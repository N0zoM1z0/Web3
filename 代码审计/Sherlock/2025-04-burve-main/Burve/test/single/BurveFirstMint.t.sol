// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {StdUtils} from "forge-std/StdUtils.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {AdminLib} from "Commons/Util/Admin.sol";
import {ForkableTest} from "Commons/Test/ForkableTest.sol";

import {Mainnet} from "../utils/BerachainAddresses.sol";
import {Burve} from "../../src/single/Burve.sol";
import {BurveExposedInternal} from "./BurveExposedInternal.sol";
import {FeeLib} from "../../src/single/Fees.sol";
import {FullMath} from "../../src/FullMath.sol";
import {IKodiakIsland} from "../../src/single/integrations/kodiak/IKodiakIsland.sol";
import {Info} from "../../src/single/Info.sol";
import {IStationProxy} from "../../src/single/IStationProxy.sol";
import {IUniswapV3SwapCallback} from "../../src/single/integrations/kodiak/pool/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "../../src/single/integrations/kodiak/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "../../src/single/integrations/uniswap/LiquidityAmounts.sol";
import {NullStationProxy} from "./NullStationProxy.sol";
import {TickMath} from "../../src/single/integrations/uniswap/TickMath.sol";
import {TickRange} from "../../src/single/TickRange.sol";

uint256 constant QUERY_BURN_ALLOWED_APPROX_DELTA = 5;
uint256 constant TVL_BURN_ALLOWED_APPROX_DELTA = 10;

// Same setup as BurveTest
contract BurveFirstMintTest is ForkableTest, IUniswapV3SwapCallback {
    uint256 private constant X96_MASK = (1 << 96) - 1;
    uint256 private constant UNIT_NOMINAL_LIQ_X64 = 1 << 64;

    BurveExposedInternal public burveIsland; // island only
    BurveExposedInternal public burveV3; // v3 only
    BurveExposedInternal public burve; // island + v3
    BurveExposedInternal public burveCompound; // island + v3 (mocked uni pool)

    IUniswapV3Pool pool;
    IERC20 token0;
    IERC20 token1;

    IStationProxy stationProxy;

    address alice;
    address charlie;
    address sender;

    function forkSetup() internal virtual override {
        alice = makeAddr("Alice");
        charlie = makeAddr("Charlie");
        sender = makeAddr("Sender");

        stationProxy = new NullStationProxy();

        // Pool info
        pool = IUniswapV3Pool(Mainnet.KODIAK_WBERA_HONEY_POOL_V3);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
    }

    function postSetup() internal override {
        vm.label(Mainnet.KODIAK_WBERA_HONEY_POOL_V3, "HONEY_NECT_POOL_V3");
        vm.label(Mainnet.KODIAK_WBERA_HONEY_ISLAND, "HONEY_NECT_ISLAND");
    }

    /* Tests */

    function test_FirstMint() public forkOnly {
        int24 tickSpacing = pool.tickSpacing();
        int24 clampedCurrentTick = getClampedCurrentTick();

        // Burve setup
        int24 rangeWidth = 100 * tickSpacing;
        TickRange[] memory ranges = new TickRange[](2);
        ranges[0] = TickRange(0, 0);
        ranges[1] = TickRange(
            clampedCurrentTick - rangeWidth,
            clampedCurrentTick + rangeWidth
        );

        uint128[] memory weights = new uint128[](2);
        weights[0] = 3;
        weights[1] = 1;

        burve = new BurveExposedInternal(
            Mainnet.KODIAK_WBERA_HONEY_POOL_V3,
            Mainnet.KODIAK_WBERA_HONEY_ISLAND,
            address(stationProxy),
            ranges,
            weights
        );

        // First, transfers to mint will fail.
        vm.expectRevert();
        burve.mint(address(this), 100, 0, type(uint128).max);

        // Second, mint amount can be too low
        deal(address(token0), address(this), type(uint256).max);
        deal(address(token1), address(this), type(uint256).max);
        token0.approve(address(burve), type(uint256).max);
        token1.approve(address(burve), type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(Burve.InsecureFirstMintAmount.selector, 99)
        );
        burve.mint(address(this), 99, 0, type(uint128).max);

        // Third recipient must be the pool itself.
        vm.expectRevert(
            abi.encodeWithSelector(
                Burve.InsecureFirstMintRecipient.selector,
                address(this)
            )
        );
        burve.mint(address(this), 100, 0, type(uint128).max);

        // Finally, we can mint and do follow up mints however we want.
        burve.mint(address(burve), 100, 0, type(uint128).max);
        burve.mint(address(this), 99, 0, type(uint128).max);
    }

    // Helpers

    /// @notice Gets the current tick clamped to respect the tick spacing
    function getClampedCurrentTick() internal view returns (int24) {
        (, int24 currentTick, , , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();
        return currentTick - (currentTick % tickSpacing);
    }

    /// @notice Calculate token amounts in liquidity for the given range.
    /// @param liquidity The amount of liquidity.
    /// @param lower The lower tick of the range.
    /// @param upper The upper tick of the range.
    function getAmountsForLiquidity(
        uint128 liquidity,
        int24 lower,
        int24 upper,
        bool roundUp
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();

        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(lower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(upper);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity,
            roundUp
        );
    }

    /// @notice Calculates the liquidity represented by island shares
    /// @param island The island
    /// @param shares The shares
    /// @return liquidity The liquidity
    function islandSharesToLiquidity(
        IKodiakIsland island,
        uint256 shares
    ) internal view returns (uint128 liquidity) {
        bytes32 positionId = island.getPositionID();
        (uint128 poolLiquidity, , , , ) = pool.positions(positionId);
        uint256 totalSupply = island.totalSupply();
        liquidity = uint128(
            FullMath.mulDiv(shares, poolLiquidity, totalSupply)
        );
    }

    function shift96(
        uint256 a,
        bool roundUp
    ) internal pure returns (uint256 b) {
        b = a >> 96;
        if (roundUp && (a & X96_MASK) > 0) b += 1;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta > 0)
            token0.transfer(address(pool), uint256(amount0Delta));
        if (amount1Delta > 0)
            token1.transfer(address(pool), uint256(amount1Delta));
    }
}
