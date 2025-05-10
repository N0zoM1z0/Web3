// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";

import {FullMath} from "../src/Math/FullMath.sol";

contract FullMathGasTest is PRBTest, StdCheats {
    function testMulDivGas() public pure {
        FullMath.mulDiv(1337 << 140, 128 << 129, 340 << 200);
    }

    function testMulDivShortCircuitGas() public pure {
        uint256 m0 = 1337 << 140;
        uint256 m1 = 128 << 129;
        uint256 denominator = 340 << 200;

        uint256 num;
        unchecked {
            num = m0 * m1;
        }
        if (m0 == 0) return;

        if (num / m0 == m1) {
            num / denominator;
        }
    }

    function testShortMulDivGas() public pure {
        FullMath.shortMulDiv(1337 << 140, 128 << 129, 340 << 200);
        FullMath.shortMulDiv(1337 << 74, 128 << 129, 340 << 200);
    }

    function testMul512Gas(uint256 a, uint256 b) public pure {
        FullMath.mul512(a, b);
    }

    function testShortDivMulDivGas() public pure {
        FullMath.shortMulDiv(1337 << 140, 128 << 120, 340 << 200);
        FullMath.shortMulDiv(1337 << 74, 128 << 120, 340 << 200);
        FullMath.shortMulDiv(1337 << 74, 128 << 120, 340 << 112);
        FullMath.shortMulDiv(1337 << 74, 128 << 64, 340 << 128);
    }

    /// Another way to short circuit mulDiv for specific circumstances
    function shortDivMulDiv(uint256 a, uint128 b, uint160 denom) public pure {
        uint256 res;
        if (denom < (1 << 128)) {
            uint256 numX128 = (b << 128) / denom;
            (uint256 bot, uint256 top) = FullMath.mul512(a, numX128);
            res = ((top << 128) | (bot >> 128));
        } else if (denom < (1 << 160) && b < (1 << 96)) {
            uint256 numX160 = (b << 160) / denom;
            (uint256 bot, uint256 top) = FullMath.mul512(a, numX160);
            res = ((top << 96) | (bot >> 160));
        } else {
            res = FullMath.shortMulDiv(a, b, denom);
        }
    }
}
