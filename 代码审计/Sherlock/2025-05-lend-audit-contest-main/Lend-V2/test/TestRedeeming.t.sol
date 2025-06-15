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

contract TestRedeeming is Test {
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
    event RedeemSuccess(address indexed redeemer, address indexed lToken, uint256 redeemAmount, uint256 redeemTokens);

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

    // Helper function to supply tokens before testing redemption
    function _supply(uint256 amount) internal returns (address token, address lToken) {
        token = supportedTokens[0];
        lToken = lendStorage.underlyingTolToken(token);

        ERC20Mock(token).mint(deployer, amount);
        IERC20(token).approve(address(coreRouter), amount);
        coreRouter.supply(amount, token);
    }

    function test_that_redeeming_with_no_liquidity_reverts() public {
        vm.startPrank(deployer);
        address token = supportedTokens[0];
        address lToken = lendStorage.underlyingTolToken(token);

        vm.expectRevert("Insufficient balance");
        coreRouter.redeem(1e18, payable(lToken));

        vm.stopPrank();
    }

    function test_that_redeeming_with_insufficient_liquidity_reverts(uint256 supplyAmount, uint256 redeemAmount)
        public
    {
        vm.assume(supplyAmount > 1e18 && supplyAmount < 1e36);
        vm.assume(redeemAmount > supplyAmount);

        vm.startPrank(deployer);
        (, address lToken) = _supply(supplyAmount);

        vm.expectRevert();
        coreRouter.redeem(redeemAmount, payable(lToken));

        vm.stopPrank();
    }

    function test_that_redeeming_works(uint256 amount) public {
        vm.assume(amount > 1e18 && amount < 1e36);
        vm.startPrank(deployer);

        // First supply tokens
        (address token, address lToken) = _supply(amount);

        // Get initial balances
        uint256 initialUnderlyingBalance = IERC20(token).balanceOf(deployer);
        uint256 initialLTokenBalance = lendStorage.totalInvestment(deployer, lToken);

        // Calculate expected tokens based on exchange rate
        uint256 exchangeRate = LTokenInterface(lToken).exchangeRateStored();
        uint256 expectedUnderlying = (initialLTokenBalance * exchangeRate) / 1e18;

        // Expect RedeemSuccess event
        vm.expectEmit(true, true, true, true);
        emit RedeemSuccess(deployer, lToken, expectedUnderlying, initialLTokenBalance);

        coreRouter.redeem(initialLTokenBalance, payable(lToken));

        // Verify balances after redemption
        assertEq(
            IERC20(token).balanceOf(deployer) - initialUnderlyingBalance,
            expectedUnderlying,
            "Should receive correct amount of underlying tokens"
        );
        assertEq(
            lendStorage.totalInvestment(deployer, lToken),
            initialLTokenBalance - initialLTokenBalance,
            "Total investment should be reduced"
        );

        vm.stopPrank();
    }

    function test_that_partial_redemption_works(uint256 supplyAmount, uint256 redeemAmount) public {
        vm.assume(supplyAmount > 1e18 && supplyAmount < 1e36);

        vm.startPrank(deployer);

        // First supply tokens
        (, address lToken) = _supply(supplyAmount);

        // Get the actual lToken balance received
        uint256 initialInvestment = lendStorage.totalInvestment(deployer, lToken);

        // Adjust redeemAmount to be a portion of the actual lToken balance
        redeemAmount = bound(redeemAmount, 1, initialInvestment - 1); // Changed assumption

        coreRouter.redeem(redeemAmount, payable(lToken));

        assertEq(
            lendStorage.totalInvestment(deployer, lToken),
            initialInvestment - redeemAmount,
            "Investment should be reduced by redeemed amount"
        );
        assertGt(lendStorage.totalInvestment(deployer, lToken), 0, "Should still have remaining investment");

        vm.stopPrank();
    }

    function test_that_full_redemption_removes_supplied_asset(uint256 amount) public {
        vm.assume(amount > 1e18 && amount < 1e36);
        vm.startPrank(deployer);

        // First supply tokens
        (, address lToken) = _supply(amount);

        // Get the actual lToken balance received
        uint256 initialInvestment = lendStorage.totalInvestment(deployer, lToken);

        // Redeem full amount
        coreRouter.redeem(initialInvestment, payable(lToken));

        // Check if asset is removed from user's supplied assets
        (, uint256 sumCollateral) =
            lendStorage.getHypotheticalAccountLiquidityCollateral(deployer, LToken(lToken), 0, 0);

        assertEq(sumCollateral, 0, "Collateral should be zero after full redemption");
        assertEq(lendStorage.totalInvestment(deployer, lToken), 0, "Total investment should be zero");

        vm.stopPrank();
    }

    function test_that_multiple_redeems_work(uint256[] calldata amounts) public {
        vm.assume(amounts.length > 0 && amounts.length <= 10); // Test up to 10 redemptions
        vm.startPrank(deployer);

        // Calculate total amount needed and supply it
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += bound(amounts[i], 1e18, 1e30);
        }

        // Supply tokens and get the actual lToken balance
        (, address lToken) = _supply(totalAmount);
        uint256 initialInvestment = lendStorage.totalInvestment(deployer, lToken);
        uint256 remainingInvestment = initialInvestment;

        // Perform multiple redemptions
        for (uint256 i = 0; i < amounts.length; i++) {
            // Skip if we don't have enough remaining investment
            if (remainingInvestment <= 1) break;

            // Calculate a portion of the remaining investment to redeem
            uint256 redeemAmount = bound(amounts[i], 1, remainingInvestment - 1); // Ensure we leave at least 1 token

            coreRouter.redeem(redeemAmount, payable(lToken));
            remainingInvestment -= redeemAmount;
        }

        assertEq(
            lendStorage.totalInvestment(deployer, lToken),
            remainingInvestment,
            "Final investment should match remaining balance"
        );

        vm.stopPrank();
    }

    function test_that_redeeming_with_borrow_shortfall_reverts() public {
        vm.startPrank(deployer);

        // First supply tokens
        uint256 supplyAmount = 100e18;
        (address token, address lToken) = _supply(supplyAmount);

        // Get the actual lToken balance
        uint256 lTokenBalance = lendStorage.totalInvestment(deployer, lToken);

        // Borrow against the supply to create potential shortfall
        coreRouter.borrow(50e18, token); // Borrow 50% of supply

        vm.expectRevert();
        // Attempt to redeem full amount should fail due to shortfall
        coreRouter.redeem(lTokenBalance, payable(lToken));

        vm.stopPrank();
    }
}
