// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Store} from "../../src/multi/Store.sol";
import {UniV3Edge} from "../../src/multi/UniV3Edge.sol";
import {Edge} from "../../src/multi/Edge.sol";
import {TickMath} from "../../src/multi/uniV3Lib/TickMath.sol";
import {FullMath} from "../../src/FullMath.sol";

contract UniV3EdgeTest is Test {
    uint160 constant SELL_SQRT_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 constant BUY_SQRT_LIMIT = TickMath.MAX_SQRT_RATIO - 1;

    Edge public edge;

    function setUp() public {
        edge.setRange(uint128(100), int24(-100), int24(100));
        edge.setFee(0, 0);
    }

    /* Helpers */

    /// Helper for getting what the implied balances should be from a swap.
    /// @dev Rounds down.
    function getBalances(
        uint256 sqrtPriceX96,
        uint256 wideLiq
    ) internal view returns (uint256 x, uint256 y) {
        x = ((wideLiq << 128) / sqrtPriceX96) << 64;
        y = (wideLiq * sqrtPriceX96);
        if (sqrtPriceX96 < edge.lowSqrtPriceX96) {
            x +=
                edge.amplitude *
                wideLiq *
                (edge.invLowSqrtPriceX96 - edge.invHighSqrtPriceX96);
        } else if (sqrtPriceX96 >= edge.highSqrtPriceX96) {
            y +=
                edge.amplitude *
                wideLiq *
                (edge.highSqrtPriceX96 - edge.lowSqrtPriceX96);
        } else {
            x +=
                edge.amplitude *
                wideLiq *
                ((1 << 192) / sqrtPriceX96 - edge.invHighSqrtPriceX96);
            y +=
                edge.amplitude *
                wideLiq *
                (sqrtPriceX96 - edge.lowSqrtPriceX96);
        }
        x >>= 96;
        y >>= 96;
    }

    function checkedSwap(
        uint160 sqrtPriceX96,
        uint128 wideLiq,
        bool zeroForOne,
        int256 amount
    ) internal view returns (uint160 newSqrtPriceX96) {
        int24 startTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        uint128 startLiq = edge.updateLiquidity(
            startTick,
            edge.highTick,
            wideLiq
        );
        (uint256 startX, uint256 startY) = getBalances(sqrtPriceX96, wideLiq);
        UniV3Edge.Slot0 memory slot0 = UniV3Edge.Slot0(
            0, // fee
            0, // feeProtocol
            sqrtPriceX96, // sqrtPriceX96
            startTick, // tick
            startLiq // current liq
        );
        (
            int256 x,
            int256 y,
            ,
            uint160 finalSqrtPriceX96,
            int24 finalTick
        ) = UniV3Edge.swap(
                edge,
                slot0,
                zeroForOne,
                amount,
                zeroForOne ? SELL_SQRT_LIMIT : BUY_SQRT_LIMIT
            );
        if (zeroForOne) {
            assertGt(x, 0);
            assertLt(y, 0);
        } else {
            assertGt(y, 0);
            assertLt(x, 0);
        }
        uint128 finalLiq = edge.updateLiquidity(finalTick, startTick, startLiq);
        (uint256 finalX, uint256 finalY) = getBalances(
            finalSqrtPriceX96,
            wideLiq
        );
        if (x > 0) {
            assertApproxEqAbs(finalX - startX, uint256(x), 2);
        } else {
            assertApproxEqAbs(startX - finalX, uint256(-x), 2);
        }

        if (y > 0) {
            assertApproxEqAbs(finalY - startY, uint256(y), 2);
        } else {
            assertApproxEqAbs(startY - finalY, uint256(-y), 2);
        }
        newSqrtPriceX96 = finalSqrtPriceX96;
    }

    /* Test */

    function testSimpleSwap() public view {
        UniV3Edge.Slot0 memory slot0 = UniV3Edge.Slot0(
            0, // fee
            0, // feeProtocol
            1 << 96, // sqrtPriceX96
            0, // tick
            1000e18 // current liq
        );

        UniV3Edge.swap(edge, slot0, true, 100e18, SELL_SQRT_LIMIT);
    }

    function testSwapConcentrationAmount() public {
        uint160 startSqrtPriceX96 = 1 << 96;
        int24 startTick = 0;
        UniV3Edge.Slot0 memory slot0 = UniV3Edge.Slot0(
            0, // fee
            0, // feeProtocol
            startSqrtPriceX96, // sqrtPriceX96
            startTick, // tick
            1000e18 // current liq
        );

        (int256 x, int256 y, uint128 proto, , int24 finalTick) = UniV3Edge.swap(
            edge,
            slot0,
            true,
            100e18,
            SELL_SQRT_LIMIT
        );
        // Generally correct values.
        assertEq(proto, 0);
        assertLt(y, 0);
        assertGt(x, 0);

        // Try again but what if the liquidity was more concentrated.
        edge.lowTick = int24(-10);
        edge.highTick = int24(10);
        (int256 x10, int256 y10, , , int24 finalTick2) = UniV3Edge.swap(
            edge,
            slot0,
            true,
            100e18,
            SELL_SQRT_LIMIT
        );
        assertEq(x, x10);
        assertGt(y10, y); // We get less because the liquidity is less.
        assertLt(finalTick2, finalTick); // We move the tick more.
    }

    function testSwapAmounts() public {
        uint160 newSqrtPriceX96 = checkedSwap(
            1 << 96, // price
            1000e18, // wideLiq,
            true, // zero for one
            123e17 // amount
        );
        // Go past the high tick.
        newSqrtPriceX96 = checkedSwap(newSqrtPriceX96, 100e18, false, 70e18);
        // And go straight past the low tick
        newSqrtPriceX96 = checkedSwap(newSqrtPriceX96, 100e18, true, -150e18);
    }
}
