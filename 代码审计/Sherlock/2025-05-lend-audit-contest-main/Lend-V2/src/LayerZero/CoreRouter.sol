// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./LendStorage.sol";
import "../LToken.sol";
import "../LErc20Delegator.sol";
import "./interaces/LendtrollerInterfaceV2.sol";
import "./interaces/LendInterface.sol";
import "./interaces/UniswapAnchoredViewInterface.sol";

/**
 * @title CoreRouter
 * @notice Handles all same-chain lending operations including supply, borrow, redeem, and liquidate
 * @dev Works in conjunction with LendStorage for state management
 */
contract CoreRouter is Ownable, ExponentialNoError {
    using SafeERC20 for IERC20;

    // Storage contract reference
    LendStorage public immutable lendStorage;

    address public lendtroller;
    address public priceOracle;
    address public crossChainRouter;

    // Events
    event SupplySuccess(address indexed supplier, address indexed lToken, uint256 supplyAmount, uint256 supplyTokens);
    event RedeemSuccess(address indexed redeemer, address indexed lToken, uint256 redeemAmount, uint256 redeemTokens);
    event BorrowSuccess(address indexed borrower, address indexed lToken, uint256 accountBorrow);
    event RepaySuccess(address indexed repayBorrowPayer, address indexed lToken, uint256 repayBorrowAccountBorrows);
    event LiquidateBorrow(
        address indexed liquidator, address indexed lToken, address indexed borrower, address lTokenCollateral
    );

    constructor(address _lendStorage, address _priceOracle, address _lendtroller) {
        require(_lendStorage != address(0), "Invalid storage address");
        lendStorage = LendStorage(_lendStorage);
        priceOracle = _priceOracle;
        lendtroller = _lendtroller;
    }

    receive() external payable {}

    /**
     * @notice Sets the address of the cross-chain router
     * @param _crossChainRouter The address of the cross-chain router
     */
    function setCrossChainRouter(address _crossChainRouter) external onlyOwner {
        crossChainRouter = _crossChainRouter;
    }

    /**
     * @dev Allows users to supply tokens to mint lTokens in the Compound protocol.
     * @param _amount The amount of tokens to supply.
     * @param _token The address of the token to be supplied.
     */
    function supply(uint256 _amount, address _token) external {
        address _lToken = lendStorage.underlyingTolToken(_token);

        require(_lToken != address(0), "Unsupported Token");
// 以上其实已经隐式验证了whitelist
        require(_amount > 0, "Zero supply amount");

        // Transfer tokens from the user to the contract
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        _approveToken(_token, _lToken, _amount);

        // Get exchange rate before mint
        uint256 exchangeRateBefore = LTokenInterface(_lToken).exchangeRateStored();

        // Mint lTokens
        require(LErc20Interface(_lToken).mint(_amount) == 0, "Mint failed");

        // Calculate actual minted tokens using exchangeRate from before mint
        uint256 mintTokens = (_amount * 1e18) / exchangeRateBefore;

        lendStorage.addUserSuppliedAsset(msg.sender, _lToken);

        lendStorage.distributeSupplierLend(_lToken, msg.sender);

        // Update total investment using calculated mintTokens
        lendStorage.updateTotalInvestment(
            msg.sender, _lToken, lendStorage.totalInvestment(msg.sender, _lToken) + mintTokens
        );

        emit SupplySuccess(msg.sender, _lToken, _amount, mintTokens);
    }

    /**
     * @dev Redeems lTokens for underlying tokens and transfers them to the user.
     * @param _amount The amount of lTokens to redeem.
     * @param _lToken The address of the lToken to be redeemed.
     * @return An enum indicating the error status.
     */
    function redeem(uint256 _amount, address payable _lToken) external returns (uint256) {
        // Redeem lTokens
        address _token = lendStorage.lTokenToUnderlying(_lToken);

        require(_amount > 0, "Zero redeem amount");

        // Check if user has enough balance before any calculations
        require(lendStorage.totalInvestment(msg.sender, _lToken) >= _amount, "Insufficient balance");

        // Check liquidity
        (uint256 borrowed, uint256 collateral) =
            lendStorage.getHypotheticalAccountLiquidityCollateral(msg.sender, LToken(_lToken), _amount, 0);
        require(collateral >= borrowed, "Insufficient liquidity");

        // Get exchange rate before redeem
        uint256 exchangeRateBefore = LTokenInterface(_lToken).exchangeRateStored();

        // Calculate expected underlying tokens
        uint256 expectedUnderlying = (_amount * exchangeRateBefore) / 1e18;

        // Perform redeem
        require(LErc20Interface(_lToken).redeem(_amount) == 0, "Redeem failed");

        // Transfer underlying tokens to the user
        IERC20(_token).transfer(msg.sender, expectedUnderlying);

        // Update total investment
        lendStorage.distributeSupplierLend(_lToken, msg.sender);
        uint256 newInvestment = lendStorage.totalInvestment(msg.sender, _lToken) - _amount;
        lendStorage.updateTotalInvestment(msg.sender, _lToken, newInvestment);

        if (newInvestment == 0) {
            lendStorage.removeUserSuppliedAsset(msg.sender, _lToken);
        }

        emit RedeemSuccess(msg.sender, _lToken, expectedUnderlying, _amount);

        return 0;
    }

    /**
     * @notice Borrows tokens using supplied collateral
     * @param _amount Amount of tokens to borrow
     * @param _token Address of the token to borrow
     */
    function borrow(uint256 _amount, address _token) external {
        require(_amount != 0, "Zero borrow amount");

        address _lToken = lendStorage.underlyingTolToken(_token);
// missing check : require(_lToken != address(0), "Unsupported Token"); 缺少检查导致对新借款的流动性计算被完全跳过
        LTokenInterface(_lToken).accrueInterest();
// start
        (uint256 borrowed, uint256 collateral) =
            lendStorage.getHypotheticalAccountLiquidityCollateral(msg.sender, LToken(payable(_lToken)), 0, _amount);

        LendStorage.BorrowMarketState memory currentBorrow = lendStorage.getBorrowBalance(msg.sender, _lToken);

        uint256 borrowAmount = currentBorrow.borrowIndex != 0
            ? ((borrowed * LTokenInterface(_lToken).borrowIndex()) / currentBorrow.borrowIndex) // with interest
            : 0;

        require(collateral >= borrowAmount, "Insufficient collateral");
// end   !!!confused!!! to be check
        // Enter the Compound market
        enterMarkets(_lToken);

        // Borrow tokens
        require(LErc20Interface(_lToken).borrow(_amount) == 0, "Borrow failed");

        // Transfer borrowed tokens to the user
        IERC20(_token).transfer(msg.sender, _amount);

        lendStorage.distributeBorrowerLend(_lToken, msg.sender);

        // Update records
        if (currentBorrow.borrowIndex != 0) {
            uint256 _newPrinciple =
                (currentBorrow.amount * LTokenInterface(_lToken).borrowIndex()) / currentBorrow.borrowIndex;
// with interest
            lendStorage.updateBorrowBalance(
                msg.sender, _lToken, _newPrinciple + _amount, LTokenInterface(_lToken).borrowIndex()
            );
        } else {
            lendStorage.updateBorrowBalance(msg.sender, _lToken, _amount, LTokenInterface(_lToken).borrowIndex());
        }

        lendStorage.addUserBorrowedAsset(msg.sender, _lToken);

        // Emit BorrowSuccess event
        emit BorrowSuccess(msg.sender, _lToken, lendStorage.getBorrowBalance(msg.sender, _lToken).amount);
    }

    /**
     * @dev Only callable by CrossChainRouter
     */
    function borrowForCrossChain(address _borrower, uint256 _amount, address _destlToken, address _destUnderlying)
        external // 跨链
    { // 依赖CrossChainRouter 完成所有检查和状态更新 (checked ✔️)
        require(crossChainRouter != address(0), "CrossChainRouter not set");

        require(msg.sender == crossChainRouter, "Access Denied"); // ACL check

        require(LErc20Interface(_destlToken).borrow(_amount) == 0, "Borrow failed");

        IERC20(_destUnderlying).transfer(_borrower, _amount);
    }

    /**
     * @notice Repays borrowed tokens
     * @param _amount The amount of tokens to repay. Pass `type(uint).max` to repay the maximum borrow amount.
     * @param _lToken The address of the lToken representing the borrowed asset
     */
    function repayBorrow(uint256 _amount, address _lToken) public {
        repayBorrowInternal(msg.sender, msg.sender, _amount, _lToken, true);
    }

    function repayCrossChainLiquidation(address _borrower, address _liquidator, uint256 _amount, address _lToken)
        external
    {
        require(msg.sender == crossChainRouter, "Access Denied");
        repayBorrowInternal(_borrower, _liquidator, _amount, _lToken, false);
    }

    /**
     * @notice Liquidates a borrower's position for same chain borrows.
     * @param borrower The address of the borrower
     * @param repayAmount The amount to repay
     * @param lTokenCollateral The address of the collateral lToken
     * @param borrowedAsset The address of the asset that was borrowed
     */
    function liquidateBorrow(address borrower, uint256 repayAmount, address lTokenCollateral, address borrowedAsset)
        external // 同链的清算
    { // 允许一个清算人 (msg.sender) 介入一个抵押不足的借款人 (borrower) 的头寸。清算人会代表借款人偿还一部分被借资产 (repayAmount 数量的 borrowedAsset)，并作为回报获得一部分借款人的抵押品 (lTokenCollateral)，通常带有一定的折扣（清算激励）。此函数处理的是同一条链上的清算。
        // The lToken of the borrowed asset
        address borrowedlToken = lendStorage.underlyingTolToken(borrowedAsset);
// missing check : require(borrowedlToken != address(0), "Unsupported Token");
        LTokenInterface(borrowedlToken).accrueInterest();

        (uint256 borrowed, uint256 collateral) =
            lendStorage.getHypotheticalAccountLiquidityCollateral(borrower, LToken(payable(borrowedlToken)), 0, 0);

        liquidateBorrowInternal(
            msg.sender, borrower, repayAmount, lTokenCollateral, payable(borrowedlToken), collateral, borrowed
        );
    }

    /**
     * @notice Internal function to liquidate a borrower's position
     * @param liquidator The address of the liquidator
     * @param borrower The address of the borrower
     * @param repayAmount The amount to repay
     * @param lTokenCollateral The address of the collateral lToken
     * @param borrowedlToken The address of the borrowing lToken
     * @param collateral The collateral amount
     * @param borrowed The borrowed amount
     */
    function liquidateBorrowInternal(
        address liquidator,
        address borrower,
        uint256 repayAmount,
        address lTokenCollateral,
        address payable borrowedlToken,
        uint256 collateral,
        uint256 borrowed
    ) internal {
        require(
            liquidateBorrowAllowedInternal(borrowedlToken, borrower, repayAmount, collateral, borrowed) == 0,
            "Borrow not allowed"
        );
        require(borrower != liquidator, "Liquidator cannot be borrower");
        require(repayAmount > 0, "Repay amount not zero");

        repayBorrowInternal(borrower, liquidator, repayAmount, borrowedlToken, true);

        // Liquidation logic for same chain
        liquidateSeizeUpdate(msg.sender, borrower, lTokenCollateral, borrowedlToken, repayAmount);
    }

    function liquidateSeizeUpdate(
        address sender,
        address borrower,
        address lTokenCollateral,
        address borrowedlToken,
        uint256 repayAmount
    ) internal { // 在清算人成功替借款人偿还一部分债务后，计算清算人应得的抵押品数量，并执行相应的状态更新和抵押品划转（逻辑上的，实际的 lToken 转移由更新 totalInvestment 体现）
        (uint256 amountSeizeError, uint256 seizeTokens) = LendtrollerInterfaceV2(lendtroller)
            .liquidateCalculateSeizeTokens(borrowedlToken, lTokenCollateral, repayAmount);
        require(amountSeizeError == 0, "Failed to calculate");

        // Revert if borrower collateral token balance < seizeTokens
        require(lendStorage.totalInvestment(borrower, lTokenCollateral) >= seizeTokens, "Insufficient collateral");

        uint256 currentReward = mul_(seizeTokens, Exp({mantissa: lendStorage.PROTOCOL_SEIZE_SHARE_MANTISSA()}));
// Calculate the protocol's share of the seized tokens
        // Just for safety, Never gonna occur
        if (currentReward >= seizeTokens) {
            currentReward = 0;
        }

        // Update protocol reward
        lendStorage.updateProtocolReward(lTokenCollateral, lendStorage.protocolReward(lTokenCollateral) + currentReward);

        // Distribute rewards
        lendStorage.distributeSupplierLend(lTokenCollateral, sender);
        lendStorage.distributeSupplierLend(lTokenCollateral, borrower);

        // Update total investment
        lendStorage.updateTotalInvestment(
            borrower, lTokenCollateral, lendStorage.totalInvestment(borrower, lTokenCollateral) - seizeTokens
        );
        lendStorage.updateTotalInvestment(
            sender,
            lTokenCollateral,
            lendStorage.totalInvestment(sender, lTokenCollateral) + (seizeTokens - currentReward)
        );

        // Emit LiquidateBorrow event
        emit LiquidateBorrow(sender, borrowedlToken, borrower, lTokenCollateral);
    }

    /**
     * @notice Checks if liquidation is allowed
     * @param lTokenBorrowed The address of the borrowing lToken
     * @param borrower The address of the borrower
     * @param repayAmount The amount to repay
     * @param collateral The collateral amount
     * @param borrowed The borrowed amount
     * @return uint An error code (0 if no error)
     */
    function liquidateBorrowAllowedInternal(
        address payable lTokenBorrowed,
        address borrower,
        uint256 repayAmount,
        uint256 collateral,
        uint256 borrowed
    ) internal view returns (uint256) {
        // Determine borrowIndex and borrowAmount based on chain type
        LendStorage.BorrowMarketState memory borrowBalance = lendStorage.getBorrowBalance(borrower, lTokenBorrowed);

        // Allow accounts to be liquidated if the market is deprecated
        if (LendtrollerInterfaceV2(lendtroller).isDeprecated(LToken(lTokenBorrowed))) {
            require(borrowBalance.amount >= repayAmount, "Repay > total borrow"); // 这里的未计入利息; 应该允许偿还全部
        } else {
            // The borrower must have shortfall in order to be liquidatable
            uint256 borrowedAmount;

            // For same-chain liquidations, calculate borrowed amount using the borrowBalance's index
            borrowedAmount = // 这里的borrowd是借款人的所有借款（同链 + 跨链） （通过getHypotheticalAccountLiquidityCollateral获取的是整个的借款）
                (borrowed * uint256(LTokenInterface(lTokenBorrowed).borrowIndex())) / borrowBalance.borrowIndex;
// 但 lTokenBorrowed 是当前被清算市场的 用整个账户的总负债价值，去乘以特定市场的借款指数比率，这在数学和逻辑上都是完全错误的。 它无法得出任何有意义的关于“lTokenBorrowed 市场当前债务价值”的结果。
            require(borrowedAmount > collateral, "Insufficient shortfall");
// 这里的检查使用的当前市场的与collateral(总的抵押物价值)比较，应该用总价值
            /* The liquidator may not repay more than what is allowed by the closeFactor */
            uint256 maxClose = mul_ScalarTruncate(
                Exp({mantissa: LendtrollerInterfaceV2(lendtroller).closeFactorMantissa()}), borrowBalance.amount
            ); // maxClose的计算 borrowBalance.amount 未考虑累计的利息 

            require(repayAmount <= maxClose, "Too much repay");
        }

        return 0;
    }

    /**
     * @notice Claims LEND tokens for users
     * @param holders Array of addresses to claim for
     * @param lTokens Array of lToken markets
     * @param borrowers Whether to claim for borrowers
     * @param suppliers Whether to claim for suppliers
     */
    function claimLend(address[] memory holders, LToken[] memory lTokens, bool borrowers, bool suppliers) external {
    // external允许外部调用，且有极高的gas消耗
        LendtrollerInterfaceV2(lendtroller).claimLend(address(this));

        for (uint256 i = 0; i < lTokens.length;) {
            address lToken = address(lTokens[i]);

            if (borrowers) {
                for (uint256 j = 0; j < holders.length;) {
                    lendStorage.distributeBorrowerLend(lToken, holders[j]);
                    unchecked {
                        ++j;
                    }
                }
            }

            if (suppliers) {
                for (uint256 j = 0; j < holders.length;) {
                    lendStorage.distributeSupplierLend(lToken, holders[j]);
                    unchecked {
                        ++j;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }

        for (uint256 j = 0; j < holders.length;) {
            uint256 accrued = lendStorage.lendAccrued(holders[j]);
            if (accrued > 0) {
                grantLendInternal(holders[j], accrued);
            }
            unchecked {
                ++j;
            }
        }
    }

    /**
     * @dev Grants LEND tokens to a user
     * @param user The recipient
     * @param amount The amount to grant
     * @return uint256 Remaining amount if grant failed
     */
    function grantLendInternal(address user, uint256 amount) internal returns (uint256) {
        address lendAddress = LendtrollerInterfaceV2(lendtroller).getLendAddress();
        uint256 lendBalance = IERC20(lendAddress).balanceOf(address(this));

        if (amount > 0 && amount <= lendBalance) {
            IERC20(lendAddress).safeTransfer(user, amount);
            return 0;
        }
        return amount;
    }

    /**
     * @dev Enters markets in the lendtroller
     * @param _lToken The lToken market to enter
     */
    function enterMarkets(address _lToken) internal {
        address[] memory lTokens = new address[](1);
        lTokens[0] = _lToken;
        LendtrollerInterfaceV2(lendtroller).enterMarkets(lTokens);
    }

    /**
     * @dev Approves tokens for spending
     * @param _token The token to approve
     * @param _approvalAddress The address to approve
     * @param _amount The amount to approve
     */
    function _approveToken(address _token, address _approvalAddress, uint256 _amount) internal {
        uint256 currentAllowance = IERC20(_token).allowance(address(this), _approvalAddress);
        if (currentAllowance < _amount) {
            if (currentAllowance > 0) {
                IERC20(_token).safeApprove(_approvalAddress, 0);
            }
            IERC20(_token).safeApprove(_approvalAddress, _amount);
        }
    }

    /**
     * @notice Internal function to repay borrowed tokens
     * @param borrower The address of the borrower
     * @param _amount The amount of tokens to repay
     * @param _lToken The address of the lToken representing the borrowed asset
     */
    function repayBorrowInternal(
        address borrower,
        address liquidator,
        uint256 _amount,
        address _lToken,
        bool _isSameChain
    ) internal { // 不仅限于同链
        address _token = lendStorage.lTokenToUnderlying(_lToken);

        LTokenInterface(_lToken).accrueInterest();

        uint256 borrowedAmount;

        if (_isSameChain) {
            borrowedAmount = lendStorage.borrowWithInterestSame(borrower, _lToken);
        } else {
            borrowedAmount = lendStorage.borrowWithInterest(borrower, _lToken);
        }

        require(borrowedAmount > 0, "Borrowed amount is 0");

        uint256 repayAmountFinal = _amount == type(uint256).max ? borrowedAmount : _amount;
// 允许超额还款
        // Transfer tokens from the liquidator to the contract
        IERC20(_token).safeTransferFrom(liquidator, address(this), repayAmountFinal);

        _approveToken(_token, _lToken, repayAmountFinal);

        lendStorage.distributeBorrowerLend(_lToken, borrower);

        // Repay borrowed tokens
        require(LErc20Interface(_lToken).repayBorrow(repayAmountFinal) == 0, "Repay failed");

        // Update same-chain borrow balances
        if (repayAmountFinal == borrowedAmount) { // 跨链的情况没有进行remove！！！ removeCrossChainBorrow 有没有可能是在CrossChainRouter里面更新了？ to be check
            lendStorage.removeBorrowBalance(borrower, _lToken); // 后面发现确实在CrossChainRouter里面更新了
            lendStorage.removeUserBorrowedAsset(borrower, _lToken);
        } else { // updateCrossChainBorrow 
            lendStorage.updateBorrowBalance(
                borrower, _lToken, borrowedAmount - repayAmountFinal, LTokenInterface(_lToken).borrowIndex()
            );
        }

        // Emit RepaySuccess event
        emit RepaySuccess(borrower, _lToken, repayAmountFinal);
    }
}
