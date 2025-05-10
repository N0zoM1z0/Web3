// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {DecimalAdjustor} from "../../src/integrations/adjustor/DecimalAdjustor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {FullMath} from "../../src/FullMath.sol";

contract DecimalAdjustorTest is Test {
    DecimalAdjustor public adj;
    address token18;
    address token6;
    address token24;
    address token42;
    address token0;
    address token7;

    function setUp() public {
        adj = new DecimalAdjustor();
        token18 = address(new MockERC20("18", "18", 18));
        token6 = address(new MockERC20("6", "6", 6));
        token24 = address(new MockERC20("24", "24", 24));
        token42 = address(new MockERC20("42", "42", 42));
        token0 = address(new MockERC20("0", "0", 0));
        token7 = address(new MockERC20("7", "7", 7));
    }

    function testAdjustment() public {
        adj.cacheAdjustment(token18);
        assertEq(adj.adjustments(token18), 1);

        adj.cacheAdjustment(token6);
        assertEq(adj.adjustments(token6), 1e12);

        adj.cacheAdjustment(token24);
        assertEq(adj.adjustments(token24), -1e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                DecimalAdjustor.TooManyDecimals.selector,
                uint8(42)
            )
        );
        adj.cacheAdjustment(token42);

        adj.cacheAdjustment(token0);
        assertEq(adj.adjustments(token0), 1e18);

        adj.cacheAdjustment(token7);
        assertEq(adj.adjustments(token7), 1e11);
    }

    function testPositiveNominal() public {
        assertEq(adj.toNominal(token6, int256(1e12), false), 1e24);
        assertEq(adj.toNominal(token6, int256(1e12), true), 1e24);
    }

    function testNegativeNominal() public {
        assertEq(adj.toNominal(token24, int256(1e12), false), 1e6);
        assertEq(adj.toNominal(token24, int256(1e12), true), 1e6);
        assertEq(
            adj.toNominal(token24, int24(type(uint24).max), true),
            adj.toNominal(token24, int24(type(uint24).max), false) + 1
        );
    }

    function testPositiveSqrtRatio() public {
        // Basic test without using sqrt of 10.
        assertEq(adj.nominalSqrtRatioX128(token18, token6, false), 1e6 << 128);
        assertEq(adj.nominalSqrtRatioX128(token18, token6, true), 1e6 << 128);

        // A test that must use sqrt of 10.
        uint256 testRatioX128 = adj.nominalSqrtRatioX128(
            token18,
            token7,
            false
        );
        uint256 fullRatio = FullMath.mulX256(
            testRatioX128,
            testRatioX128,
            true
        );
        assertEq(fullRatio, 1e11);
        // If we're looking to underestimate, it works.
        fullRatio = FullMath.mulX256(testRatioX128, testRatioX128, false);
        assertEq(fullRatio, 1e11 - 1); // Meaning we're off by the smallest amount possible.

        // Now we try rounding up.
        testRatioX128 = adj.nominalSqrtRatioX128(token18, token7, true);
        fullRatio = FullMath.mulX256(testRatioX128, testRatioX128, false);
        assertEq(fullRatio, 1e11); // We round up after rounding down to get the right result!
        // If we're looking to overestimate, it works as intended.
        fullRatio = FullMath.mulX256(testRatioX128, testRatioX128, true);
        assertEq(fullRatio, 1e11 + 1);
        // Hence, we're off by the smallest amount possible.
    }

    function testNegativeSqrtRatio() public {
        uint256 testRatio = adj.nominalSqrtRatioX128(token6, token18, false);
        // We slightly underestimate on ratios that decrease the value.
        // We'll see if this causes any trouble.
        // Typically rounding up fixes the issue.
        assertEq(FullMath.mulX128(1e12, testRatio, true), 1e6);
        assertEq(FullMath.mulX128(1e12, testRatio, false), 1e6 - 1);
        // And if we round up the opposite is true in the other direction.
        testRatio = adj.nominalSqrtRatioX128(token6, token18, true);
        assertEq(FullMath.mulX128(1e12, testRatio, false), 1e6);
        assertEq(FullMath.mulX128(1e12, testRatio, true), 1e6 + 1);
        // So overall this seems like the desired behavior, false false gives one less. false true is okay.
        // True false is okay. True true is one above.

        // Test with one that uses the sqrt of ten. This has the widest margin of error, but is still relatively small.
        testRatio = adj.nominalSqrtRatioX128(token7, token18, false);
        // sqrt(1/1e11) right now with 128 fractional bits. It uses at most 146 bits and 1e11 is under 40 bits.
        assertApproxEqAbs(
            FullMath.mulX128(testRatio * 1e11, testRatio, true),
            1 << 128,
            1 << 20
        );
    }
}
