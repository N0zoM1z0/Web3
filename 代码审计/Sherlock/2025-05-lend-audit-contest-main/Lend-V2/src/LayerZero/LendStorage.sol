// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interaces/LendtrollerInterfaceV2.sol";
import "./interaces/LendInterface.sol";
import "../LTokenInterfaces.sol";
import "../ExponentialNoError.sol";
import "./interaces/UniswapAnchoredViewInterface.sol";

/**
 * @title LendStorage
 * @notice Contract responsible for storing all state variables used by CoreRouter and NewCrossChainRouter
 * @dev This contract acts as a single source of truth for all storage variables
 */
contract LendStorage is Ownable, ExponentialNoError {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public lendtroller;
    address public priceOracle;
    uint256 public currentEid;

    // Protocol constants
    uint256 public constant PROTOCOL_SEIZE_SHARE_MANTISSA = 2.8e16; // 2.8%
    uint224 public constant LEND_INITIAL_INDEX = 1e36;
    // Structs

    struct Borrow {
        uint256 srcEid; // Source chain's layer zero endpoint id
        uint256 destEid; // Destination chain's layer zero endpoint id
        uint256 principle; // Borrowed token amount
        uint256 borrowIndex; // Borrow index
        address borrowedlToken; // Address of the borrower
        address srcToken; // Source token address
    }

    struct BorrowMarketState {
        uint256 amount; // Borrowed amount
        uint256 borrowIndex; // Borrow index when last updated
    }

    struct LiquidationParams {
        address borrower;
        uint256 repayAmount;
        uint32 srcEid;
        address lTokenToSeize;
        address borrowedAsset;
        uint256 storedBorrowIndex;
        uint256 borrowPrinciple;
        address borrowedlToken;
    }

    struct AccountLiquidityLocalVars {
        uint256 sumCollateral;
        uint256 sumBorrowPlusEffects;
        uint256 lTokenBalance;
        uint256 borrowBalance;
        uint256 oraclePriceMantissa;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;
    }

    // Token mappings
    mapping(address lToken => address underlying) public lTokenToUnderlying;
    mapping(address underlying => address lToken) public underlyingTolToken;
    mapping(address underlying => mapping(uint256 destId => address destUnderlying)) public underlyingToDestUnderlying;
    mapping(address underlying => mapping(uint256 destId => address destlToken)) public underlyingToDestlToken;

    // LEND distribution state
    mapping(address lToken => mapping(address user => uint256 lendSupplierIndex)) public lendSupplierIndex;
    mapping(address lToken => mapping(address user => uint256 lendBorrowerIndex)) public lendBorrowerIndex;
    mapping(address user => uint256 lendAccrued) public lendAccrued;

    // Cross-chain mappings
    mapping(address asset => mapping(uint256 destEid => address assetDestChain)) public crossChainAssetMap;
    mapping(address lToken => mapping(uint256 destEid => address lTokenDestChain)) public crossChainLTokenMap;

    // Borrow and collateral tracking
    mapping(address borrower => mapping(address underlying => Borrow[])) public crossChainBorrows;
    mapping(address borrower => mapping(address underlying => Borrow[])) public crossChainCollaterals;

    // Investment and balance tracking
    mapping(address user => mapping(address lToken => uint256 totalInvestment)) public totalInvestment;
    mapping(address user => mapping(address lToken => BorrowMarketState borrowBalance)) public borrowBalance;
    mapping(address lToken => uint256 protocolReward) public protocolReward;

    // User asset tracking
    mapping(address user => EnumerableSet.AddressSet suppliedLTokens) internal userSuppliedAssets;
    // Only for cross-chain borrows
    mapping(address user => EnumerableSet.AddressSet borrowedLTokens) internal userBorrowedAssets;

    // Access control
    mapping(address contractAddress => bool isAuthorized) public authorizedContracts;

    // Events
    event LendtrollerSet(address indexed newLendtroller);
    event LTokenAdded(address indexed underlying, address indexed lToken);
    event UnderlyingToDestUnderlyingSet(
        address indexed underlying, uint256 indexed destId, address indexed destUnderlying
    );
    event UnderlyingToDestlTokenSet(address indexed underlying, uint256 indexed destId, address indexed destlToken);
    event CrossChainAssetMapSet(address indexed localToken, uint256 indexed destEid, address indexed remoteToken);
    event CrossChainLTokenMapSet(address indexed lToken, uint256 indexed destEid, address indexed destlToken);
    event ContractAuthorized(address indexed contractAddress, bool authorized);
    event ProtocolRewardUpdated(address indexed lToken, uint256 newAmount);
    event TotalInvestmentUpdated(address indexed user, address indexed lToken, uint256 newAmount);

    // Modifiers
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Caller not authorized");
        _;
    }

    constructor(address _lendtroller, address _priceOracleAddress, uint32 _currentEid) {
        require(_lendtroller != address(0), "Invalid lendtroller");
        require(_priceOracleAddress != address(0), "Invalid oracle");
        lendtroller = _lendtroller;
        priceOracle = _priceOracleAddress;
        currentEid = _currentEid;
    }

    // Authorization functions
    function setAuthorizedContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit ContractAuthorized(_contract, _authorized);
    }

    function setLendtroller(address _lendtroller) external onlyOwner {
        require(_lendtroller != address(0), "Invalid lendtroller");
        lendtroller = _lendtroller;
        emit LendtrollerSet(_lendtroller);
    }

    // Asset management functions
    function addSupportedTokens(address underlying, address lToken) external onlyOwner {
        require(underlying != address(0) && lToken != address(0), "Invalid addresses");
        underlyingTolToken[underlying] = lToken;
        lTokenToUnderlying[lToken] = underlying; // 双向mapping
        emit LTokenAdded(underlying, lToken);
    }

    function addUnderlyingToDestUnderlying(address underlying, address destUnderlying, uint256 destId)
        external
        onlyOwner
    {
        require(underlying != address(0) && destUnderlying != address(0), "Invalid addresses");
        underlyingToDestUnderlying[underlying][destId] = destUnderlying;
        emit UnderlyingToDestUnderlyingSet(underlying, destId, destUnderlying);
    }

    function addUnderlyingToDestlToken(address underlying, address destlToken, uint256 destId) external onlyOwner {
        require(underlying != address(0) && destlToken != address(0), "Invalid addresses");
        underlyingToDestlToken[underlying][destId] = destlToken;
        emit UnderlyingToDestlTokenSet(underlying, destId, destlToken);
    }

    // User asset tracking functions
    function getUserSuppliedAssets(address user) external view returns (address[] memory) {
        return userSuppliedAssets[user].values();
    }

    function getUserBorrowedAssets(address user) external view returns (address[] memory) {
        return userBorrowedAssets[user].values();
    }

    function addUserSuppliedAsset(address user, address lTokenAddress) external onlyAuthorized {
        if (!userSuppliedAssets[user].contains(lTokenAddress)) {
            userSuppliedAssets[user].add(lTokenAddress);
        }
    }

    function removeUserSuppliedAsset(address user, address lTokenAddress) external onlyAuthorized {
        userSuppliedAssets[user].remove(lTokenAddress);
    }

    function addUserBorrowedAsset(address user, address lTokenAddress) external onlyAuthorized {
        if (!userBorrowedAssets[user].contains(lTokenAddress)) {
            userBorrowedAssets[user].add(lTokenAddress);
        }
    }

    function removeUserBorrowedAsset(address user, address lTokenAddress) external onlyAuthorized {
        userBorrowedAssets[user].remove(lTokenAddress);
    }

    // Protocol reward functions
    function updateProtocolReward(address lToken, uint256 amount) external onlyAuthorized {
        protocolReward[lToken] = amount;
        emit ProtocolRewardUpdated(lToken, amount);
    }

    // Investment tracking functions
    function updateTotalInvestment(address user, address lToken, uint256 amount) external onlyAuthorized {
        totalInvestment[user][lToken] = amount;
        emit TotalInvestmentUpdated(user, lToken, amount);
    }

    function updateCrossChainCollateral(address user, address underlying, uint256 index, Borrow memory newCollateral)
        external
        onlyAuthorized // 跨链质押物
    {
        Borrow storage collateral = crossChainCollaterals[user][underlying][index]; // 没有检查有没有
        collateral.srcEid = newCollateral.srcEid;
        collateral.destEid = newCollateral.destEid;
        collateral.principle = newCollateral.principle;
        collateral.borrowIndex = newCollateral.borrowIndex;
        collateral.borrowedlToken = newCollateral.borrowedlToken;
        collateral.srcToken = newCollateral.srcToken;
    }

    function addCrossChainCollateral(address user, address underlying, Borrow memory newCollateral)
        external
        onlyAuthorized
    {
        crossChainCollaterals[user][underlying].push(newCollateral);
    }

    function removeCrossChainCollateral(address user, address underlying, uint256 index) external onlyAuthorized {
        crossChainCollaterals[user][underlying][index] =
            crossChainCollaterals[user][underlying][crossChainCollaterals[user][underlying].length - 1];
        crossChainCollaterals[user][underlying].pop();
    }

    function updateCrossChainBorrow(address user, address underlying, uint256 index, Borrow memory newBorrow)
        external
        onlyAuthorized
    {
        Borrow storage borrow = crossChainBorrows[user][underlying][index];
        borrow.srcEid = newBorrow.srcEid;
        borrow.destEid = newBorrow.destEid;
        borrow.principle = newBorrow.principle;
        borrow.borrowIndex = newBorrow.borrowIndex;
        borrow.borrowedlToken = newBorrow.borrowedlToken;
        borrow.srcToken = newBorrow.srcToken;
    }

    function updateBorrowBalance(address user, address lToken, uint256 _amount, uint256 _borrowIndex)
        external
        onlyAuthorized
    {
        BorrowMarketState storage borrow = borrowBalance[user][lToken];
        borrow.amount = _amount;
        borrow.borrowIndex = _borrowIndex;
    }

    function removeBorrowBalance(address user, address lToken) external onlyAuthorized {
        delete borrowBalance[user][lToken];
    }

    function addCrossChainBorrow(address user, address underlying, Borrow memory newBorrow) external onlyAuthorized {
        crossChainBorrows[user][underlying].push(newBorrow);
    }

    function removeCrossChainBorrow(address user, address underlying, uint256 index) external onlyAuthorized {
        crossChainBorrows[user][underlying][index] =
            crossChainBorrows[user][underlying][crossChainBorrows[user][underlying].length - 1];
        crossChainBorrows[user][underlying].pop();
    }

    // Cross-chain mapping functions
    function setChainAssetMap(address localToken, uint256 destEid, address remoteToken) external onlyOwner {
        require(localToken != address(0) && remoteToken != address(0), "Invalid addresses");
        crossChainAssetMap[localToken][destEid] = remoteToken; // using destEid to distinguish chains
        emit CrossChainAssetMapSet(localToken, destEid, remoteToken);
    }

    function setChainLTokenMap(address lToken, uint256 destEid, address destlToken) external onlyOwner {
        require(lToken != address(0) && destlToken != address(0), "Invalid addresses");
        crossChainLTokenMap[lToken][destEid] = destlToken;
        emit CrossChainLTokenMapSet(lToken, destEid, destlToken);
    }

    function setLendSupplierIndex(address lToken, address account, uint256 index) external onlyAuthorized {
        lendSupplierIndex[lToken][account] = index;
    }

    function setLendBorrowerIndex(address lToken, address account, uint256 index) external onlyAuthorized {
        lendBorrowerIndex[lToken][account] = index;
    }

    // Getter functions
    function getBorrowBalance(address user, address lToken) external view returns (BorrowMarketState memory) {
        return borrowBalance[user][lToken];
    }

    function getCrossChainBorrows(address user, address token) external view returns (Borrow[] memory) {
        return crossChainBorrows[user][token];
    }

    function getCrossChainCollaterals(address user, address token) external view returns (Borrow[] memory) {
        return crossChainCollaterals[user][token];
    }

    /**
     * @notice Distributes LEND tokens to the supplier or borrower
     * @param lToken The address of the lToken representing the asset
     * @param supplier The address of the supplier
     */
    function distributeSupplierLend(address lToken, address supplier) external onlyAuthorized {
        // Trigger supply index update
        LendtrollerInterfaceV2(lendtroller).triggerSupplyIndexUpdate(lToken);

        // Get the appropriate lend state based on whether it's for supply or borrow
        (uint224 supplyIndex,) = LendtrollerInterfaceV2(lendtroller).lendSupplyState(lToken);

        // Get the relevant indexes and accrued LEND for the account
        uint256 supplierIndex = lendSupplierIndex[lToken][supplier];

        lendSupplierIndex[lToken][supplier] = supplyIndex;

        // Update the account's index to the current index since we are distributing accrued LEND
        if (supplierIndex == 0 && supplyIndex >= LEND_INITIAL_INDEX) {
            // Covers the case where users borrowed tokens before the market's borrow state index was set.
            // Rewards the user with LEND accrued from the start of when borrower rewards were first
            // set for the market.
            supplierIndex = LEND_INITIAL_INDEX;
        }

        // Calculate change in the cumulative sum of the LEND per lToken accrued
        Double memory deltaIndex = Double({mantissa: sub_(supplyIndex, supplierIndex)}); // 从上次结算以来的奖励(每单位lToken)

        // Calculate the appropriate account balance and delta based on supply or borrow
        uint256 supplierTokens = totalInvestment[supplier][lToken];

        // Calculate LEND accrued: lTokenAmount * accruedPerLToken
        uint256 supplierDelta = mul_(supplierTokens, deltaIndex);

        // Update the accrued LEND for the account
        uint256 supplierAccrued = add_(lendAccrued[supplier], supplierDelta); // 累加
        lendAccrued[supplier] = supplierAccrued;
    }

    /**
     * @notice Distributes LEND tokens to the borrower
     * @param lToken The address of the lToken representing the asset
     * @param borrower The address of the borrower
     */
    function distributeBorrowerLend(address lToken, address borrower) external onlyAuthorized {
        // Trigger borrow index update
        LendtrollerInterfaceV2(lendtroller).triggerBorrowIndexUpdate(lToken);

        // Get the appropriate lend state based on whether it's for supply or borrow
        (uint224 borrowIndex,) = LendtrollerInterfaceV2(lendtroller).lendBorrowState(lToken);

        uint256 borrowerIndex = lendBorrowerIndex[lToken][borrower];

        // Update borrowers's index to the current index since we are distributing accrued LEND
        lendBorrowerIndex[lToken][borrower] = borrowIndex;

        if (borrowerIndex == 0 && borrowIndex >= LEND_INITIAL_INDEX) {
            // Covers the case where users borrowed tokens before the market's borrow state index was set.
            // Rewards the user with LEND accrued from the start of when borrower rewards were first
            // set for the market.
            borrowerIndex = LEND_INITIAL_INDEX;
        }

        // Calculate change in the cumulative sum of the LEND per borrowed unit accrued
        Double memory deltaIndex = Double({mantissa: sub_(borrowIndex, borrowerIndex)});

        // Calculate the appropriate account balance and delta based on supply or borrow
        uint256 borrowerAmount = div_(
            add_(borrowWithInterest(borrower, lToken), borrowWithInterestSame(borrower, lToken)),
            // 跨链 + 同链 的借款总额
            Exp({mantissa: LTokenInterface(lToken).borrowIndex()}) // 获取当前 lToken 市场自身的市场借款指数
        );

        // Calculate LEND accrued: lTokenAmount * accruedPerBorrowedUnit
        uint256 borrowerDelta = mul_(borrowerAmount, deltaIndex);
        // borrowerDelta = deltaIndex * (same + cross-chain) / LTokenInterface(lToken).borrowIndex()
        uint256 borrowerAccrued = add_(lendAccrued[borrower], borrowerDelta);
        lendAccrued[borrower] = borrowerAccrued;
    }

    /**
     * @dev Calculates the hypothetical account liquidity and collateral.
     * @param account The address of the account.
     * @param lTokenModify The lToken being modified (redeemed or borrowed).
     * @param redeemTokens The amount of lTokens being redeemed.
     * @param borrowAmount The amount of tokens being borrowed.
     * @return An enum indicating the error status, the sum of borrowed amount plus effects, and the sum of collateral.
     */
    function getHypotheticalAccountLiquidityCollateral(
        address account,
        LToken lTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) public view returns (uint256, uint256) {
        AccountLiquidityLocalVars memory vars;
// 它的主要作用是计算一个账户在考虑了某笔假设的、即将发生的操作（如赎回抵押品或新增借款）之后的总体流动性状况，返回两个值：总的借款价值 (sumBorrowPlusEffects) 和总的抵押品价值 (sumCollateral)，这两个值通常会以一个共同的计价单位（如美元）表示。
        // Calculate collateral value from supplied assets
        address[] memory suppliedAssets = userSuppliedAssets[account].values();
        address[] memory borrowedAssets = userBorrowedAssets[account].values();

        // First loop: Calculate collateral value from supplied assets
        for (uint256 i = 0; i < suppliedAssets.length;) { // 遍历用户已提供的所有作为抵押品的 LToken 列表。
            LToken asset = LToken(suppliedAssets[i]);
            uint256 lTokenBalanceInternal = totalInvestment[account][address(asset)];

            // Get collateral factor and price for this asset
            vars.collateralFactor =
                Exp({mantissa: LendtrollerInterfaceV2(lendtroller).getCollateralFactorMantissa(address(asset))});
            vars.exchangeRate = Exp({mantissa: asset.exchangeRateStored()});

            vars.oraclePriceMantissa = UniswapAnchoredViewInterface(priceOracle).getUnderlyingPrice(asset);
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});
            vars.tokensToDenom = mul_(mul_(vars.collateralFactor, vars.exchangeRate), vars.oraclePrice);
// 得到每单位的 LToken 抵押品的折算价值
            // Add to collateral sum
            vars.sumCollateral =
                mul_ScalarTruncateAddUInt(vars.tokensToDenom, lTokenBalanceInternal, vars.sumCollateral);
// 折算并累加
            unchecked {
                ++i;
            }
        }

        // Second loop: Calculate borrow value from borrowed assets
        for (uint256 i = 0; i < borrowedAssets.length;) { // 遍历用户已借入的所有 LToken 列表。
            LToken asset = LToken(borrowedAssets[i]);

            // Get borrow balance for this asset
            uint256 totalBorrow = borrowWithInterestSame(account, address(asset));

            // Add cross-chain borrows if any
            totalBorrow += borrowWithInterest(account, address(asset)); // 同 + 跨链借款

            // Get price for borrowed asset
            vars.oraclePriceMantissa = UniswapAnchoredViewInterface(priceOracle).getUnderlyingPrice(asset);
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

            // Add to borrow sum
            vars.sumBorrowPlusEffects =
                mul_ScalarTruncateAddUInt(vars.oraclePrice, totalBorrow, vars.sumBorrowPlusEffects);

            unchecked {
                ++i;
            }
        }

        // Handle effects of current action
        if (address(lTokenModify) != address(0)) {
            vars.oraclePriceMantissa = UniswapAnchoredViewInterface(priceOracle).getUnderlyingPrice(lTokenModify);
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

            // Add effect of redeeming collateral
            if (redeemTokens > 0) { // 赎回质押
                vars.collateralFactor = Exp({
                    mantissa: LendtrollerInterfaceV2(lendtroller).getCollateralFactorMantissa(address(lTokenModify))
                });
                vars.exchangeRate = Exp({mantissa: lTokenModify.exchangeRateStored()});
                vars.tokensToDenom = mul_(mul_(vars.collateralFactor, vars.exchangeRate), vars.oraclePrice);
                vars.sumBorrowPlusEffects = // 减少的抵押能力 折算成 等效增加的负债   来进行评估
                    mul_ScalarTruncateAddUInt(vars.tokensToDenom, redeemTokens, vars.sumBorrowPlusEffects);
            }

            // Add effect of new borrow
            if (borrowAmount > 0) {
                vars.sumBorrowPlusEffects =
                    mul_ScalarTruncateAddUInt(vars.oraclePrice, borrowAmount, vars.sumBorrowPlusEffects);
            }
        }

        return (vars.sumBorrowPlusEffects, vars.sumCollateral);
    }

    /**
     * @notice Helper function to calculate borrow with interest.
     * @dev Returns the sum of all cross-chain borrows with interest in underlying tokens.
     * For example, a return value of 1e6 for the USDC lToken, would be 1 USDC.
     * Loops through crossChainBorrows and crossChainCollaterals, as only 1 is populated for each borrow,
     * on each chain.
     * For example if a cross chain borrow was initiated on chain A, crossChainBorrows will be populated on chain A,
     * and crossChainCollaterals will be populated on chain B. The other will be empty.
     */
    function borrowWithInterest(address borrower, address _lToken) public view returns (uint256) { // 跨链
        address _token = lTokenToUnderlying[_lToken];
        uint256 borrowedAmount;

        Borrow[] memory borrows = crossChainBorrows[borrower][_token];
        Borrow[] memory collaterals = crossChainCollaterals[borrower][_token];
// 借款的底层资金 or 抵押物的价值
        require(borrows.length == 0 || collaterals.length == 0, "Invariant violated: both mappings populated");
        // Only one mapping should be populated:
        if (borrows.length > 0) {
            for (uint256 i = 0; i < borrows.length; i++) {
                if (borrows[i].srcEid == currentEid) {
                    borrowedAmount +=
                        (borrows[i].principle * LTokenInterface(_lToken).borrowIndex()) / borrows[i].borrowIndex;
                }
            }
        } else { // 不能两者并存吗?
            for (uint256 i = 0; i < collaterals.length; i++) {
                // Only include a cross-chain collateral borrow if it originated locally.
                if (collaterals[i].destEid == currentEid && collaterals[i].srcEid == currentEid) { // dest 和 src 都是当前链的同链情况？
                    borrowedAmount +=
                        (collaterals[i].principle * LTokenInterface(_lToken).borrowIndex()) / collaterals[i].borrowIndex;
                }
            }
        }
        return borrowedAmount;
    }

    /**
     * @notice Helper function to calculate same-chain borrow with interest.
     */
    function borrowWithInterestSame(address borrower, address _lToken) public view returns (uint256) { // 同链
        uint256 borrowIndex = borrowBalance[borrower][_lToken].borrowIndex;
        uint256 borrowBalanceSameChain = borrowIndex != 0
            ? (borrowBalance[borrower][_lToken].amount * uint256(LTokenInterface(_lToken).borrowIndex())) / borrowIndex
            : 0;
        return borrowBalanceSameChain;
    }

    /**
     * @notice Calculates the maximum amount a user can borrow of a specific asset
     * @dev Call with simulateContract as to not be charged gas fees for the call.
     * @param _borrower The address of the potential borrower
     * @param _lToken The lToken they want to borrow
     * @return maxBorrow The maximum amount that can be borrowed in USD.
     */
    function getMaxBorrowAmount(address _borrower, address _lToken) external returns (uint256) {
        // First accrue interest
        LTokenInterface(_lToken).accrueInterest(); // what if _lToken == address(0)?

        require(_lToken != address(0), "Unsupported Token");

        // Get current liquidity
        (uint256 borrowed, uint256 collateral) =
            getHypotheticalAccountLiquidityCollateral(_borrower, LToken(payable(_lToken)), 0, 0);

        // If borrowed >= collateral, they cannot borrow more
        if (borrowed >= collateral) {
            return 0;
        }

        // Calculate the maximum borrow amount
        uint256 maxBorrow = collateral - borrowed;

        return maxBorrow;
    }

    /**
     * @notice Calculates the maximum amount a user can repay of a specific asset.
     * @dev Call with simulateContract as to not be charged gas fees for the call.
     * @param borrower The address of the borrower
     * @param lToken The lToken being repaid
     * @param isSameChain Boolean indicating whether the repay is for same-chain borrows (true) or cross-chain borrows (false)
     * @return maxRepay The maximum amount that can be repaid
     */
    function getMaxRepayAmount(address borrower, address lToken, bool isSameChain) external returns (uint256) {
        // First accrue interest
        LTokenInterface(lToken).accrueInterest(); // what if lToken == address(0)?

        // Get the current borrow balance including interest
        uint256 currentBorrow = 0;

        // Calculate same-chain borrows with interest
        currentBorrow += isSameChain ? borrowWithInterestSame(borrower, lToken) : borrowWithInterest(borrower, lToken);

        return currentBorrow;
    }

    /**
     * @notice Calculates the maximum amount a user can repay of a specific asset for liquidation.
     * @param borrower The address of the borrower
     * @param lToken The lToken being repaid
     * @param isSameChain Boolean indicating whether the repay is for same-chain borrows (true) or cross-chain borrows (false)
     * @return maxRepay The maximum amount that can be repaid
     */
    function getMaxLiquidationRepayAmount(address borrower, address lToken, bool isSameChain)
        external
        view
        returns (uint256)
    {
        // Get the current borrow balance including interest
        uint256 currentBorrow = 0;

        // Calculate same-chain borrows with interest
        currentBorrow += isSameChain ? borrowWithInterestSame(borrower, lToken) : borrowWithInterest(borrower, lToken);

        // Get close factor from lendtroller (typically 0.5 or 50%)
        uint256 closeFactorMantissa = LendtrollerInterfaceV2(lendtroller).closeFactorMantissa();

        // Calculate max repay amount (currentBorrow * closeFactor)
        uint256 maxRepay = (currentBorrow * closeFactorMantissa) / 1e18;

        return maxRepay;
    }

    /**
     * @notice Calculates the maximum amount a user can withdraw of a specific asset
     * @dev Call with simulateContract as to not be charged gas fees for the call.
     * @param account The address of the user
     * @param lToken The lToken being withdrawn
     * @return maxWithdraw The maximum amount that can be withdrawn
     */
    function getMaxWithdrawable(address account, address lToken) external returns (uint256) {
        // First accrue interest
        LTokenInterface(lToken).accrueInterest();

        uint256 marketLiquidity = LTokenInterface(lToken).getCash();

        (uint256 sumBorrowPlusEffects, uint256 sumCollateral) =
            getHypotheticalAccountLiquidityCollateral(account, LToken(lToken), 0, 0);
        if (sumBorrowPlusEffects >= sumCollateral) {
            return 0; // No free collateral to withdraw
        }

        uint256 maxRedeemInUSD = sumCollateral - sumBorrowPlusEffects;
        uint256 exchangeRate = LTokenInterface(lToken).exchangeRateStored();
        uint256 oraclePrice = UniswapAnchoredViewInterface(priceOracle).getUnderlyingPrice(LToken(lToken));
        uint256 collateralFactor = LendtrollerInterfaceV2(lendtroller).getCollateralFactorMantissa(lToken);

        // tokensToDenom = collateralFactor * exchangeRate * price / 1e36
        uint256 tokensToDenom = (collateralFactor * exchangeRate * oraclePrice) / 1e36;

        // max lTokens = (maxRedeemInUSD * 1e18) / tokensToDenom
        uint256 redeemableLTokens = (maxRedeemInUSD * 1e18) / tokensToDenom;

        uint256 maxWithdrawUnderlying = (redeemableLTokens * exchangeRate) / 1e18;
        return min(marketLiquidity, maxWithdrawUnderlying);
    }

    function getTotalSupplied(address account, address lToken) external view returns (uint256) {
        // Can't use balanceOf because it's held by Routers.
        uint256 lTokenBalance = totalInvestment[account][lToken];
        // Use stored exchange rate, as it's view.
        uint256 exchangeRate = LTokenInterface(lToken).exchangeRateStored();

        return lTokenBalance * exchangeRate / 1e18;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a <= b) return a;
        return b;
    }

    /**
     * @notice Finds a specific cross chain borrow record
     * @param user The user address
     * @param underlying The underlying token address
     * @param srcEid Source chain ID
     * @param destEid Destination chain ID
     * @param borrowedlToken The borrowed lToken address
     * @return (bool, uint256) Returns (found, index)
     */
    function findCrossChainBorrow(
        address user,
        address underlying,
        uint256 srcEid,
        uint256 destEid,
        address borrowedlToken
    ) public view returns (bool, uint256) {
        Borrow[] memory userBorrows = crossChainBorrows[user][underlying];

        for (uint256 i = 0; i < userBorrows.length;) {
            if (
                userBorrows[i].srcEid == srcEid && userBorrows[i].destEid == destEid
                    && userBorrows[i].borrowedlToken == borrowedlToken
            ) {
                return (true, i);
            }
            unchecked {
                ++i;
            }
        }
        return (false, 0);
    }

    /**
     * @notice Finds a specific cross chain collateral record
     * @param user The user address
     * @param underlying The underlying token address
     * @param srcEid Source chain ID
     * @param destEid Destination chain ID
     * @param borrowedlToken The borrowed lToken address
     * @param srcToken The source token address
     * @return (bool, uint256) Returns (found, index)
     */
    function findCrossChainCollateral(
        address user,
        address underlying,
        uint256 srcEid,
        uint256 destEid,
        address borrowedlToken,
        address srcToken
    ) public view returns (bool, uint256) {
        Borrow[] memory userCollaterals = crossChainCollaterals[user][underlying];

        for (uint256 i = 0; i < userCollaterals.length;) {
            if (
                userCollaterals[i].srcEid == srcEid && userCollaterals[i].destEid == destEid
                    && userCollaterals[i].borrowedlToken == borrowedlToken && userCollaterals[i].srcToken == srcToken
            ) {
                return (true, i);
            }
            unchecked {
                ++i;
            }
        }
        return (false, 0);
    }
}
