// SPDX-License-Identifier: MIT
// Copyright 2024 Itos Inc.
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";

import {
    Int24ComparisonLib,
    Int256ComparisonLib,
    Uint24ComparisonLib,
    Uint256ComparisonLib
} from "../../src/Math/Comparison.sol";

contract ComparisonLibTest is Test {
    // int24

    function testMinInt24() public pure {
        int24 a = 1;
        int24 b = 2;

        assertEq(a, Int24ComparisonLib.min(a, b));
        assertEq(a, Int24ComparisonLib.min(b, a));
    }

    function testMaxInt24() public pure {
        int24 a = 1;
        int24 b = 2;

        assertEq(b, Int24ComparisonLib.max(a, b));
        assertEq(b, Int24ComparisonLib.max(b, a));
    }

    // int256

    function testMinInt256() public pure {
        int256 a = 1;
        int256 b = 2;

        assertEq(a, Int256ComparisonLib.min(a, b));
        assertEq(a, Int256ComparisonLib.min(b, a));
    }

    function testMaxInt256() public pure {
        int256 a = 1;
        int256 b = 2;

        assertEq(b, Int256ComparisonLib.max(a, b));
        assertEq(b, Int256ComparisonLib.max(b, a));
    }

    // uint24

    function testMinUint24() public pure {
        uint24 a = 1;
        uint24 b = 2;

        assertEq(a, Uint24ComparisonLib.min(a, b));
        assertEq(a, Uint24ComparisonLib.min(b, a));
    }

    function testMaxUint24() public pure {
        uint24 a = 1;
        uint24 b = 2;

        assertEq(b, Uint24ComparisonLib.max(a, b));
        assertEq(b, Uint24ComparisonLib.max(b, a));
    }

    // uint256

    function testMinUint256() public pure {
        uint256 a = 1;
        uint256 b = 2;

        assertEq(a, Uint256ComparisonLib.min(a, b));
        assertEq(a, Uint256ComparisonLib.min(b, a));
    }

    function testMaxUint256() public pure {
        uint256 a = 1;
        uint256 b = 2;

        assertEq(b, Uint256ComparisonLib.max(a, b));
        assertEq(b, Uint256ComparisonLib.max(b, a));
    }
}
