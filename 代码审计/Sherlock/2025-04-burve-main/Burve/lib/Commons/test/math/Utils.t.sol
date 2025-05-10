// SPDX-License-Identifier: MIT
// Copyright 2024 Itos Inc.
pragma solidity ^0.8.13;

import { console, Test } from "forge-std/Test.sol";
import { MathUtils } from "../../src/Math/Utils.sol";
import { FullMath } from "../../src/Math/FullMath.sol";

contract MathUtilsTest is Test {

    function testPercentX256() public pure {
        uint256 res = MathUtils.percentX256(50, 100);
        assertApproxEqAbs(res, 1 << 255, 100);
    }

    /// Test that the percentX256 function is bounded above by the exact result.
    function testPercentX256Bounded(uint256 a, uint256 b) public pure {
        vm.assume(a < type(uint256).max);
        vm.assume(b < type(uint256).max);
        vm.assume(a != b);
        // numerator can't be 0.
        a += 1;
        b += 1;
        if (a > b) {
            (a, b) = (b, a);
        }
        vm.assume(a < (uint256(1) << 254));
        console.log(a, b);
        uint256 exact = FullMath.mulDiv(uint256(1) << 254, a << 2, b);
        // uint256 approx = MathUtils.percentX256(a, b);
        // assertGe(exact, approx);
    }

    /// Try to test that without a certain percentage difference, this function is somewhat accureate.
    /// forge-config: default.fuzz.runs = 6000
    /// forge-config: ci.fuzz.runs = 500
    function testPercentX256Approx(uint192 smallDenom, uint128 percent, uint192 fuzz) public pure {
        uint256 denom = smallDenom; // Cast up.
        vm.assume(percent > 0);
        uint256 hundredPercent = 1 << 128;
        // Make sure we have some fuzz
        vm.assume(fuzz > 0);
        if (fuzz >= (1 << 192)) {
            fuzz >>= 1; // A <10 percent fuzz
        }
        // We can't be so small we can't take a percentage off of.
        if (denom < hundredPercent) {
            denom += hundredPercent; // Just for a sufficiently large base to take a percentage of and to outweight the fuzz.
        }
        uint256 num = FullMath.mulDiv(denom, percent, hundredPercent);
        num += fuzz;
        if (num > denom) {
            (denom, num) = (num, denom);
        }
        if (num == denom) {
            denom += 13371337;
        }
        console.log(num, denom, fuzz);
        uint256 exact = FullMath.mulDiv(num << 16, 1 << 240, denom);
        uint256 approx = MathUtils.percentX256(num, denom);
        // Unfortunately, the foundry standard delta calculation can overflow.
        console.log(exact, approx);
        uint256 relDelta = FullMath.mulDiv(1e18, exact - approx, exact);
        assertLt(relDelta, 1); // less than 1 basis point
    }

    /// Test that the percentX256 function is bounded above by the exact result.
    /// USE THIS TO TEST FOR ERROR BOUNDS, but know that they are large.
    // function testPercentX256Exact(uint256 a, uint256 b) public pure {
    //     vm.assume(a < type(uint256).max);
    //     vm.assume(b < type(uint256).max);
    //     vm.assume(a != b);
    //     // numerator can't be 0.
    //     a += 1;
    //     b += 1;
    //     if (a > b) {
    //         (a, b) = (b, a);
    //     }
    //     vm.assume(a < (uint256(1) << 255));
    //     uint256 exact = FullMath.mulDiv(1 << 255, uint256(a) << 1, b);
    //     uint256 approx = MathUtils.percentX256(a, b);
    //     assertGe(exact, approx);
    //     uint256 absDelta = exact - approx;
    //     uint256 relDelta = FullMath.mulDiv(1e18, exact - approx, exact);
    //     // If the result is greater than 1 percent we want it to be exact.
    //     if (exact > (type(uint256).max / 10)) {
    //         assertLt(relDelta, 1e14); // One hundreth of a basis point.
    //         // assertApproxEqAbs(exact, approx, );
    //     }
    // }
}
