// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712Upgradeable} from
    "openzeppelin-contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";

import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IEth0} from "src/interfaces/token/IEth0.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {ITokenMapping} from "src/interfaces/tokenManager/ITokenMapping.sol";
import {IOracle} from "src/interfaces/oracles/IOracle.sol";
import {IDaoCollateral} from "src/interfaces/IDaoCollateral.sol";
import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";
import {Normalize} from "src/utils/normalize.sol";
import {
    SCALAR_ONE,
    DEFAULT_ADMIN_ROLE,
    MAX_REDEEM_FEE,
    BASIS_POINT_BASE,
    CONTRACT_YIELD_TREASURY,
    PAUSING_CONTRACTS_ROLE,
    DAO_REDEMPTION_ROLE,
    UNPAUSING_CONTRACTS_ROLE,
    CONTRACT_REGISTRY_ACCESS,
    CONTRACT_TREASURY,
    CONTRACT_TOKEN_MAPPING,
    CONTRACT_ETH0,
    CONTRACT_ORACLE
} from "src/constants.sol";

import {
    InvalidToken,
    AmountIsZero,
    AmountTooLow,
    AmountTooBig,
    RedeemMustNotBePaused,
    RedeemMustBePaused,
    SwapMustNotBePaused,
    SwapMustBePaused,
    SameValue,
    CBRIsTooHigh,
    CBRIsNull,
    RedeemFeeTooBig,
    RedeemFeeCannotBeZero,
    NullContract
} from "src/errors.sol";

/// @title   DaoCollateral Contract
/// @notice  Manages the swapping of Ether collateral tokens for ETH0, with functionalities for swap (direct mint) and redeeming tokens
/// @dev     Provides mechanisms for token swap operations, fee management, called Dao Collateral for historical reasons
/// @author  Usual Tech team
contract DaoCollateral is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable,
    IDaoCollateral
{
    using SafeERC20 for IERC20Metadata;
    using CheckAccessControl for IRegistryAccess;
    using Normalize for uint256;

    struct DaoCollateralStorageV0 {
        /// @notice Indicates if the redeem functionality is paused.
        bool _redeemPaused;
        /// @notice Indicates if the swap functionality is paused.
        bool _swapPaused;
        /// @notice Indicates if the Counter Bank Run (CBR) functionality is active.
        bool isCBROn;
        /// @notice The fee for redeeming tokens, in basis points.
        uint256 redeemFee;
        /// @notice The coefficient for calculating the returned collateralToken amount when CBR is active.
        uint256 cbrCoef;
        /// @notice The RegistryAccess contract instance for role checks.
        IRegistryAccess registryAccess;
        /// @notice The RegistryContract instance for contract interactions.
        IRegistryContract registryContract;
        /// @notice The TokenMapping contract instance for managing token mappings.
        ITokenMapping tokenMapping;
        /// @notice The ETH0 token contract instance.
        IEth0 eth0;
        /// @notice The Oracle contract instance for price feeds.
        IOracle oracle;
        /// @notice The address of treasury holding collateral tokens.
        address treasury;
        /// @notice The address of treasury holding fee tokens.
        address treasuryYield;
    }

    // keccak256(abi.encode(uint256(keccak256("daoCollateral.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant DaoCollateralStorageV0Location =
        0xb6b5806749b83e5a37ff64f3aa7a7ce3ac6e8a80a998e853c1d3efe545237c00;

    /*//////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures the function is called only when the redeem is not paused.
    modifier whenRedeemNotPaused() {
        _requireRedeemNotPaused();
        _;
    }

    /// @notice Ensures the function is called only when the redeem is paused.
    modifier whenRedeemPaused() {
        _requireRedeemPaused();
        _;
    }

    /// @notice Ensures the function is called only when the swap is not paused.
    modifier whenSwapNotPaused() {
        _requireSwapNotPaused();
        _;
    }

    /// @notice Ensures the function is called only when the swap is paused.
    modifier whenSwapPaused() {
        _requireSwapPaused();
        _;
    }

    /// @notice  _requireRedeemNotPaused method will check if the redeem is not paused
    /// @dev Throws if the contract is paused.
    function _requireRedeemNotPaused() internal view virtual {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        if ($._redeemPaused) {
            revert RedeemMustNotBePaused();
        }
    }

    /// @notice  _requireRedeemPaused method will check if the redeem is paused
    /// @dev Throws if the contract is not paused.
    function _requireRedeemPaused() internal view virtual {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        if (!$._redeemPaused) {
            revert RedeemMustBePaused();
        }
    }

    /// @notice  _requireSwapNotPaused method will check if the redeem is not paused
    /// @dev Throws if the contract is paused.
    function _requireSwapNotPaused() internal view virtual {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        if ($._swapPaused) {
            revert SwapMustNotBePaused();
        }
    }

    /// @notice  _requireSwapPaused method will check if the redeem is paused
    /// @dev Throws if the contract is not paused.
    function _requireSwapPaused() internal view virtual {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        if (!$._swapPaused) {
            revert SwapMustBePaused();
        }
    }

    /// @notice Ensures the caller is authorized as part of the Usual Tech team.
    function _requireOnlyAdmin() internal view {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
    }

    /// @notice Ensures the caller is authorized as a pauser
    function _requireOnlyPauser() internal view {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $.registryAccess.onlyMatchingRole(PAUSING_CONTRACTS_ROLE);
    }

    /// @notice Ensures the caller is authorized as a unpauser
    function _requireOnlyUnpauser() internal view {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $.registryAccess.onlyMatchingRole(UNPAUSING_CONTRACTS_ROLE);
    }

    /// @notice Ensures the caller is authorized as a dao redeemer
    function _requireOnlyDaoRedeemer() internal view {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $.registryAccess.onlyMatchingRole(DAO_REDEMPTION_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the DaoCollateral contract with registry information and initial configuration.
    /// @param _registryContract The address of the registry contract.
    /// @param _redeemFee The initial redeem fee, in basis points.
    function initialize(address _registryContract, uint256 _redeemFee) public initializer {
        // can't have a redeem fee greater than 25%
        if (_redeemFee > MAX_REDEEM_FEE) {
            revert RedeemFeeTooBig();
        }
        if (_redeemFee == 0) {
            revert RedeemFeeCannotBeZero();
        }

        if (_registryContract == address(0)) {
            revert NullContract();
        }

        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();
        __EIP712_init_unchained("daoCollateral", "1");
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $.redeemFee = _redeemFee;

        IRegistryContract registryContract = IRegistryContract(_registryContract);
        $.registryAccess = IRegistryAccess(registryContract.getContract(CONTRACT_REGISTRY_ACCESS));
        $.treasury = address(registryContract.getContract(CONTRACT_TREASURY));
        $.tokenMapping = ITokenMapping(registryContract.getContract(CONTRACT_TOKEN_MAPPING));
        $.eth0 = IEth0(registryContract.getContract(CONTRACT_ETH0));
        $.oracle = IOracle(registryContract.getContract(CONTRACT_ORACLE));

        $.treasuryYield = registryContract.getContract(CONTRACT_YIELD_TREASURY);
    }

    /// @notice Returns the storage struct of the contract.
    /// @return $ The pointer to the storage struct of the contract.
    function _daoCollateralStorageV0() internal pure returns (DaoCollateralStorageV0 storage $) {
        bytes32 position = DaoCollateralStorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////
                               Setters
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IDaoCollateral
    function activateCBR(uint256 coefficient) external { // what's the CBR? : Counter Bank Run 反银行挤兑
        // we should revert if the coef is greater than 1
        if (coefficient > SCALAR_ONE) {
            revert CBRIsTooHigh();
        } else if (coefficient == 0) {
            revert CBRIsNull();
        }
        _requireOnlyAdmin();
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $.isCBROn = true; // 没有检查之前是否已经activate了， but not a vulnerability
        $._swapPaused = true;
        $.cbrCoef = coefficient;
        emit CBRActivated($.cbrCoef);
        emit SwapPaused(); // ?
    }

    /// @inheritdoc IDaoCollateral
    function deactivateCBR() external {
        _requireOnlyAdmin();
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        if ($.isCBROn == false) revert SameValue();
        $.isCBROn = false;
        emit CBRDeactivated();
    }

    /// @inheritdoc IDaoCollateral
    function setRedeemFee(uint256 _redeemFee) external {
        if (_redeemFee > MAX_REDEEM_FEE) revert RedeemFeeTooBig();
        if (_redeemFee == 0) revert RedeemFeeCannotBeZero();
        _requireOnlyAdmin(); // fully trust the admin to set the redeem fee
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        if ($.redeemFee == _redeemFee) revert SameValue();
        $.redeemFee = _redeemFee;
        emit RedeemFeeUpdated(_redeemFee);
    }

    /// @inheritdoc IDaoCollateral
    function pauseRedeem() external whenRedeemNotPaused {
        _requireOnlyPauser();
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $._redeemPaused = true;
        emit RedeemPaused();
    }

    /// @inheritdoc IDaoCollateral
    function unpauseRedeem() external whenRedeemPaused {
        _requireOnlyUnpauser();
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $._redeemPaused = false;
        emit RedeemUnPaused();
    }

    /// @inheritdoc IDaoCollateral
    function pauseSwap() external whenSwapNotPaused {
        _requireOnlyPauser();
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $._swapPaused = true;
        emit SwapPaused();
    }

    /// @inheritdoc IDaoCollateral
    function unpauseSwap() external whenSwapPaused {
        _requireOnlyUnpauser();
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        $._swapPaused = false;
        emit SwapUnPaused();
    }

    /// @inheritdoc IDaoCollateral
    function pause() external {
        _requireOnlyPauser();
        _pause();
    }

    /// @inheritdoc IDaoCollateral
    function unpause() external {
        _requireOnlyUnpauser();
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                               Internal
    //////////////////////////////////////////////////////////////*/

    /// @notice  _swapCheckAndGetETHQuote method will check if the token is a ETH0-supported collateral token and if the amount is not 0
    /// @dev     Function that do sanity check on the inputs
    /// @dev      and return the normalized ETH quoted price of collateral tokens for the given amount
    /// @param   collateralToken  address of the token to swap MUST be a collateral token.
    /// @param   amountInToken  amount of collateral token to swap.
    /// @return  wadQuoteInETH The quoted amount in ETH with 18 decimals for the specified token and amount.
    function _swapCheckAndGetETHQuote(address collateralToken, uint256 amountInToken)
        internal
        view
        returns (uint256 wadQuoteInETH)
    {
        if (amountInToken == 0) {
            revert AmountIsZero();
        }

        // Amount can't be greater than uint128
        if (amountInToken > type(uint128).max) {
            revert AmountTooBig();
        }

        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        if (!$.tokenMapping.isEth0Collateral(collateralToken)) {
            revert InvalidToken();
        }
        wadQuoteInETH = _getQuoteInETH(amountInToken, collateralToken);
        //slither-disable-next-line incorrect-equality
        if (wadQuoteInETH == 0) {
            revert AmountTooLow();
        }
    }

    /// @notice  transfers Collateral Token And Mint ETH0
    /// @dev     will transfer the collateral to the treasury and mints the corresponding stableAmount in ETH0
    /// @param   collateralToken  address of the token to swap MUST be a collateral token.
    /// @param   amount  amount of collateral token to swap.
    /// @param   wadAmountInETH0 amount of ETH0 to mint.
    function _transferCollateralTokenAndMintEth0(
        address collateralToken,
        uint256 amount,
        uint256 wadAmountInETH0
    ) internal {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        // Should revert if balance is insufficient
        IERC20Metadata(address(collateralToken)).safeTransferFrom(msg.sender, $.treasury, amount);
        // Mint some ETH0
        $.eth0.mint(msg.sender, wadAmountInETH0);
    }

    /// @dev call the oracle to get the price in ETH
    /// @param collateralToken the collateral token address
    /// @return wadPriceInETH the price in ETH with 18 decimals
    /// @return decimals number of decimals of the token
    function _getPriceAndDecimals(address collateralToken)
        internal
        view
        returns (uint256 wadPriceInETH, uint8 decimals)
    {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        wadPriceInETH = uint256($.oracle.getPrice(collateralToken));
        decimals = uint8(IERC20Metadata(collateralToken).decimals());
    }

    /// @notice  get the price in ETH of an `tokenAmount` of `collateralToken`
    /// @dev call the oracle to get the price in ETH of `tokenAmount` of token with 18 decimals
    /// @param tokenAmount the amount of token to convert in ETH with 18 decimals
    /// @param collateralToken the collateral token address
    /// @return wadAmountInETH the amount in ETH with 18 decimals
    function _getQuoteInETH(uint256 tokenAmount, address collateralToken)
        internal
        view
        returns (uint256 wadAmountInETH) // 计算用户最终能获得的ETH0数量
    {
        (uint256 wadPriceInETH, uint8 decimals) = _getPriceAndDecimals(collateralToken);
        uint256 wadAmount = tokenAmount.tokenAmountToWad(decimals);
        wadAmountInETH = Math.mulDiv(wadAmount, wadPriceInETH, SCALAR_ONE, Math.Rounding.Floor);
        // 这里是向下取整，对协议有利！ 与Q&A的对用户有利 相违背！ anyway，可以report
    }

    /// @notice  get the amount of token for an amount of ETH
    /// @dev call the oracle to get the price in ETH of `amount` of token with 18 decimals
    /// @param wadStableAmount the amount of ETH with 18 decimals
    /// @param collateralToken the collateral token address
    /// @return amountInToken the amount in token corresponding to the amount of ETH
    function _getQuoteInTokenFromETH(uint256 wadStableAmount, address collateralToken)
        internal
        view
        returns (uint256 amountInToken)
    {
        (uint256 wadPriceInETH, uint8 decimals) = _getPriceAndDecimals(collateralToken);
        // will result in an amount with the same 'decimals' as the token
        amountInToken = wadStableAmount.wadTokenAmountForPrice(wadPriceInETH, decimals);
    }

    /// @notice Calculates the returned amount of collateralToken give an amount of ETH
    /// @dev return the amountInToken of token for `wadStableAmount` of ETH at the current price
    /// @param wadStableAmount the amount of ETH
    /// @param collateralToken the collateral token address
    /// @return amountInToken the amount of token that is worth `wadStableAmount` of ETH with 18 decimals
    function _getTokenAmountForAmountInETH(uint256 wadStableAmount, address collateralToken)
        internal
        view
        returns (uint256 amountInToken)
    {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        amountInToken = _getQuoteInTokenFromETH(wadStableAmount, collateralToken);
        // if cbr is on we need to apply the coef to the collateral price
        // cbrCoef should be less than 1e18
        if ($.isCBROn) {
            amountInToken = Math.mulDiv(amountInToken, $.cbrCoef, SCALAR_ONE, Math.Rounding.Floor);
        }
    }

    /// @notice  _calculateFee method will calculate the ETH0 redeem fee
    /// @dev     Function that transfer the fee to the treasury
    /// @dev     The fee is calculated as a percentage of the amount of ETH0 to redeem
    /// @dev     The fee is minted to avoid transfer and allowance as the whole ETH0 amount is burnt afterwards
    /// @param   eth0Amount  Amount of ETH0 to transfer to treasury.
    /// @param   collateralToken  address of the token to swap should be a collateral token.
    /// @return stableFee The amount of ETH0 minted as fees for the treasury.
    function _calculateFee(uint256 eth0Amount, address collateralToken)
        internal
        view
        returns (uint256 stableFee) // 计算用户所需要支付的赎回费用
    {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        stableFee = Math.mulDiv(eth0Amount, $.redeemFee, BASIS_POINT_BASE, Math.Rounding.Floor); // 有利于用户
        uint8 tokenDecimals = IERC20Metadata(collateralToken).decimals();
        // if the token has less decimals than ETH0 we need to normalize the fee
        if (tokenDecimals < 18) {
            // we scale down the fee to the token decimals
            // and we scale it up to 18 decimals
            stableFee = Normalize.tokenAmountToWad( // 有点奇怪的转换 舍掉过于小粒度的(类似舍掉小数部分)
                Normalize.wadAmountToDecimals(stableFee, tokenDecimals), tokenDecimals
            );
        }
    }

    /// @notice  _burnEth0TokenAndTransferCollateral method will burn the ETH0 token and transfer the collateral token
    /// @param   collateralToken  address of the token to swap should be a collateral token.
    /// @param   eth0Amount  amount of ETH0 to swap.
    /// @param   stableFee  amount of fee in ETH0.
    /// @return returnedCollateral The amount of collateral token returned.
    function _burnEth0TokenAndTransferCollateral(
        address collateralToken,
        uint256 eth0Amount,
        uint256 stableFee
    ) internal returns (uint256 returnedCollateral) {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        // we burn the remaining ETH0 token
        uint256 burnedEth0 = eth0Amount - stableFee;
        // we burn all the ETH0 token
        $.eth0.burnFrom(msg.sender, eth0Amount);

        // If the CBR is on, the fees are forfeited from the yield treasury to favor the collateralization ratio
        if (stableFee > 0 && !$.isCBROn) {
            $.eth0.mint($.treasuryYield, stableFee); // treasuryYield:收益金库,专门用来接收协议产生的ETH0赎回费用的金库
        }

        // get the amount of collateral token for the amount of ETH0 burned by calling the oracle
        returnedCollateral = _getTokenAmountForAmountInETH(burnedEth0, collateralToken);
        if (returnedCollateral == 0) {
            revert AmountTooLow();
        }

        // we distribute the collateral token from the treasury to the user
        // slither-disable-next-line arbitrary-send-erc20
        IERC20Metadata(collateralToken).safeTransferFrom($.treasury, msg.sender, returnedCollateral);
        // treasury: 存放用户抵押品的主金库
    }

    /*//////////////////////////////////////////////////////////////
                               External
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IDaoCollateral
    function swap(address collateralToken, uint256 amount, uint256 minAmountOut)
        public
        nonReentrant
        whenSwapNotPaused
        whenNotPaused
    { // 在这里，swap 的实际作用是：用户提供合格的抵押品代币 (collateralToken)，协议根据这些抵押品的价值，为用户铸造 (mint) 出新的 ETH0 代币。
        uint256 wadQuoteInETH = _swapCheckAndGetETHQuote(collateralToken, amount);
        // Check if the amount is greater than the minAmountOut
        if (wadQuoteInETH < minAmountOut) { // 防止滑点过大
            revert AmountTooLow();
        }

        _transferCollateralTokenAndMintEth0(collateralToken, amount, wadQuoteInETH); // why need mint?
        emit Swap(msg.sender, collateralToken, amount, wadQuoteInETH);
    }

    /// @inheritdoc IDaoCollateral
    function swapWithPermit(
        address collateralToken,
        uint256 amount,
        uint256 minAmountOut,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // solhint-disable-next-line no-empty-blocks
        try IERC20Permit(collateralToken).permit(
            msg.sender, address(this), amount, deadline, v, r, s
        ) {} catch {} // solhint-disable-line no-empty-blocks
        swap(collateralToken, amount, minAmountOut);
    }

    /// @inheritdoc IDaoCollateral
    function redeem(address collateralToken, uint256 amount, uint256 minAmountOut)
        external
        nonReentrant
        whenRedeemNotPaused
        whenNotPaused
    {
        // Amount can't be 0
        if (amount == 0) {
            revert AmountIsZero();
        }

        // check that collateralToken is a collateral token
        if (!_daoCollateralStorageV0().tokenMapping.isEth0Collateral(collateralToken)) {
            revert InvalidToken();
        }
        uint256 stableFee = _calculateFee(amount, collateralToken);
        uint256 returnedCollateral =
            _burnEth0TokenAndTransferCollateral(collateralToken, amount, stableFee);
        // Check if the amount is greater than the minAmountOut
        if (returnedCollateral < minAmountOut) {
            revert AmountTooLow();
        }
        emit Redeem(msg.sender, collateralToken, amount, returnedCollateral, stableFee);
    }

    /// @inheritdoc IDaoCollateral
    function redeemDao(address collateralToken, uint256 amount)
        external
        nonReentrant
        whenNotPaused
    {
        // Amount can't be 0
        if (amount == 0) {
            revert AmountIsZero();
        }

        _requireOnlyDaoRedeemer();
        // check that collateralToken is a collateral token
        if (!_daoCollateralStorageV0().tokenMapping.isEth0Collateral(collateralToken)) {
            revert InvalidToken();
        }
        uint256 returnedCollateral = _burnEth0TokenAndTransferCollateral(collateralToken, amount, 0);
        emit Redeem(msg.sender, collateralToken, amount, returnedCollateral, 0);
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @inheritdoc IDaoCollateral
    function isCBROn() external view returns (bool) {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        return $.isCBROn;
    }

    /// @inheritdoc IDaoCollateral
    function cbrCoef() public view returns (uint256) {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        return $.cbrCoef;
    }

    /// @inheritdoc IDaoCollateral
    function redeemFee() public view returns (uint256) {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        return $.redeemFee;
    }

    /// @inheritdoc IDaoCollateral
    function isRedeemPaused() public view returns (bool) {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        return $._redeemPaused;
    }

    /// @inheritdoc IDaoCollateral
    function isSwapPaused() public view returns (bool) {
        DaoCollateralStorageV0 storage $ = _daoCollateralStorageV0();
        return $._swapPaused;
    }
}
