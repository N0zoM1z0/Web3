// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {BaseHealthCheck, BaseStrategy, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IStabilityPool} from "./interfaces/IStabilityPool.sol";
import {IAuction} from "./interfaces/IAuction.sol";
import {IAuctionFactory} from "./interfaces/IAuctionFactory.sol";
import {IAddressesRegistry} from "./interfaces/IAddressesRegistry.sol";

contract LiquityV2SPStrategy is BaseHealthCheck {

    using SafeERC20 for ERC20;

    // ===============================================================
    // Storage
    // ===============================================================

    /// @notice Whether deposits are open to everyone
    bool public openDeposits;

    /// @notice Max base fee (in gwei) for a tend
    uint256 public maxGasPriceToTend;

    /// @notice Buffer percentage for the auction starting price
    uint256 public bufferPercentage;

    /// @notice Any amount below this will be ignored
    uint256 public dustThreshold;

    /// @notice Addresses allowed to deposit when openDeposits is false
    mapping(address => bool) public allowed;

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice WAD constant
    uint256 private constant WAD = 1e18;

    /// @notice Auction starting price buffer percentage increase when the oracle is down
    uint256 public constant ORACLE_DOWN_BUFFER_PCT_MULTIPLIER = 1_000; // 1000x

    /// @notice Minimum buffer percentage for the auction starting price
    uint256 public constant MIN_BUFFER_PERCENTAGE = WAD + 1e17; // 10%

    /// @notice Minimum dust threshold
    uint256 public constant MIN_DUST_THRESHOLD = 1e15;

    /// @notice Collateral reward token of the Stability Pool
    ERC20 public immutable COLL;

    /// @notice Liquity's price oracle for the collateral token
    ///         Assumes the price feed is using 18 decimals
    IPriceFeed public immutable COLL_PRICE_ORACLE;

    /// @notice Stability Pool contract
    IStabilityPool public immutable SP;

    /// @notice Auction contract for selling the collateral reward token
    IAuction public immutable AUCTION;

    /// @notice Factory for creating the auction contract
    IAuctionFactory public constant AUCTION_FACTORY = IAuctionFactory(0xCfA510188884F199fcC6e750764FAAbE6e56ec40);

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _addressesRegistry Address of the AddressesRegistry
    /// @param _asset Address of the strategy's underlying asset
    /// @param _name Name of the strategy
    constructor(address _addressesRegistry, address _asset, string memory _name) BaseHealthCheck(_asset, _name) {
        COLL_PRICE_ORACLE = IAddressesRegistry(_addressesRegistry).priceFeed();
        (, bool _isOracleDown) = COLL_PRICE_ORACLE.fetchPrice();
        require(!_isOracleDown && COLL_PRICE_ORACLE.priceSource() == IPriceFeed.PriceSource.primary, "!oracle");

        SP = IAddressesRegistry(_addressesRegistry).stabilityPool();
        require(SP.boldToken() == _asset, "!sp");
        COLL = ERC20(SP.collToken());

        AUCTION = AUCTION_FACTORY.createNewAuction(_asset);
        AUCTION.enable(address(COLL));

        maxGasPriceToTend = 200 * 1e9;
        bufferPercentage = MIN_BUFFER_PERCENTAGE;
        dustThreshold = MIN_DUST_THRESHOLD;
    }

    // ===============================================================
    // View functions
    // ===============================================================

    /// @notice Check if there are collateral gains to claim from the Stability Pool
    /// @return True if there are collateral gains to claim
    function isCollateralGainToClaim() public view returns (bool) {
        return SP.getDepositorCollGain(address(this)) > dustThreshold;
    }

    /// @notice Estimated total assets held by the strategy
    /// @dev Does not account for pending collateral reward value
    /// @return Estimated total assets held by the strategy
    function estimatedTotalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + SP.getCompoundedBoldDeposit(address(this));
    }

    /// @inheritdoc BaseStrategy
    function availableDepositLimit(
        address _owner
    ) public view override returns (uint256) {
        return openDeposits || allowed[_owner] ? type(uint256).max : 0;
    }

    /// @inheritdoc BaseStrategy
    function availableWithdrawLimit(
        address /*_owner*/
    ) public view override returns (uint256) {
        return estimatedTotalAssets();
    }

    // ===============================================================
    // Management functions
    // ===============================================================

    /// @notice Allow anyone to deposit
    /// @dev This is irreversible
    function allowDeposits() external onlyManagement {
        openDeposits = true;
    }

    /// @notice Set the maximum gas price for tending
    /// @param _maxGasPriceToTend New maximum gas price
    function setMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) external onlyManagement {
        maxGasPriceToTend = _maxGasPriceToTend;
    }

    /// @notice Set the buffer percentage for the auction starting price
    /// @param _bufferPercentage New buffer percentage
    function setBufferPercentage(
        uint256 _bufferPercentage
    ) external onlyManagement {
        require(_bufferPercentage >= MIN_BUFFER_PERCENTAGE, "!minBuffer");
        bufferPercentage = _bufferPercentage;
    }

    /// @notice Set the dust threshold for the strategy
    /// @param _dustThreshold New dust threshold
    function setDustThreshold(
        uint256 _dustThreshold
    ) external onlyManagement {
        require(_dustThreshold >= MIN_DUST_THRESHOLD, "!minDust");
        dustThreshold = _dustThreshold;
    }

    /// @notice Allow a specific address to deposit
    /// @dev This is irreversible
    /// @param _address Address to allow
    function setAllowed(
        address _address
    ) external onlyManagement {
        allowed[_address] = true;
    }

    /// @notice Sweep stuck tokens
    /// @dev Cannot sweep strategy asset or collateral token
    /// @param _token Address of token to sweep
    function sweep(
        ERC20 _token
    ) external onlyManagement {
        require(_token != asset && _token != COLL, "!token");
        uint256 _balance = _token.balanceOf(address(this));
        require(_balance > 0, "!balance");
        _token.safeTransfer(TokenizedStrategy.management(), _balance);
    }

    // ===============================================================
    // Mutated functions
    // ===============================================================

    /// @notice Claim collateral and yield gains from the Stability Pool
    function claim() public {
        _freeFunds(0);
    }

    // ===============================================================
    // Internal mutated functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _deployFunds(
        uint256 _amount
    ) internal override {
        SP.provideToSP(_amount, false);
    }

    /// @inheritdoc BaseStrategy
    function _freeFunds(
        uint256 _amount
    ) internal override {
        SP.withdrawFromSP(_amount, true);
    }

    /// @inheritdoc BaseStrategy
    function _harvestAndReport() internal override returns (uint256 _totalAssets) {
        if (!TokenizedStrategy.isShutdown()) {
            uint256 _toDeploy = asset.balanceOf(address(this));
            if (_toDeploy > dustThreshold) _deployFunds(_toDeploy);
        }

        return estimatedTotalAssets();
    }

    /// @inheritdoc BaseStrategy
    function _emergencyWithdraw(
        uint256 /*_amount*/
    ) internal override {
        _freeFunds(type(uint256).max); // Stability pool scales down to actual balance for us
    }

    /// @inheritdoc BaseStrategy
    function _tend(
        uint256 /*_totalIdle*/
    ) internal override {
        if (isCollateralGainToClaim()) claim();
        if (AUCTION.isActive(address(COLL)) && AUCTION.available(address(COLL)) == 0) AUCTION.settle(address(COLL));

        uint256 _toAuction = COLL.balanceOf(address(this));
        uint256 _available = COLL.balanceOf(address(AUCTION)) + _toAuction;
        if (_available > dustThreshold) {
            (uint256 _price, bool _isOracleDown) = COLL_PRICE_ORACLE.fetchPrice();
            uint256 _bufferPercentage = bufferPercentage;
            if (_isOracleDown || COLL_PRICE_ORACLE.priceSource() != IPriceFeed.PriceSource.primary) {
                _bufferPercentage *= ORACLE_DOWN_BUFFER_PCT_MULTIPLIER;
            }

            // slither-disable-next-line divide-before-multiply
            AUCTION.setStartingPrice(_available * _price / WAD * _bufferPercentage / WAD / WAD); // Reverts if there's an active auction

            COLL.safeTransfer(address(AUCTION), _toAuction);
            AUCTION.kick(address(COLL));
        }
    }

    // ===============================================================
    // Internal view functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _tendTrigger() internal view override returns (bool) {
        if (TokenizedStrategy.totalAssets() == 0) return false;

        // If active auction, wait
        if (AUCTION.available(address(COLL)) > 0) return false;

        // If base fee is acceptable and there's collateral to sell, tend to minimize exchange rate exposure
        return block.basefee <= maxGasPriceToTend
            && (isCollateralGainToClaim() || COLL.balanceOf(address(this)) > dustThreshold);
    }

}
