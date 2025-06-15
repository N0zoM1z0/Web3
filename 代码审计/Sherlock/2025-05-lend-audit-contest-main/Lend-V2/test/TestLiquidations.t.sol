// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
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
import "@layerzerolabs/lz-evm-protocol-v2/test/utils/LayerZeroTest.sol";

contract TestLiquidations is LayerZeroTest {
    // State variables
    HelperConfig public helperConfig;
    address public layerZeroEndpoint;
    address[] public supportedTokensA;
    address[] public supportedTokensB;
    bool public isTestnet;
    address public deployer;
    address public liquidator;

    // Chain A (Source)
    CrossChainRouterMock public routerA;
    LendStorage public lendStorageA;
    CoreRouter public coreRouterA;
    Lendtroller public lendtrollerA;
    InterestRateModel public interestRateModelA;
    SimplePriceOracle public priceOracleA;
    address[] public lTokensA;

    // Chain B (Destination)
    CrossChainRouterMock public routerB;
    LendStorage public lendStorageB;
    CoreRouter public coreRouterB;
    Lendtroller public lendtrollerB;
    InterestRateModel public interestRateModelB;
    SimplePriceOracle public priceOracleB;
    address[] public lTokensB;

    uint32 constant CHAIN_A_ID = 1;
    uint32 constant CHAIN_B_ID = 2;

    EndpointV2 public endpointA;
    EndpointV2 public endpointB;

    // Events
    event LiquidateBorrow(
        address indexed liquidator, address indexed lToken, address indexed borrower, address lTokenCollateral
    );

    function setUp() public override(LayerZeroTest) {
        super.setUp();

        deployer = makeAddr("deployer");
        liquidator = makeAddr("liquidator");
        vm.deal(deployer, 1000 ether);
        vm.deal(liquidator, 1000 ether);

        // Deploy protocol on Chain A using the endpoint we just created
        Deploy deployA = new Deploy();
        (
            address priceOracleAddressA,
            address lendtrollerAddressA,
            address interestRateModelAddressA,
            address[] memory lTokenAddressesA,
            address payable routerAddressA,
            address payable coreRouterAddressA,
            address lendStorageAddressA,
            , //address _layerZeroEndpoint
            address[] memory _supportedTokensA
        ) = deployA.run(address(endpointA)); // Pass the endpoint address to Deploy.run

        // Store Chain A values
        routerA = CrossChainRouterMock(payable(routerAddressA));
        vm.label(address(routerA), "Router A");
        lendStorageA = LendStorage(lendStorageAddressA);
        vm.label(address(lendStorageA), "LendStorage A");
        coreRouterA = CoreRouter(coreRouterAddressA);
        vm.label(address(coreRouterA), "CoreRouter A");
        lendtrollerA = Lendtroller(lendtrollerAddressA);
        vm.label(address(lendtrollerA), "Lendtroller A");
        interestRateModelA = InterestRateModel(interestRateModelAddressA);
        vm.label(address(interestRateModelA), "InterestRateModel A");
        priceOracleA = SimplePriceOracle(priceOracleAddressA);
        vm.label(address(priceOracleA), "PriceOracle A");
        lTokensA = lTokenAddressesA;
        supportedTokensA = _supportedTokensA;

        // Deploy protocol on Chain B
        Deploy deployB = new Deploy();
        (
            address priceOracleAddressB,
            address lendtrollerAddressB,
            address interestRateModelAddressB,
            address[] memory lTokenAddressesB,
            address payable routerAddressB,
            address payable coreRouterAddressB,
            address lendStorageAddressB,
            , // address _layerZeroEndpoint
            address[] memory _supportedTokensB
        ) = deployB.run(address(endpointB));

        // Store Chain B values
        routerB = CrossChainRouterMock(payable(routerAddressB));
        vm.label(address(routerB), "Router B");
        lendStorageB = LendStorage(lendStorageAddressB);
        vm.label(address(lendStorageB), "LendStorage B");
        coreRouterB = CoreRouter(coreRouterAddressB);
        vm.label(address(coreRouterB), "CoreRouter B");
        lendtrollerB = Lendtroller(lendtrollerAddressB);
        vm.label(address(lendtrollerB), "Lendtroller B");
        interestRateModelB = InterestRateModel(interestRateModelAddressB);
        vm.label(address(interestRateModelB), "InterestRateModel B");
        priceOracleB = SimplePriceOracle(priceOracleAddressB);
        vm.label(address(priceOracleB), "PriceOracle B");
        lTokensB = lTokenAddressesB;
        supportedTokensB = _supportedTokensB;

        // Set up cross-chain mappings
        vm.startPrank(routerA.owner());
        for (uint256 i = 0; i < supportedTokensA.length; i++) {
            lendStorageA.addUnderlyingToDestUnderlying(supportedTokensA[i], supportedTokensB[i], CHAIN_B_ID);
            lendStorageA.addUnderlyingToDestlToken(supportedTokensA[i], lTokensB[i], CHAIN_B_ID);
            lendStorageA.setChainAssetMap(supportedTokensA[i], block.chainid, supportedTokensB[i]);
            lendStorageA.setChainLTokenMap(lTokensA[i], block.chainid, lTokensB[i]);
            lendStorageA.setChainLTokenMap(lTokensB[i], block.chainid, lTokensA[i]);
            console2.log("Mapped l token: ", lTokensA[i], "to", lTokensB[i]);
            console2.log("Mapping assets with chain: ", block.chainid);
        }
        vm.stopPrank();

        vm.startPrank(routerB.owner());
        for (uint256 i = 0; i < supportedTokensB.length; i++) {
            lendStorageB.addUnderlyingToDestUnderlying(supportedTokensB[i], supportedTokensA[i], CHAIN_A_ID);
            lendStorageB.addUnderlyingToDestlToken(supportedTokensB[i], lTokensA[i], CHAIN_A_ID);
            lendStorageB.setChainAssetMap(supportedTokensB[i], block.chainid, supportedTokensA[i]);
            lendStorageB.setChainLTokenMap(lTokensB[i], block.chainid, lTokensA[i]);
            lendStorageB.setChainLTokenMap(lTokensA[i], block.chainid, lTokensB[i]);
            console2.log("Mapped l token: ", lTokensB[i], "to", lTokensA[i]);
            console2.log("Mapping assets with chain: ", block.chainid);
        }
        vm.stopPrank();

        // Set up initial token prices
        for (uint256 i = 0; i < supportedTokensA.length; i++) {
            priceOracleA.setDirectPrice(supportedTokensA[i], 1e18);
        }
        for (uint256 i = 0; i < supportedTokensB.length; i++) {
            priceOracleB.setDirectPrice(supportedTokensB[i], 1e18);
        }

        // Set up router pairs
        routerA.setPairContract(payable(address(routerB)));
        routerB.setPairContract(payable(address(routerA)));

        vm.label(address(routerA), "Router A");
        vm.label(address(routerB), "Router B");
    }

    // Helper functions
    function _supplyA(address user, uint256 amount, uint256 tokenIndex)
        internal
        returns (address token, address lToken)
    {
        vm.deal(address(routerA), 1 ether);
        token = supportedTokensA[tokenIndex];
        lToken = lendStorageA.underlyingTolToken(token);

        vm.startPrank(user);
        ERC20Mock(token).mint(user, amount);
        IERC20(token).approve(address(coreRouterA), amount);
        coreRouterA.supply(amount, token);
        vm.stopPrank();
    }

    function _supplyB(address user, uint256 amount, uint256 tokenIndex)
        internal
        returns (address token, address lToken)
    {
        vm.deal(address(routerB), 1 ether);
        token = supportedTokensB[tokenIndex];
        lToken = lendStorageB.underlyingTolToken(token);

        vm.startPrank(user);
        ERC20Mock(token).mint(user, amount);
        IERC20(token).approve(address(coreRouterB), amount);
        coreRouterB.supply(amount, token);
        vm.stopPrank();
    }

    function _setupBorrowAndPriceDropScenario(
        uint256 supplyAmount,
        uint256 borrowAmount,
        uint256 newPrice,
        bool returnA
    ) internal returns (address tokenA, address tokenB, address lToken) {
        // Supply token0 as collateral on Chain A
        address lTokenA;
        (tokenA, lTokenA) = _supplyA(deployer, supplyAmount, 0);

        // Supply token1 as liquidity on Chain A from random wallet
        address lTokenB;
        (tokenB, lTokenB) = _supplyA(address(1), supplyAmount, 1);

        vm.prank(deployer);
        coreRouterA.borrow(borrowAmount, tokenB);

        // Simulate price drop of collateral (tokenA) only on first chain
        priceOracleA.setDirectPrice(tokenA, newPrice);
        // Simulate price drop of collateral (tokenA) only on second chain
        priceOracleB.setDirectPrice(
            lendStorageB.lTokenToUnderlying(lendStorageB.crossChainLTokenMap(lTokenA, block.chainid)), newPrice
        );

        return (tokenA, tokenB, returnA ? lTokenA : lTokenB);
    }

    function _setupBorrowCrossChainAndPriceDropScenario(uint256 supplyAmount, uint256 borrowAmount, uint256 newPrice)
        internal
        returns (address tokenA, address lTokenA)
    {
        // Supply collateral on Chain A
        (tokenA, lTokenA) = _supplyA(deployer, supplyAmount, 0);

        // Supply liquidity on Chain B for borrowing
        _supplyB(liquidator, supplyAmount * 2, 0);

        vm.deal(address(routerA), 1 ether); // For LayerZero fees

        // Borrow cross-chain from Chain A to Chain B
        vm.startPrank(deployer);
        routerA.borrowCrossChain(borrowAmount, tokenA, CHAIN_B_ID);
        vm.stopPrank();

        // Simulate price drop of collateral (tokenA) only on first chain
        priceOracleA.setDirectPrice(tokenA, newPrice);
        // Simulate price drop of collateral (tokenA) only on second chain
        priceOracleB.setDirectPrice(
            lendStorageB.lTokenToUnderlying(lendStorageB.crossChainLTokenMap(lTokenA, block.chainid)), newPrice
        );
    }

    // Test Functions
    function test_liquidation_after_price_drop(uint256 supplyAmount, uint256 borrowAmount, uint256 newPrice) public {
        // Bound inputs to reasonable values
        supplyAmount = bound(supplyAmount, 100e18, 1000e18);
        borrowAmount = bound(borrowAmount, 50e18, supplyAmount * 60 / 100); // Max 60% LTV
        newPrice = bound(newPrice, 1e16, 5e16); // 1-5% of original price

        // Supply token0 as collateral on Chain A
        (address tokenA, address lTokenA) = _supplyA(deployer, supplyAmount, 0);

        // Supply token1 as liquidity on Chain A from random wallet
        (address tokenB, address lTokenB) = _supplyA(address(1), supplyAmount, 1);

        vm.prank(deployer);
        coreRouterA.borrow(borrowAmount, tokenB);

        // Simulate price drop of collateral (tokenA) only on first chain
        priceOracleA.setDirectPrice(tokenA, newPrice);
        // Simulate price drop of collateral (tokenA) only on second chain
        priceOracleB.setDirectPrice(
            lendStorageB.lTokenToUnderlying(lendStorageB.crossChainLTokenMap(lTokenA, block.chainid)), newPrice
        );

        // Attempt liquidation
        vm.startPrank(liquidator);
        ERC20Mock(tokenB).mint(liquidator, borrowAmount);
        IERC20(tokenB).approve(address(coreRouterA), borrowAmount);

        // Expect LiquidateBorrow event
        vm.expectEmit(true, true, true, true);
        emit LiquidateBorrow(liquidator, lTokenB, deployer, lTokenA);

        // Repay 0.5% of the borrow
        uint256 repayAmount = borrowAmount / 200;

        coreRouterA.liquidateBorrow(deployer, repayAmount, lTokenA, tokenB);
        vm.stopPrank();

        // Verify liquidation was successful
        assertLt(
            lendStorageA.borrowWithInterest(deployer, lTokenB),
            borrowAmount,
            "Borrow should be reduced after liquidation"
        );
    }

    function test_liquidation_without_price_drop_always_reverts(
        uint256 supplyAmount,
        uint256 borrowAmount,
        uint256 newPrice
    ) public {
        // Bound inputs to reasonable values
        supplyAmount = bound(supplyAmount, 100e18, 1000e18);
        borrowAmount = bound(borrowAmount, 50e18, supplyAmount * 70 / 100); // Max 70% LTV
        newPrice = bound(newPrice, 1e18, 2e18); // 100-200% of original price

        // Supply token0 as collateral on Chain A
        (address tokenA, address lTokenA) = _supplyA(deployer, supplyAmount, 0);

        // Supply token1 as liquidity on Chain A from random wallet
        (address tokenB, address lTokenB) = _supplyA(address(1), supplyAmount, 1);

        vm.prank(deployer);
        coreRouterA.borrow(borrowAmount, tokenB);

        // Simulate price drop of collateral (tokenA) only on first chain
        priceOracleA.setDirectPrice(tokenA, newPrice);
        // Simulate price drop of collateral (tokenA) only on second chain
        priceOracleB.setDirectPrice(
            lendStorageB.lTokenToUnderlying(lendStorageB.crossChainLTokenMap(lTokenA, block.chainid)), newPrice
        );

        // Attempt liquidation
        vm.startPrank(liquidator);
        ERC20Mock(tokenB).mint(liquidator, borrowAmount);
        IERC20(tokenB).approve(address(coreRouterA), borrowAmount);

        // Repay 50% of the borrow
        uint256 repayAmount = borrowAmount * 5 / 10;

        vm.expectRevert();

        coreRouterA.liquidateBorrow(deployer, repayAmount, lTokenA, tokenB);
        vm.stopPrank();

        // Verify liquidation was successful
        assertLt(
            lendStorageA.borrowWithInterest(deployer, lTokenB),
            borrowAmount,
            "Borrow should be reduced after liquidation"
        );
    }

    // @fail
    function test_cross_chain_liquidation_after_price_drop(uint256 supplyAmount, uint256 borrowAmount, uint256 newPrice)
        public
    {
        // Bound inputs to reasonable values
        supplyAmount = bound(supplyAmount, 100e18, 1000e18);
        borrowAmount = bound(borrowAmount, 50e18, supplyAmount * 60 / 100); // Max 60% LTV
        newPrice = bound(newPrice, 1e14, 2e16); // 0.1-2% of original price

        // Supply collateral on Chain A
        (address tokenA, address lTokenA) = _supplyA(deployer, supplyAmount, 0);

        // Supply liquidity on Chain B for borrowing
        (address tokenB, address lTokenB) = _supplyB(liquidator, supplyAmount * 2, 0);

        vm.deal(address(routerA), 1 ether); // For LayerZero fees

        // Borrow cross-chain from Chain A to Chain B
        vm.startPrank(deployer);
        routerA.borrowCrossChain(borrowAmount, tokenA, CHAIN_B_ID);
        vm.stopPrank();

        // Simulate price drop of collateral (tokenA) only on first chain
        priceOracleA.setDirectPrice(tokenA, newPrice);
        // Simulate price drop of collateral (tokenA) only on second chain
        priceOracleB.setDirectPrice(
            lendStorageB.lTokenToUnderlying(lendStorageB.crossChainLTokenMap(lTokenA, block.chainid)), newPrice
        );

        // Set up liquidator with borrowed asset on Chain A
        vm.deal(liquidator, 1 ether);
        vm.startPrank(liquidator);

        // We need the Chain A version of the tokens for liquidation on Router A
        ERC20Mock(tokenA).mint(liquidator, borrowAmount);
        IERC20(tokenA).approve(address(routerA), borrowAmount);

        // Repay 50% of the borrow
        uint256 repayAmount = borrowAmount * 5 / 10;

        ERC20Mock(tokenB).mint(liquidator, 1e30);

        // approve router b to spend repay amount
        IERC20(tokenB).approve(address(coreRouterB), type(uint256).max);

        // Call liquidateBorrow on Router B (where the borrow exists)
        routerB.liquidateCrossChain(
            deployer, // borrower
            repayAmount, // amount to repay
            31337, // chain where the collateral exists
            lTokenB, // collateral lToken (on Chain B)
            tokenB // borrowed asset (Chain B version)
        );
        vm.stopPrank();

        // Verify liquidation was successful by checking the borrow was reduced
        assertLt(
            lendStorageB.borrowWithInterest(deployer, lendStorageB.underlyingTolToken(supportedTokensB[0])),
            borrowAmount,
            "Borrow should be reduced after liquidation"
        );
    }

    function test_cross_chain_liquidation_without_price_drop_always_reverts(
        uint256 supplyAmount,
        uint256 borrowAmount,
        uint256 price
    ) public {
        // Bound inputs to reasonable values
        supplyAmount = bound(supplyAmount, 100e18, 1000e18);
        borrowAmount = bound(borrowAmount, 50e18, supplyAmount * 70 / 100); // Max 70% LTV
        price = bound(price, 1e18, 2e18); // 100-200% of original price

        // Supply collateral on Chain A
        (address tokenA, address lTokenA) = _supplyA(deployer, supplyAmount, 0);

        // Supply liquidity on Chain B for borrowing
        (address tokenB, address lTokenB) = _supplyB(liquidator, supplyAmount * 2, 0);

        vm.deal(address(routerA), 1 ether); // For LayerZero fees

        // Borrow cross-chain from Chain A to Chain B
        vm.startPrank(deployer);
        routerA.borrowCrossChain(borrowAmount, tokenA, CHAIN_B_ID);
        vm.stopPrank();

        // Simulate price drop of collateral (tokenA) only on first chain
        priceOracleA.setDirectPrice(tokenA, price);
        // Simulate price drop of collateral (tokenA) only on second chain
        priceOracleB.setDirectPrice(
            lendStorageB.lTokenToUnderlying(lendStorageB.crossChainLTokenMap(lTokenA, block.chainid)), price
        );

        // Set up liquidator with borrowed asset on Chain A
        vm.deal(liquidator, 1 ether);
        vm.startPrank(liquidator);

        // We need the Chain A version of the tokens for liquidation on Router A
        ERC20Mock(tokenA).mint(liquidator, borrowAmount);
        IERC20(tokenA).approve(address(routerA), borrowAmount);

        // Repay 50% of the borrow
        uint256 repayAmount = borrowAmount * 5 / 10;

        ERC20Mock(tokenB).mint(liquidator, 1e30);
        IERC20(tokenB).approve(address(coreRouterB), type(uint256).max);

        // Attempt liquidation should revert since position is healthy
        vm.expectRevert();
        routerB.liquidateCrossChain(
            deployer, // borrower
            repayAmount, // amount to repay
            31337, // chain where the collateral exists
            lTokenB, // collateral lToken (on Chain B)
            tokenB // borrowed asset (Chain B version)
        );
        vm.stopPrank();

        // Verify borrow amount remains unchanged
        assertEq(
            lendStorageB.borrowWithInterest(deployer, lendStorageB.underlyingTolToken(supportedTokensB[0])),
            borrowAmount,
            "Borrow amount should remain unchanged"
        );
    }

    struct State {
        uint256 deployerLiquidationInvestment;
        uint256 liquidatorLiquidationInvestment;
        uint256 protocolReward;
        uint256 deployerLiquidationBorrow;
        uint256 borrowsLength;
        uint256 collateralsLength;
    }

    // @fail
    function test_cross_chain_storage_updates_after_liquidation(
        uint256 supplyAmount,
        uint256 borrowAmount,
        uint256 newPrice,
        uint256 repayAmount
    ) public {
        // Bound inputs to reasonable values
        supplyAmount = bound(supplyAmount, 100e18, 1000e18);
        borrowAmount = bound(borrowAmount, 50e18, supplyAmount * 60 / 100); // Max 60% LTV
        newPrice = bound(newPrice, 1e14, 2e16); // 0.1-2% of original price
        repayAmount = bound(repayAmount, borrowAmount * 25 / 100, borrowAmount * 50 / 100); // 25-50% of borrow

        // Setup initial state
        (address tokenA, address lTokenA) =
            _setupBorrowCrossChainAndPriceDropScenario(supplyAmount, borrowAmount, newPrice);

        address tokenB = supportedTokensB[0];
        address lTokenB = lendStorageB.underlyingTolToken(tokenB);

        State memory preState;
        State memory postState;

        // Get pre-liquidation state for Chain A
        preState.deployerLiquidationInvestment = lendStorageA.totalInvestment(deployer, lTokenA);
        preState.liquidatorLiquidationInvestment = lendStorageA.totalInvestment(liquidator, lTokenA);
        preState.protocolReward = lendStorageA.protocolReward(lTokenA);

        // Get pre-liquidation state for Chain B
        preState.deployerLiquidationBorrow = lendStorageB.borrowWithInterest(deployer, lTokenB);

        // Store initial crossChainBorrows and crossChainCollaterals lengths
        preState.borrowsLength = lendStorageA.getCrossChainBorrows(deployer, tokenA).length;
        preState.collateralsLength = lendStorageB.getCrossChainCollaterals(deployer, tokenB).length;

        // Execute liquidation
        vm.startPrank(liquidator);
        ERC20Mock(tokenB).mint(liquidator, 1e30);

        // approve router b to spend repay amount
        IERC20(tokenB).approve(address(coreRouterB), type(uint256).max);

        // Call liquidateBorrow on Router B (where the borrow exists)
        routerB.liquidateCrossChain(
            deployer, // borrower
            repayAmount, // amount to repay
            31337, // chain where the collateral exists
            lTokenB, // collateral lToken (on Chain B)
            tokenB // borrowed asset (Chain B version)
        );
        vm.stopPrank();

        // Get post-liquidation state for Chain A
        postState.deployerLiquidationInvestment = lendStorageA.totalInvestment(deployer, lTokenA);
        postState.liquidatorLiquidationInvestment = lendStorageA.totalInvestment(liquidator, lTokenA);
        postState.protocolReward = lendStorageA.protocolReward(lTokenA);

        // Get post-liquidation state for Chain B
        postState.deployerLiquidationBorrow = lendStorageB.borrowWithInterest(deployer, lTokenB);

        // Get final crossChainBorrows and crossChainCollaterals lengths
        postState.borrowsLength = lendStorageA.getCrossChainBorrows(deployer, tokenA).length;
        postState.collateralsLength = lendStorageB.getCrossChainCollaterals(deployer, tokenB).length;

        // Verify Chain A storage updates
        assertLt(
            postState.deployerLiquidationInvestment,
            preState.deployerLiquidationInvestment,
            "Borrower collateral should decrease"
        );
        assertGt(
            postState.liquidatorLiquidationInvestment,
            preState.liquidatorLiquidationInvestment,
            "Liquidator collateral should increase"
        );
        assertGt(postState.protocolReward, preState.protocolReward, "Protocol rewards should increase");

        // Verify Chain B storage updates
        assertLt(
            postState.deployerLiquidationBorrow, preState.deployerLiquidationBorrow, "Borrow amount should decrease"
        );

        // If full liquidation, arrays should be shorter
        if (repayAmount == preState.deployerLiquidationBorrow) {
            assertLt(
                postState.borrowsLength, preState.borrowsLength, "Borrows array should decrease for full liquidation"
            );
            assertLt(
                postState.collateralsLength,
                preState.collateralsLength,
                "Collaterals array should decrease for full liquidation"
            );
        } else {
            // For partial liquidation, arrays should maintain same length
            assertEq(
                postState.borrowsLength,
                preState.borrowsLength,
                "Borrows array should not change for partial liquidation"
            );
            assertEq(
                postState.collateralsLength,
                preState.collateralsLength,
                "Collaterals array should not change for partial liquidation"
            );
        }

        // Verify the difference in collateral matches protocol fee
        uint256 collateralDecrease = preState.deployerLiquidationInvestment - postState.deployerLiquidationInvestment;
        uint256 liquidatorIncrease =
            postState.liquidatorLiquidationInvestment - preState.liquidatorLiquidationInvestment;
        uint256 protocolIncrease = postState.protocolReward - preState.protocolReward;

        assertEq(
            collateralDecrease,
            liquidatorIncrease + protocolIncrease,
            "Collateral decrease should equal liquidator gain plus protocol fee"
        );

        // Verify the borrow was reduced by the repay amount
        assertEq(
            preState.deployerLiquidationBorrow - postState.deployerLiquidationBorrow,
            repayAmount,
            "Borrow reduction should equal repay amount"
        );
    }
}
