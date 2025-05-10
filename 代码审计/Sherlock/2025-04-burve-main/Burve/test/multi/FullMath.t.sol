// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {FullMath} from "../../src/FullMath.sol";

contract FullMathTest is Test {
    function setUp() public {}

    function testMulDivX256() public {
        {
            uint256 half = FullMath.mulDivX256(1000, 2000, false);
            uint256 half2 = FullMath.mulDivX256(
                123412341234,
                246824682468,
                false
            );
            assertEq(half, half2);
            assertEq(half, 1 << 255);
        }

        {
            // With remainders rounding down.
            uint256 third = FullMath.mulDivX256(1112, 3333, false);
            uint256 third2 = FullMath.mulDivX256(1111111112, 3333333333, false);
            uint256 third3 = FullMath.mulDivX256(1111, 3333, false);
            assertGt(third, third2);
            assertGt(third2, third3);
        }
    }

    // TODO: We can definitely test muldivX256 a lot more, especially with rounding up.
}
