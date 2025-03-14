// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {IStrategy} from "../src/interfaces/IStrategy.sol";
import {IUniswapV3Pool} from "../src/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Strategy} from "../src/Strategy.sol";
import {IMainnetRouter} from "../src/interfaces/IMainnetRouter.sol";
import {IPriceFeed} from "../src/interfaces/IPriceFeed.sol";
import {ILendingPool} from "../src/interfaces/ILendingPool.sol";
import {ILeverager} from "../src/interfaces/ILeverager.sol";
import {IyToken} from "../src/interfaces/IyToken.sol";
import {LiquidityAmounts} from "../src/libraries/LiquidityAmounts.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {BaseTest} from "./BaseTest.sol";
import {Leverager} from "../src/Leverager.sol";
import {PriceFeed} from "../src/PriceFeed.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {MockOracle} from "./utils/MockOracle.sol";
import {DataTypes} from "../src/types/DataTypes.sol";

contract LeveragerTest is BaseTest {
    address leverager;
    address lendingPool;
    address priceFeed;
    address wbtcOracle;
    address usdcOracle;
    address wethOracle;

    address lender = address(123456);
    address liquidator = address(21873781);

    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address yWeth;
    address yUsdc;
    address yWbtc;

    function setUp() public override {
        super.setUp();
        vm.startPrank(owner);

        priceFeed = address(new PriceFeed());
        wbtcOracle = address(new MockOracle());
        usdcOracle = address(new MockOracle());
        wethOracle = address(new MockOracle());

        IPriceFeed(priceFeed).setChainlinkPriceFeed(address(wbtc), wbtcOracle, 604800);
        IPriceFeed(priceFeed).setChainlinkPriceFeed(address(usdc), usdcOracle, 604800);
        IPriceFeed(priceFeed).setChainlinkPriceFeed(address(weth), wethOracle, 604800);

        lendingPool = address(new LendingPool());

        ILendingPool(lendingPool).initReserve(address(wbtc));
        ILendingPool(lendingPool).initReserve(address(usdc));
        ILendingPool(lendingPool).initReserve(address(weth));

        leverager = address(new Leverager("", "", lendingPool));
        ILeverager(leverager).initVault(address(vault), 1_000_000e18, 5e18, 0.1e18, 1e27);

        ILendingPool(lendingPool).setLeverager(leverager);
        ILendingPool(lendingPool).setLeverageParams(address(wbtc), type(uint256).max, type(uint256).max);
        ILendingPool(lendingPool).setLeverageParams(address(usdc), type(uint256).max, type(uint256).max);
        ILendingPool(lendingPool).setLeverageParams(address(weth), type(uint256).max, type(uint256).max);
        ILeverager(leverager).setPriceFeed(priceFeed);
        ILeverager(leverager).enableTokenAsBorrowed(address(weth));
        MockOracle(wbtcOracle).setPrice(100_000e18);
        MockOracle(usdcOracle).setPrice(1e18);
        MockOracle(wethOracle).setPrice(2500e18);

        ILeverager(leverager).setSwapRouter(uniRouter);

        yWeth = ILendingPool(lendingPool).getYTokenAddress(address(weth));
        yUsdc = ILendingPool(lendingPool).getYTokenAddress(address(usdc));
        yWbtc = ILendingPool(lendingPool).getYTokenAddress(address(wbtc));

        // add some funds to borrow from.
        vm.startPrank(lender);
        wbtc.approve(lendingPool, 10e8);
        deal(address(wbtc), lender, 10e8);
        ILendingPool(lendingPool).deposit(address(wbtc), 10e8, lender);

        usdc.approve(lendingPool, 250_000e6);
        deal(address(usdc), lender, 250_000e6);
        ILendingPool(lendingPool).deposit(address(usdc), 250_000e6, lender);

        weth.approve(lendingPool, 1000e18);
        deal(address(weth), lender, 1000e18);
        ILendingPool(lendingPool).deposit(address(weth), 1000e18, lender);

        uint256 borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        assertEq(borrowingRate, 0);
    }

    function test_cantOpenPositionWhenReserveInactive() external {
        uint256 borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        assertEq(borrowingRate, 0);
        vm.startPrank(owner);
        ILendingPool(lendingPool).freezeReserve(address(wbtc));

        skip(6 minutes);

        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 100_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 0.6e8;
        lp.denomination = address(wbtc);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 100_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        vm.expectRevert("reserve frozen");
        ILeverager(leverager).openLeveragedPosition(lp);

        vm.startPrank(owner);
        ILendingPool(lendingPool).unFreezeReserve(address(wbtc));

        vm.startPrank(depositor);
        ILeverager(leverager).openLeveragedPosition(lp);
    }

    function test_LendingPool() external {
        vm.startPrank(lender);
        wbtc.approve(lendingPool, 10e8);
        deal(address(wbtc), lender, 10e8);

        ILendingPool(lendingPool).deposit(address(wbtc), 10e8, lender);

        uint256 borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        assertEq(borrowingRate, 0);

        skip(6 minutes);

        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 100_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 0.6e8;
        lp.denomination = address(wbtc);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 100_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        ILeverager(leverager).openLeveragedPosition(lp);

        vm.startPrank(rebalancer);
        IStrategy(strategy).compound();
        vm.stopPrank();

        borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        console.log("%e", borrowingRate);

        uint256 exchangeRate = ILendingPool(lendingPool).exchangeRateOfReserve(address(wbtc));
        console.log(exchangeRate);

        skip(1 weeks);
        exchangeRate = ILendingPool(lendingPool).exchangeRateOfReserve(address(wbtc));
        console.log(exchangeRate);

        swapUsdc(10_000_000e6); // should be enough to make position usdc only
        MockOracle(usdcOracle).setPrice(0.1e18);
        assertEq(ILeverager(leverager).isLiquidateable(1), true);

        vm.startPrank(liquidator);
        deal(address(wbtc), liquidator, 0.51e8);
        wbtc.approve(leverager, 0.51e8);

        ILeverager.LiquidateParams memory liqParams;
        liqParams.id = 1;

        ILeverager(leverager).liquidatePosition(liqParams);

        borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        assertEq(borrowingRate, 0);
    }

    function test_LendingPoolRepaymentAndClaim() external {
        vm.startPrank(lender);
        wbtc.approve(lendingPool, 10e8);
        deal(address(wbtc), lender, 10e8);

        ILendingPool(lendingPool).deposit(address(wbtc), 10e8, lender);

        uint256 borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        assertEq(borrowingRate, 0);

        skip(6 minutes);

        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 100_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 0.6e8;
        lp.denomination = address(wbtc);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 100_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        uint256 posId = ILeverager(leverager).openLeveragedPosition(lp);

        skip(52 weeks);
        uint256 newIndex = ILendingPool(lendingPool).getCurrentBorrowingIndex(address(wbtc));
        uint256 owedwbtc = 0.5e8 * newIndex / 1e27 - 0.5e8;

        // we do not actually need to deal the user any funds, as the position covers everything.
        // deal(address(wbtc), depositor, owedwbtc);

        ILeverager.WithdrawParams memory wp;
        wp.id = posId;
        wp.pctWithdraw = 1e18;

        ILeverager(leverager).withdraw(wp);

        vm.startPrank(lender);
        uint256 yBal = IERC20(yWbtc).balanceOf(lender);

        IERC20(yWbtc).approve(lendingPool, type(uint256).max);
        uint256 received = ILendingPool(lendingPool).redeem(address(wbtc), yBal, lender);
        assertApproxEqAbs(received, 20e8 + owedwbtc - 1000, 10); // 20e8 were the reserves within the pool, 1000 wei are burned upon first deposit
    }


    function test_LendingPoolRepaymentFromBorrower() external {
        vm.startPrank(lender);
        wbtc.approve(lendingPool, 10e8);
        deal(address(wbtc), lender, 10e8);

        ILendingPool(lendingPool).deposit(address(wbtc), 10e8, lender);

        uint256 borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        assertEq(borrowingRate, 0);

        skip(6 minutes);

        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0;
        lp.amount1In = 50_000e6;
        lp.vault0In = 0.5e8;
        lp.vault1In = 50_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 0.6e8;
        lp.denomination = address(wbtc);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 100_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        uint256 posId = ILeverager(leverager).openLeveragedPosition(lp);

        skip(52 weeks);
        uint256 newIndex = ILendingPool(lendingPool).getCurrentBorrowingIndex(address(wbtc));
        uint256 owedwbtc = 0.5e8 * newIndex / 1e27 - 0.5e8;


        deal(address(wbtc), depositor, owedwbtc + 100); // minting a few wei extra as the withdraw from the vault rounds down

        ILeverager.WithdrawParams memory wp;
        wp.id = posId;
        wp.pctWithdraw = 1e18;

        ILeverager(leverager).withdraw(wp);

        vm.startPrank(lender);
        uint256 yBal = IERC20(yWbtc).balanceOf(lender);

        IERC20(yWbtc).approve(lendingPool, type(uint256).max);
        uint256 received = ILendingPool(lendingPool).redeem(address(wbtc), yBal, lender);
        assertApproxEqAbs(received, 20e8 + owedwbtc - 1000, 10); // 20e8 were the reserves within the pool, 1000 wei are burned upon first deposit

        assertApproxEqAbs(wbtc.balanceOf(depositor), 0, 100);
    }

    function test_partialWithdraw() external {
        skip(6 minutes);

        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 50_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 1.5e8;
        lp.denomination = address(wbtc);
        IMainnetRouter.ExactOutputParams memory ep;

        bytes memory _path = abi.encodePacked(address(usdc), uint24(3000), address(wbtc));
        ep.path = _path;
        ep.deadline = block.timestamp;
        ep.amountInMaximum = type(uint256).max;
        ep.recipient = leverager;
        lp.swapParams2 = abi.encode(ep);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 50_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        ILeverager(leverager).openLeveragedPosition(lp);

        vm.startPrank(rebalancer);
        skip(10 minutes);
        IStrategy(strategy).compound();
        vm.stopPrank();

        deal(address(wbtc), depositor, 0.6e8);

        ILeverager.WithdrawParams memory wp;
        wp.id = 1;
        wp.pctWithdraw = 0.001e18;

        // this should fail
        vm.startPrank(depositor);

        vm.expectRevert();
        ILeverager(leverager).withdraw(wp);

        wp.pctWithdraw = 0.1e18;
        ILeverager(leverager).withdraw(wp);

        wp.pctWithdraw = 1e18;
        ILeverager(leverager).withdraw(wp);

        assertEq(IERC20(vault).balanceOf(leverager), 0);
    }

    function test_borrowToken1() public {
        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 50_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 200_000e6;
        lp.denomination = address(usdc);
        IMainnetRouter.ExactOutputParams memory ep;

        bytes memory _path = abi.encodePacked(address(wbtc), uint24(3000), address(usdc));
        ep.path = _path;
        ep.deadline = block.timestamp;
        ep.amountInMaximum = type(uint256).max;
        ep.recipient = leverager;
        lp.swapParams1 = abi.encode(ep);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 50_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        ILeverager(leverager).openLeveragedPosition(lp);
    }

    function test_cantOpenPositionDueToVolatileVault() public {
        vm.startPrank(lender);
        IMainnetRouter.ExactInputSingleParams memory _params;
        _params.amountIn = 100e8;
        _params.tokenIn = address(wbtc);
        _params.tokenOut = address(usdc);
        _params.fee = 3000;
        _params.deadline = block.timestamp;
        _params.recipient = lender;
        deal(address(wbtc), lender, 100e8);
        wbtc.approve(uniRouter, 100e8);
        IMainnetRouter(uniRouter).exactInputSingle(_params);


        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 50_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 200e18;
        lp.denomination = address(weth);
        IMainnetRouter.ExactOutputParams memory ep;

        bytes memory _path = abi.encodePacked(address(wbtc), uint24(3000), address(weth));
        ep.path = _path;
        ep.deadline = block.timestamp;
        ep.amountInMaximum = type(uint256).max;
        ep.recipient = leverager;

        lp.swapParams1 = abi.encode(ep);
        _path = abi.encodePacked(address(usdc), uint24(3000), address(weth));
        ep.path = _path;

        lp.swapParams2 = abi.encode(ep);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 50_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        
        vm.expectRevert("market too volatile");
        uint256 posId = ILeverager(leverager).openLeveragedPosition(lp);

        skip(1 minutes);
        vm.expectRevert("market too volatile");
        posId = ILeverager(leverager).openLeveragedPosition(lp);
    }

    function test_borrowInThirdToken() public {
        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 50_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 200e18;
        lp.denomination = address(weth);
        IMainnetRouter.ExactOutputParams memory ep;

        bytes memory _path = abi.encodePacked(address(wbtc), uint24(3000), address(weth));
        ep.path = _path;
        ep.deadline = block.timestamp;
        ep.amountInMaximum = type(uint256).max;
        ep.recipient = leverager;

        lp.swapParams1 = abi.encode(ep);
        _path = abi.encodePacked(address(usdc), uint24(3000), address(weth));
        ep.path = _path;

        lp.swapParams2 = abi.encode(ep);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 50_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        uint256 posId = ILeverager(leverager).openLeveragedPosition(lp);

        assertEq(ILeverager(leverager).isLiquidateable(posId), false);
        MockOracle(wethOracle).setPrice(6000e18);
        assertEq(ILeverager(leverager).isLiquidateable(posId), true);

        vm.startPrank(lender);
        IERC20(yWbtc).approve(lendingPool, type(uint256).max);
        IERC20(yUsdc).approve(lendingPool, type(uint256).max);
        IERC20(yWeth).approve(lendingPool, type(uint256).max);

        uint256 bal = IERC20(yWeth).balanceOf(lender);
        vm.expectRevert();
        ILendingPool(lendingPool).redeem(address(weth), bal, lender);

        ILendingPool(lendingPool).redeem(address(usdc), IERC20(yUsdc).balanceOf(lender), lender);
        ILendingPool(lendingPool).redeem(address(wbtc), IERC20(yWbtc).balanceOf(lender), lender);

        vm.startPrank(depositor);
        MockOracle(wethOracle).setPrice(2500e18);

        ILeverager.WithdrawParams memory wp;
        wp.id = posId;
        wp.pctWithdraw = 1e18;
        wp.hasToSwap = true;

        IMainnetRouter.ExactInputParams memory swapParams;
        swapParams.amountIn = 0.55e8;
        swapParams.deadline = block.timestamp;
        swapParams.path = abi.encodePacked(address(wbtc), uint24(3000), address(weth));
        swapParams.recipient = depositor;

        wp.swapParams1 = abi.encode(swapParams);

        swapParams.amountIn = 55_000e6;
        swapParams.path = abi.encodePacked(address(usdc), uint24(3000), address(weth));

        wp.swapParams2 = abi.encode(swapParams);

        weth.approve(leverager, type(uint256).max);
        vm.startPrank(lender);
        vm.expectRevert("msg.sender not approved or owner");
        ILeverager(leverager).withdraw(wp);

        vm.startPrank(depositor);
        ILeverager(leverager).withdraw(wp);

        assertApproxEqAbs(wbtc.balanceOf(depositor), 0.45e8, 1000);
        assertApproxEqAbs(usdc.balanceOf(depositor), 45_000e6, 100000);

        console.log(weth.balanceOf(depositor));
    }


    function test_cantOpenDueToPoolPriceOff() public {
        vm.skip(true);
        // this test depends very closely on the uniswap reserves and can't be abstracted to work on any block
        // reserves slightly higher -> position isn't liquidateable
        // reserves slightly below -> swap reverts due to too high amountIn
        // test succeeds on block 21874457 
        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 50_000e6;
        lp.vault0In = 3e8;
        lp.vault1In = 300_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 1000e18;
        lp.denomination = address(weth);
        IMainnetRouter.ExactOutputParams memory ep;

        bytes memory _path = abi.encodePacked(address(wbtc), uint24(3000), address(weth));
        ep.path = _path;
        ep.deadline = block.timestamp;
        ep.amountInMaximum = type(uint256).max;
        ep.recipient = leverager;

        lp.swapParams1 = abi.encode(ep);
        _path = abi.encodePacked(address(usdc), uint24(3000), address(weth));
        ep.path = _path;

        lp.swapParams2 = abi.encode(ep);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 50_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        vm.startPrank(depositor);
        deal(address(weth), depositor, 8_000e18);
        weth.approve(uniRouter, 8_000e18);
        IMainnetRouter.ExactInputSingleParams memory sp;
        sp.amountIn = 3200e18;
        sp.deadline = block.timestamp;
        sp.tokenIn = address(weth);
        sp.tokenOut = address(wbtc);
        sp.fee = 3000;
        sp.recipient = lender;

        IMainnetRouter(uniRouter).exactInputSingle(sp);

        sp.tokenOut = address(usdc);
        IMainnetRouter(uniRouter).exactInputSingle(sp);

        vm.expectRevert("position can't be liquidateable upon opening");
        ILeverager(leverager).openLeveragedPosition(lp);

    }

    function test_liquidationWithSwap() public {
        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 50_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 200e18;
        lp.denomination = address(weth);
        IMainnetRouter.ExactOutputParams memory ep;

        bytes memory _path = abi.encodePacked(address(wbtc), uint24(3000), address(weth));
        ep.path = _path;
        ep.deadline = block.timestamp;
        ep.amountInMaximum = type(uint256).max;
        ep.recipient = leverager;

        lp.swapParams1 = abi.encode(ep);
        _path = abi.encodePacked(address(usdc), uint24(3000), address(weth));
        ep.path = _path;

        lp.swapParams2 = abi.encode(ep);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 50_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        uint256 gas = gasleft();
        uint256 posId = ILeverager(leverager).openLeveragedPosition(lp);
        uint256 gas2 = gasleft();
        console.log(gas - gas2);

        MockOracle(wethOracle).setPrice(6000e18);

        vm.startPrank(liquidator);

        ILeverager.LiquidateParams memory liqParams;
        liqParams.id = posId;
        liqParams.hasToSwap = true;

        IMainnetRouter.ExactInputParams memory swapParams;
        swapParams.amountIn = 0.55e8;
        swapParams.deadline = block.timestamp;
        swapParams.path = abi.encodePacked(address(wbtc), uint24(3000), address(weth));
        swapParams.recipient = liquidator;

        liqParams.swapParams1 = abi.encode(swapParams);

        swapParams.amountIn = 55_000e6;
        swapParams.path = abi.encodePacked(address(usdc), uint24(3000), address(weth));

        liqParams.swapParams2 = abi.encode(swapParams);

        weth.approve(leverager, type(uint256).max);

        assertEq(ILeverager(leverager).isLiquidateable(posId), true);

        ILeverager(leverager).liquidatePosition(liqParams);

        assertApproxEqAbs(wbtc.balanceOf(liquidator), 0.45e8, 1000);
        assertApproxEqAbs(usdc.balanceOf(liquidator), 45_000e6, 100000);

        console.log(weth.balanceOf(liquidator));
    }

    function test_liquidationNoSwap() public {
        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 50_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 200e18;
        lp.denomination = address(weth);
        IMainnetRouter.ExactOutputParams memory ep;

        bytes memory _path = abi.encodePacked(address(wbtc), uint24(3000), address(weth));
        ep.path = _path;
        ep.deadline = block.timestamp;
        ep.amountInMaximum = type(uint256).max;
        ep.recipient = leverager;

        lp.swapParams1 = abi.encode(ep);
        _path = abi.encodePacked(address(usdc), uint24(3000), address(weth));
        ep.path = _path;

        lp.swapParams2 = abi.encode(ep);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 50_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        uint256 posId = ILeverager(leverager).openLeveragedPosition(lp);

        MockOracle(wethOracle).setPrice(6000e18);

        vm.startPrank(liquidator);

        ILeverager.LiquidateParams memory liqParams;
        liqParams.id = posId;
        deal(address(weth), liquidator, 300e18);
        weth.approve(leverager, type(uint256).max);

        ILeverager(leverager).liquidatePosition(liqParams);

        assertApproxEqAbs(wbtc.balanceOf(liquidator), 1e8, 1000);
        assertApproxEqAbs(usdc.balanceOf(liquidator), 100_000e6, 1e6); // balances should be as much as entire OI
    }

    function test_lendingRate() public {
        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.5e8;
        lp.amount1In = 50_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 200_000e6;
        lp.denomination = address(usdc);
        IMainnetRouter.ExactOutputParams memory ep;

        bytes memory _path = abi.encodePacked(address(wbtc), uint24(3000), address(usdc));
        ep.path = _path;
        ep.deadline = block.timestamp;
        ep.amountInMaximum = type(uint256).max;
        ep.recipient = leverager;
        lp.swapParams1 = abi.encode(ep);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 100_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);
        ILeverager(leverager).openLeveragedPosition(lp);

        console.log(ILendingPool(lendingPool).borrowingRateOfReserve(address(usdc)));

        vm.startPrank(lender);
        IERC20(yUsdc).approve(lendingPool, type(uint256).max);
        ILendingPool(lendingPool).redeem(address(usdc), 140_000e6, lender);

        console.log(ILendingPool(lendingPool).borrowingRateOfReserve(address(usdc)));
        skip(52 weeks);

        console.log(ILendingPool(lendingPool).exchangeRateOfReserve(address(usdc)));
    }

    function test_vaultLimitsWork1() external {
        vm.startPrank(owner);
        ILeverager(leverager).changeVaultMaxBorrow(vault, 50_000e18);

        vm.startPrank(lender);
        wbtc.approve(lendingPool, 10e8);
        deal(address(wbtc), lender, 10e8);

        ILendingPool(lendingPool).deposit(address(wbtc), 10e8, lender);

        uint256 borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        assertEq(borrowingRate, 0);

        skip(6 minutes);

        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.4e8;
        lp.amount1In = 100_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 0.6e8;
        lp.denomination = address(wbtc);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 100_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        vm.expectRevert("too high borrow usd amount");
        ILeverager(leverager).openLeveragedPosition(lp);

        lp.amount0In = 0.5e8; // this makes the borrow now worth just under $50k
        ILeverager(leverager).openLeveragedPosition(lp);
    }

    function test_vaultLimitsWork2() external {
        vm.startPrank(owner);
        ILeverager(leverager).changeVaultMaxLeverage(vault, 1.25e18);

        vm.startPrank(lender);
        wbtc.approve(lendingPool, 10e8);
        deal(address(wbtc), lender, 10e8);

        ILendingPool(lendingPool).deposit(address(wbtc), 10e8, lender);

        uint256 borrowingRate = ILendingPool(lendingPool).borrowingRateOfReserve(address(wbtc));
        assertEq(borrowingRate, 0);

        skip(6 minutes);

        vm.startPrank(depositor);
        ILeverager.LeverageParams memory lp;
        lp.amount0In = 0.4e8;
        lp.amount1In = 100_000e6;
        lp.vault0In = 1e8;
        lp.vault1In = 100_000e6;
        lp.vault = vault;
        lp.maxBorrowAmount = 0.6e8;
        lp.denomination = address(wbtc);

        deal(address(wbtc), depositor, 0.5e8);
        deal(address(usdc), depositor, 100_000e6);
        wbtc.approve(leverager, type(uint256).max);
        usdc.approve(leverager, type(uint256).max);

        vm.expectRevert("too high x leverage"); // leverage here is above 1.25x so it fails
        ILeverager(leverager).openLeveragedPosition(lp);

        lp.amount0In = 0.5e8; // leverage here is just under 1.25x so it should work
        ILeverager(leverager).openLeveragedPosition(lp);
    }

    function test_permissionedFunctions() public {
        vm.startPrank(owner);
        vm.expectRevert("asset already initialized");
        ILendingPool(lendingPool).initReserve(address(usdc));

        vm.expectRevert("borrower not leverager");
        ILendingPool(lendingPool).borrow(address(usdc), 1e6);

        vm.stopPrank();

        address _vault2 = address(new Vault(address(usdc), address(weth)));

        vm.expectRevert();
        ILeverager(leverager).initVault(_vault2, 1_000_000e18, 5e18, 0.1e18, 1e27);

        vm.startPrank(owner);
        ILeverager(leverager).initVault(_vault2, 1_000_000e18, 5e18, 0.1e18, 1e27);

        vm.expectRevert("unauthorized");
        IyToken(yUsdc).transferUnderlyingTo(owner, 100e6);

        vm.startPrank(depositor);
        vm.expectRevert("borrower not leverager");
        ILendingPool(lendingPool).pullFunds(address(usdc), 100e6);
    }



}
