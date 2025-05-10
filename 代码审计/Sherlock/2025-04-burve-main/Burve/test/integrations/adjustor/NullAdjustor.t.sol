// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {NullAdjustor} from "../../../src/integrations/adjustor/NullAdjustor.sol";

contract NullAdjustorTest is Test {
    NullAdjustor public adj;

    function setUp() public {
        adj = new NullAdjustor();
    }

    // toNominal uint tests

    function tesToNominalUintDiffTokens() public view {
        uint256 real = 100e18;
        uint256 nominalZero = adj.toNominal(address(0x0), real, true);
        uint256 nominalOne = adj.toNominal(address(0x1), real, true);
        assertEq(real, nominalZero);
        assertEq(nominalZero, nominalOne);
    }

    function testToNominalUintRounding() public view {
        uint256 real = 100e18;
        uint256 nominalRoundedUp = adj.toNominal(address(0x0), real, true);
        uint256 nominalRoundedDown = adj.toNominal(address(0x0), real, false);
        assertEq(real, nominalRoundedUp);
        assertEq(nominalRoundedUp, nominalRoundedDown);
    }

    function testToNominalUintReal() public view {
        uint256 real = 100e18;
        assertEq(real, adj.toNominal(address(0x0), real, true));
    }

    function testToNominalUintRealMin() public view {
        uint256 real = type(uint256).min;
        assertEq(real, adj.toNominal(address(0x0), real, true));
    }

    function testToNominalUintRealMax() public view {
        uint256 real = type(uint256).max;
        assertEq(real, adj.toNominal(address(0x0), real, true));
    }

    // toNominal int tests

    function tesToNominalIntDiffTokens() public view {
        int256 real = 100e18;
        int256 nominalZero = adj.toNominal(address(0x0), real, true);
        int256 nominalOne = adj.toNominal(address(0x1), real, true);
        assertEq(real, nominalZero);
        assertEq(nominalZero, nominalOne);
    }

    function testToNominalIntRounding() public view {
        int256 real = 100e18;
        int256 nominalRoundedUp = adj.toNominal(address(0x0), real, true);
        int256 nominalRoundedDown = adj.toNominal(address(0x0), real, false);
        assertEq(real, nominalRoundedUp);
        assertEq(nominalRoundedUp, nominalRoundedDown);
    }

    function testToNominalIntRealPositive() public view {
        int256 real = 100e18;
        assertEq(real, adj.toNominal(address(0x0), real, true));
    }

    function testToNominalIntRealNegative() public view {
        int256 real = -100e18;
        assertEq(real, adj.toNominal(address(0x0), real, true));
    }

    function testToNominalIntRealMin() public view {
        int256 real = type(int256).min;
        assertEq(real, adj.toNominal(address(0x0), real, true));
    }

    function testToNominalIntRealMax() public view {
        int256 real = type(int256).max;
        assertEq(real, adj.toNominal(address(0x0), real, true));
    }

    // toReal uint tests

    function tesToRealUintDiffTokens() public view {
        uint256 nominal = 100e18;
        uint256 realZero = adj.toReal(address(0x0), nominal, true);
        uint256 realOne = adj.toReal(address(0x1), nominal, true);
        assertEq(nominal, realZero);
        assertEq(realZero, realOne);
    }

    function testToRealUintRounding() public view {
        uint256 nominal = 100e18;
        uint256 realRoundedUp = adj.toReal(address(0x0), nominal, true);
        uint256 realRoundedDown = adj.toReal(address(0x0), nominal, false);
        assertEq(nominal, realRoundedUp);
        assertEq(realRoundedUp, realRoundedDown);
    }

    function testToRealUintReal() public view {
        uint256 nominal = 100e18;
        assertEq(nominal, adj.toReal(address(0x0), nominal, true));
    }

    function testToRealUintRealMin() public view {
        uint256 nominal = type(uint256).min;
        assertEq(nominal, adj.toReal(address(0x0), nominal, true));
    }

    function testToRealUintRealMax() public view {
        uint256 nominal = type(uint256).max;
        assertEq(nominal, adj.toReal(address(0x0), nominal, true));
    }

    // toReal int tests

    function tesToRealIntDiffTokens() public view {
        int256 nominal = 100e18;
        int256 realZero = adj.toReal(address(0x0), nominal, true);
        int256 realOne = adj.toReal(address(0x1), nominal, true);
        assertEq(nominal, realZero);
        assertEq(realZero, realOne);
    }

    function testToRealIntRounding() public view {
        int256 nominal = 100e18;
        int256 realRoundedUp = adj.toReal(address(0x0), nominal, true);
        int256 realRoundedDown = adj.toReal(address(0x0), nominal, false);
        assertEq(nominal, realRoundedUp);
        assertEq(realRoundedUp, realRoundedDown);
    }

    function testToRealIntRealPositive() public view {
        int256 nominal = 100e18;
        assertEq(nominal, adj.toReal(address(0x0), nominal, true));
    }

    function testToRealIntRealNegative() public view {
        int256 nominal = -100e18;
        assertEq(nominal, adj.toReal(address(0x0), nominal, true));
    }

    function testToRealIntRealMin() public view {
        int256 nominal = type(int256).min;
        assertEq(nominal, adj.toReal(address(0x0), nominal, true));
    }

    function testToRealIntRealMax() public view {
        int256 nominal = type(int256).max;
        assertEq(nominal, adj.toReal(address(0x0), nominal, true));
    }
}
