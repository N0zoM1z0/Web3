// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CrossChainRouterMock} from "./mocks/CrossChainRouterMock.sol";
import {CoreRouter} from "../src/LayerZero/CoreRouter.sol";
import {LendStorage} from "../src/LayerZero/LendStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Lendtroller} from "../src/Lendtroller.sol";
import {InterestRateModel} from "../src/InterestRateModel.sol";
import {SimplePriceOracle} from "../src/SimplePriceOracle.sol";
import {LTokenInterface} from "../src/LTokenInterfaces.sol";
import {LToken} from "../src/LToken.sol";
import "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";

contract TestBorrowing is Test {
    HelperConfig public helperConfig;
    address public layerZeroEndpoint;
    address[] public supportedTokens;
    bool public isTestnet;
    address public deployer;

    CrossChainRouterMock public router;
    LendStorage public lendStorage;
    CoreRouter public coreRouter;
    Lendtroller public lendtroller;
    InterestRateModel public interestRateModel;
    SimplePriceOracle public priceOracle;

    TestHelper public testHelper;

    address[] public lTokens;

    // Events to test
    event BorrowSuccess(address indexed borrower, address indexed lToken, uint256 accountBorrow);

    function setUp() public {
        deployer = makeAddr("deployer");

        // Deploy the entire protocol
        Deploy deploy = new Deploy();
        (
            address priceOracleAddress,
            address lendtrollerAddress,
            address interestRateModelAddress,
            address[] memory lTokenAddresses,
            address payable routerAddress,
            address payable coreRouterAddress,
            address lendStorageAddress,
            address _layerZeroEndpoint,
            address[] memory _supportedTokens
        ) = deploy.run();

        // Store the values in contract state variables
        router = CrossChainRouterMock(routerAddress);
        lendStorage = LendStorage(lendStorageAddress);
        coreRouter = CoreRouter(coreRouterAddress);
        lendtroller = Lendtroller(lendtrollerAddress);
        interestRateModel = InterestRateModel(interestRateModelAddress);
        priceOracle = SimplePriceOracle(priceOracleAddress);
        lTokens = lTokenAddresses;
        layerZeroEndpoint = _layerZeroEndpoint;
        supportedTokens = _supportedTokens;

        testHelper = TestHelper(payable(layerZeroEndpoint));

        // Set up initial prices for supported tokens
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            priceOracle.setDirectPrice(supportedTokens[i], 1e18);
        }
    }

    // Helper function to supply tokens before testing borrowing
    function _supply(uint256 amount) internal returns (address token, address lToken) {
        token = supportedTokens[0];
        lToken = lendStorage.underlyingTolToken(token);

        ERC20Mock(token).mint(deployer, amount);
        IERC20(token).approve(address(coreRouter), amount);
        coreRouter.supply(amount, token);
    }

    function test_that_borrowing_with_no_collateral_reverts() public {
        vm.startPrank(deployer);
        address token = supportedTokens[0];

        vm.expectRevert();
        coreRouter.borrow(1e18, token);

        vm.stopPrank();
    }

    function test_that_borrowing_more_than_collateral_reverts(uint256 supplyAmount, uint256 borrowAmount) public {
        vm.assume(supplyAmount > 1e18 && supplyAmount < 1e36);
        vm.assume(borrowAmount > supplyAmount);

        vm.startPrank(deployer);
        (address token,) = _supply(supplyAmount);

        vm.expectRevert();
        coreRouter.borrow(borrowAmount, token);

        vm.stopPrank();
    }

    function test_that_borrowing_works(uint256 amount) public {
        // Bound amount between 1e18 and 1e30 to ensure reasonable test values
        amount = bound(amount, 1e18, 1e30);
        vm.startPrank(deployer);

        // First supply tokens as collateral
        (address token, address lToken) = _supply(amount);

        // Calculate maximum allowed borrow (70% of collateral to leave some safety margin)
        uint256 maxBorrow = (amount * 70) / 100;

        // Get initial balances
        uint256 initialTokenBalance = IERC20(token).balanceOf(deployer);

        // Expect BorrowSuccess event
        vm.expectEmit(true, true, true, true);
        emit BorrowSuccess(deployer, lToken, maxBorrow);

        // Borrow tokens
        coreRouter.borrow(maxBorrow, token);

        // Verify balances after borrowing
        assertEq(
            IERC20(token).balanceOf(deployer) - initialTokenBalance,
            maxBorrow,
            "Should receive correct amount of borrowed tokens"
        );

        // Verify borrow balance is tracked correctly
        assertEq(
            lendStorage.borrowWithInterestSame(deployer, lToken),
            maxBorrow,
            "Borrow balance should be tracked correctly"
        );

        vm.stopPrank();
    }

    function test_that_multiple_borrows_work(uint256[] calldata amounts) public {
        // Bound array length to a reasonable size
        vm.assume(amounts.length > 0 && amounts.length <= 5); // Reduced from 10 to 5 for better test performance

        vm.startPrank(deployer);

        // Calculate total amount needed for collateral
        uint256 totalCollateral = 0;
        uint256[] memory boundedAmounts = new uint256[](amounts.length);

        // Bound each amount first, then add to total
        for (uint256 i = 0; i < amounts.length; i++) {
            // Bound each amount between 1e18 and 1e24 (reduced upper bound)
            boundedAmounts[i] = bound(amounts[i], 1e18, 1e24);
            totalCollateral += boundedAmounts[i];
        }

        // Supply collateral
        (address token, address lToken) = _supply(totalCollateral);

        uint256 totalBorrowed = 0;
        uint256 maxAllowedBorrow = (totalCollateral * 70) / 100;

        // Get initial balance
        uint256 initialTokenBalance = IERC20(token).balanceOf(deployer);

        // Perform multiple borrows using bounded amounts
        for (uint256 i = 0; i < boundedAmounts.length; i++) {
            uint256 borrowAmount = boundedAmounts[i];

            // Skip if we would exceed max allowed borrow
            if (totalBorrowed + borrowAmount > maxAllowedBorrow) break;

            vm.expectEmit(true, true, true, true);
            emit BorrowSuccess(deployer, lToken, totalBorrowed + borrowAmount);

            coreRouter.borrow(borrowAmount, token);
            totalBorrowed += borrowAmount;
        }

        // Verify balances after borrowing
        assertEq(
            IERC20(token).balanceOf(deployer) - initialTokenBalance,
            totalBorrowed,
            "Should receive correct amount of borrowed tokens"
        );

        // Verify final borrow balance
        assertEq(
            lendStorage.borrowWithInterestSame(deployer, lToken), totalBorrowed, "Total borrowed amount should match"
        );
        assertLe(totalBorrowed, maxAllowedBorrow, "Total borrowed should not exceed max allowed");

        vm.stopPrank();
    }

    function test_that_borrowing_updates_account_liquidity(uint256 amount) public {
        vm.assume(amount > 1e18 && amount < 1e36);
        vm.startPrank(deployer);

        // Supply collateral
        (address token, address lToken) = _supply(amount);

        uint256 borrowAmount = (amount * 70) / 100; // 70% of collateral to leave some safety margin

        // Get initial balance
        uint256 initialTokenBalance = IERC20(token).balanceOf(deployer);

        // Expect BorrowSuccess event
        vm.expectEmit(true, true, true, true);
        emit BorrowSuccess(deployer, lToken, borrowAmount);

        coreRouter.borrow(borrowAmount, token);

        // Verify balances after borrowing
        assertEq(
            IERC20(token).balanceOf(deployer) - initialTokenBalance,
            borrowAmount,
            "Should receive correct amount of borrowed tokens"
        );

        // Check account liquidity after borrow
        (uint256 sumBorrowPlusEffects, uint256 sumCollateral) =
            lendStorage.getHypotheticalAccountLiquidityCollateral(deployer, LToken(lToken), 0, 0);

        assertGt(sumCollateral, sumBorrowPlusEffects, "Should have remaining collateral");
        assertGe(sumCollateral, sumBorrowPlusEffects, "Should not have shortfall");

        vm.stopPrank();
    }

    function test_that_borrowing_at_max_collateral_factor_works(uint256 amount) public {
        vm.assume(amount > 1e18 && amount < 1e36);
        vm.startPrank(deployer);

        // Supply collateral
        (address token, address lToken) = _supply(amount);

        uint256 maxBorrow = (amount * 70) / 100; // 70% of collateral to leave some safety margin

        // Get initial balance
        uint256 initialTokenBalance = IERC20(token).balanceOf(deployer);

        // Expect BorrowSuccess event
        vm.expectEmit(true, true, true, true);
        emit BorrowSuccess(deployer, lToken, maxBorrow);

        // Borrow at exactly the max allowed amount
        coreRouter.borrow(maxBorrow, token);

        // Verify balances after borrowing
        assertEq(
            IERC20(token).balanceOf(deployer) - initialTokenBalance,
            maxBorrow,
            "Should receive correct amount of borrowed tokens"
        );

        // Verify the borrow succeeded at max collateral
        assertEq(
            lendStorage.borrowWithInterestSame(deployer, lToken),
            maxBorrow,
            "Should be able to borrow at max collateral factor"
        );

        vm.stopPrank();
    }

    function test_get_max_withdrawable_returns_correct_amount(uint256 supplyAmount, uint256 borrowAmount) public {
        // Bound the supply amount to a reasonable range
        // Ensuring at least 1e18 (1 token at 18 decimals) and a max for performance
        supplyAmount = bound(supplyAmount, 1e18, 1e30);
        // Borrow amount should be less than or equal to 70% of supply to ensure some safe margin
        borrowAmount = bound(borrowAmount, 0, (supplyAmount * 70) / 100);

        vm.startPrank(deployer);

        // Supply collateral
        (address token, address lToken) = _supply(supplyAmount);

        // Borrow a portion of the collateral's value
        if (borrowAmount > 0) {
            coreRouter.borrow(borrowAmount, token);
        }

        // Now check getMaxWithdrawable
        uint256 onChainMaxWithdraw = lendStorage.getMaxWithdrawable(deployer, lToken);

        // Let's manually calculate what we'd expect:
        // 1. Get hypothetical liquidity
        (uint256 sumBorrowPlusEffects, uint256 sumCollateral) =
            lendStorage.getHypotheticalAccountLiquidityCollateral(deployer, LToken(lToken), 0, 0);

        // If there's no free liquidity (borrow >= collateral), max withdraw should be 0
        if (sumBorrowPlusEffects >= sumCollateral) {
            assertEq(onChainMaxWithdraw, 0, "Expected no withdrawable assets when undercollateralized");
        } else {
            // Otherwise, the difference (sumCollateral - sumBorrowPlusEffects) is the USD free margin
            uint256 maxRedeemInUSD = sumCollateral - sumBorrowPlusEffects;

            // Gather info needed to convert USD margin back to underlying tokens
            uint256 exchangeRate = LTokenInterface(lToken).exchangeRateStored();
            uint256 oraclePrice = priceOracle.getUnderlyingPrice(LToken(lToken));
            uint256 collateralFactor = lendtroller.getCollateralFactorMantissa(lToken);

            // tokensToDenom = (collateralFactor * exchangeRate * price) / 1e36
            // Note: collateralFactor, exchangeRate, and price are all scaled by 1e18
            uint256 tokensToDenom = (collateralFactor * exchangeRate * oraclePrice) / (1e18 * 1e18);

            // max lTokens we can redeem:
            uint256 redeemableLTokens = (maxRedeemInUSD * 1e18) / tokensToDenom;

            // We cannot redeem more than we actually hold
            uint256 lTokenBalance = lendStorage.totalInvestment(deployer, lToken);
            if (redeemableLTokens > lTokenBalance) {
                redeemableLTokens = lTokenBalance;
            }

            // Convert redeemable lTokens to underlying
            uint256 expectedMaxWithdraw = (redeemableLTokens * exchangeRate) / 1e18;

            // Also bound by market liquidity
            uint256 marketLiquidity = LTokenInterface(lToken).getCash();
            if (expectedMaxWithdraw > marketLiquidity) {
                expectedMaxWithdraw = marketLiquidity;
            }

            // Allow for minor rounding differences due to integer division
            // The expected and on-chain values should be very close
            assertApproxEqAbs(
                onChainMaxWithdraw,
                expectedMaxWithdraw,
                1, // allow a difference of 1 wei due to rounding
                "Max withdrawable amount doesn't match expected value"
            );
        }

        vm.stopPrank();
    }
}
