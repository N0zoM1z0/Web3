// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {AdminLib} from "Commons/Util/Admin.sol";

import {FullMath} from "../../../src/FullMath.sol";

import {FixedAdjustor} from "../../../src/integrations/adjustor/FixedAdjustor.sol";

contract FixedAdjustorTest is Test {
    FixedAdjustor public adj;
    address public owner;
    address public tokenA;
    address public tokenB;
    address public tokenZ;
    uint256 public adjA;
    uint256 public adjB;

    function setUp() public {
        owner = makeAddr("owner");
        tokenA = makeAddr("tokenA");
        tokenB = makeAddr("tokenB");
        tokenZ = makeAddr("tokenZero");

        adjA = 2 << 128;
        adjB = uint256(1 << 128) / 3;

        vm.startPrank(owner);
        adj = new FixedAdjustor();
        adj.setAdjustment(tokenA, adjA);
        adj.setAdjustment(tokenB, adjB);
        vm.stopPrank();
    }

    // -- setAdjustment tests ----

    function testSetAdjustment() public {
        vm.startPrank(owner);

        // setAdjustment called in setUp

        assertEq(adj.adjsX128(tokenA), adjA);
        assertEq(adj.adjsX128(tokenB), adjB);

        assertEq(adj.invAdjsX128(tokenA), FullMath.mulDivX256(1, adjA, false));
        assertEq(adj.invAdjsX128(tokenB), FullMath.mulDivX256(1, adjB, false));

        vm.stopPrank();
    }

    function testRevertSetAdjustmentToZero() public {
        vm.startPrank(owner);
        vm.expectRevert();
        adj.setAdjustment(tokenA, 0);
        vm.stopPrank();
    }

    function testRevertSetAdjustmentToOne() public {
        vm.startPrank(owner);
        vm.expectRevert();
        adj.setAdjustment(tokenA, 1);
        vm.stopPrank();
    }

    function testRevertSetAdjustmentNotOwner() public {
        vm.expectRevert(AdminLib.NotOwner.selector);
        adj.setAdjustment(tokenA, 2 << 128);
    }

    // -- toNominal uint tests ----

    function testToNominalUint() public {
        uint256 real = 100e18;

        // check A
        uint256 nominalRoundingUpA = adj.toNominal(tokenA, real, true);
        assertEq(FullMath.mulX128(adjA, real, true), nominalRoundingUpA);

        uint256 nominalRoundingDownA = adj.toNominal(tokenA, real, false);
        assertEq(FullMath.mulX128(adjA, real, false), nominalRoundingDownA);

        // check B
        uint256 nominalRoundingUpB = adj.toNominal(tokenB, real, true);
        assertEq(FullMath.mulX128(adjB, real, true), nominalRoundingUpB);

        uint256 nominalRoundingDownB = adj.toNominal(tokenB, real, false);
        assertEq(FullMath.mulX128(adjB, real, false), nominalRoundingDownB);
    }

    function testToNominalUintAdjZero() public {
        uint256 real = 100;

        uint256 nominalRoundingUp = adj.toNominal(tokenZ, real, true);
        uint256 nominalRoundingDown = adj.toNominal(tokenZ, real, false);
        assertEq(real, nominalRoundingUp);
        assertEq(nominalRoundingUp, nominalRoundingDown);
    }

    // -- toNominal int tests ----

    function testToNominalIntPositive() public {
        int256 real = 100e18;

        // check A
        int256 nominalRoundingUpA = adj.toNominal(tokenA, real, true);
        assertEq(
            int256(FullMath.mulX128(adjA, uint256(real), true)),
            nominalRoundingUpA
        );

        int256 nominalRoundingDownA = adj.toNominal(tokenA, real, false);
        assertEq(
            int256(FullMath.mulX128(adjA, uint256(real), false)),
            nominalRoundingDownA
        );

        // check B
        int256 nominalRoundingUpB = adj.toNominal(tokenB, real, true);
        assertEq(
            int256(FullMath.mulX128(adjB, uint256(real), true)),
            nominalRoundingUpB
        );

        int256 nominalRoundingDownB = adj.toNominal(tokenB, real, false);
        assertEq(
            int256(FullMath.mulX128(adjB, uint256(real), false)),
            nominalRoundingDownB
        );
    }

    function testToNominalIntNegative() public {
        int256 real = -100e18;

        // check A
        int256 nominalRoundingUpA = adj.toNominal(tokenA, real, true);
        assertEq(
            -int256(FullMath.mulX128(adjA, uint256(-real), true)),
            nominalRoundingUpA
        );

        int256 nominalRoundingDownA = adj.toNominal(tokenA, real, false);
        assertEq(
            -int256(FullMath.mulX128(adjA, uint256(-real), false)),
            nominalRoundingDownA
        );

        // check B
        int256 nominalRoundingUpB = adj.toNominal(tokenB, real, true);
        assertEq(
            -int256(FullMath.mulX128(adjB, uint256(-real), true)),
            nominalRoundingUpB
        );

        int256 nominalRoundingDownB = adj.toNominal(tokenB, real, false);
        assertEq(
            -int256(FullMath.mulX128(adjB, uint256(-real), false)),
            nominalRoundingDownB
        );
    }

    function testToNominalIntAdjZero() public {
        int256 real = 100;

        int256 nominalRoundingUp = adj.toNominal(tokenZ, real, true);
        int256 nominalRoundingDown = adj.toNominal(tokenZ, real, false);
        assertEq(real, nominalRoundingUp);
        assertEq(nominalRoundingUp, nominalRoundingDown);
    }

    // -- toReal uint tests ----

    function testToRealUint() public {
        uint256 nominal = 100e18;

        // check A
        uint256 realRoundingUpA = adj.toNominal(tokenA, nominal, true);
        assertEq(FullMath.mulX128(adjA, nominal, true), realRoundingUpA);

        uint256 realRoundingDownA = adj.toNominal(tokenA, nominal, false);
        assertEq(FullMath.mulX128(adjA, nominal, false), realRoundingDownA);

        // check B
        uint256 realRoundingUpB = adj.toNominal(tokenB, nominal, true);
        assertEq(FullMath.mulX128(adjB, nominal, true), realRoundingUpB);

        uint256 realRoundingDownB = adj.toNominal(tokenB, nominal, false);
        assertEq(FullMath.mulX128(adjB, nominal, false), realRoundingDownB);
    }

    function testToRealUintAdjZero() public {
        uint256 nominal = 100;

        uint256 realRoundingUp = adj.toNominal(tokenZ, nominal, true);
        uint256 realRoundingDown = adj.toNominal(tokenZ, nominal, false);
        assertEq(nominal, realRoundingUp);
        assertEq(realRoundingUp, realRoundingDown);
    }

    // -- toReal int tests ----

    function testToRealIntPositive() public {
        int256 nominal = 100e18;

        // check A
        int256 realRoundingUpA = adj.toNominal(tokenA, nominal, true);
        assertEq(
            int256(FullMath.mulX128(adjA, uint256(nominal), true)),
            realRoundingUpA
        );

        int256 realRoundingDownA = adj.toNominal(tokenA, nominal, false);
        assertEq(
            int256(FullMath.mulX128(adjA, uint256(nominal), false)),
            realRoundingDownA
        );

        // check B
        int256 realRoundingUpB = adj.toNominal(tokenB, nominal, true);
        assertEq(
            int256(FullMath.mulX128(adjB, uint256(nominal), true)),
            realRoundingUpB
        );

        int256 realRoundingDownB = adj.toNominal(tokenB, nominal, false);
        assertEq(
            int256(FullMath.mulX128(adjB, uint256(nominal), false)),
            realRoundingDownB
        );
    }

    function testToRealIntNegative() public {
        int256 nominal = -100e18;

        // check A
        int256 realRoundingUpA = adj.toNominal(tokenA, nominal, true);
        assertEq(
            -int256(FullMath.mulX128(adjA, uint256(-nominal), true)),
            realRoundingUpA
        );

        int256 realRoundingDownA = adj.toNominal(tokenA, nominal, false);
        assertEq(
            -int256(FullMath.mulX128(adjA, uint256(-nominal), false)),
            realRoundingDownA
        );

        // check B
        int256 realRoundingUpB = adj.toNominal(tokenB, nominal, true);
        assertEq(
            -int256(FullMath.mulX128(adjB, uint256(-nominal), true)),
            realRoundingUpB
        );

        int256 realRoundingDownB = adj.toNominal(tokenB, nominal, false);
        assertEq(
            -int256(FullMath.mulX128(adjB, uint256(-nominal), false)),
            realRoundingDownB
        );
    }

    function testToRealIntAdjZero() public {
        int256 nominal = 100;

        int256 realRoundingUp = adj.toNominal(tokenZ, nominal, true);
        int256 realRoundingDown = adj.toNominal(tokenZ, nominal, false);
        assertEq(nominal, realRoundingUp);
        assertEq(realRoundingUp, realRoundingDown);
    }
}
