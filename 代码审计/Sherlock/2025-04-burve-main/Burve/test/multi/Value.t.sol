// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, stdError} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ValueLib, SearchParams} from "../../src/multi/Value.sol";
import {FullMath} from "../../src/FullMath.sol";

contract ValueTest is Test {
    /// When x is at target, it'll be equal to value no matter e or rounding.
    function testVwhenXatT() public pure {
        assertEq(
            10e18 << 128,
            ValueLib.v(10e18 << 128, 10 << 128, 10e18, true)
        );

        assertEq(
            10e18 << 128,
            ValueLib.v(10e18 << 128, 27 << 128, 10e18, false)
        );

        uint256 x = 12345e18;
        assertEq(x << 128, ValueLib.v(x << 128, 0, x, false));

        x = 8_888_888e18;
        assertEq(x << 128, ValueLib.v(x << 128, 1e6 << 128, x, true));
    }

    /// Test the v function at hard coded test cases.
    function testVHardCoded() public pure {
        // Small and under target
        assertApproxEqRel(
            451142869614988050254263049727044707418112,
            ValueLib.v(5183 << 128, 21 << 128, 1452, false),
            1e4
        );
        // Large and over target
        assertApproxEqRel(
            339402267962432329982252740804618083429751491437487773513274587156054016,
            // 1 quadrillion dollars!
            ValueLib.v(7e30 << 128, 54321 << 128, 1e33, false),
            1e6
        );
    }

    /// Test revert when we provide an x that is too small.
    function testNegativeV() public {
        uint256 tX128 = 9090e20 << 128;
        uint256 eX128 = 16 << 128;
        uint256 negX = FullMath.mulDiv(tX128, 1 << 128, eX128 + (2 << 128));
        vm.expectRevert();
        ValueLib.v(9090e20 << 128, 16 << 128, negX, false);
        // But one more is still postiive.
        ValueLib.v(9090e20 << 128, 16 << 128, negX + 1, false);
    }

    /// When v is at t, x will be equal to v no matter e or rounding.
    function testXwhenVatT() public {
        assertEq(
            10e18,
            ValueLib.x(10e18 << 128, 157 << 125, 10e18 << 128, true)
        );
        uint256 x = 181818e18;
        assertEq(x, ValueLib.x(x << 128, 1 << 125, x << 128, false));
        x = 5e12;
        assertEq(x, ValueLib.x(x << 128, 555 << 128, x << 128, false));
        x = 19e16;
        assertEq(x, ValueLib.x(x << 128, 47 << 128, x << 128, false));
        x = 12e6;
        assertEq(x, ValueLib.x(x << 128, 36 << 122, x << 128, false));
        x = 290e30;
        assertEq(x, ValueLib.x(x << 128, 15 << 127, x << 128, false));
    }

    /// Test x at some hard coded values.
    function testXHardCoded() public {
        assertEq(
            926074,
            ValueLib.x(123456789 << 128, 157 << 128, 151515 << 128, false)
        );
        assertApproxEqRel(
            30092969072164960795543732224,
            ValueLib.x(15e25 << 128, 973 << 128, 25e27 << 128, false),
            1e3
        );
    }

    /// Test t when everything is in balance. It should equal the balances.
    function testTatEquilibrium() public {
        SearchParams memory params = SearchParams({
            maxIter: 5,
            deMinimusX128: 100,
            targetSlippageX128: 1e12
        });
        uint256[] memory esX128 = new uint256[](3);
        uint256[] memory xs = new uint256[](3);
        for (uint256 i = 0; i < 3; ++i) {
            esX128[i] = 10 << 128;
            xs[i] = 100e18;
        }
        // Let's try starting at the right place.
        assertEq(100e18 << 128, ValueLib.t(params, esX128, xs, 100e18 << 128));
        // And now we need to search from a little off.
        assertApproxEqAbs(
            100e18 << 128,
            ValueLib.t(params, esX128, xs, 110e18 << 128),
            5
        );
    }

    /// Test t at some hard coded test cases.
    function testTHardCoded() public pure {
        SearchParams memory params = SearchParams({
            maxIter: 7,
            deMinimusX128: 2,
            targetSlippageX128: 1e12
        });
        uint256[] memory esX128 = new uint256[](6);
        esX128[0] = 11 << 128;
        esX128[1] = 15 << 128;
        esX128[2] = 31 << 128;
        esX128[3] = 25 << 128;
        esX128[4] = 14 << 128;
        esX128[5] = 25 << 128;
        uint256[] memory xs = new uint256[](6);
        xs[0] = 6e14;
        xs[1] = 3e15;
        xs[2] = 192e13;
        xs[3] = 2e14;
        xs[4] = 82e14;
        xs[5] = 4e14;
        // Let's try starting at the right place.
        assertApproxEqRel(
            745131471435920299611715960325491073270313151857950720,
            ValueLib.t(params, esX128, xs, 5e15 << 128),
            1e4
        );
    }

    /// Test hard coded values for stepT
    function testStepT() public pure {}

    function testDFDT() public pure {
        uint256[] memory esX128 = new uint256[](3);
        uint256[] memory xs = new uint256[](3);
        for (uint256 i = 0; i < 3; ++i) {
            esX128[i] = 10 << 128;
            xs[i] = 100e18;
        }
        assertApproxEqRel(
            -3 << 128,
            ValueLib.dfdt(100e18 << 128, esX128, xs),
            1
        );
    }

    function testDVDT() public pure {
        assertApproxEqAbs(0, ValueLib.dvdt(100 << 128, 10 << 128, 100), 100);
        assertApproxEqAbs(
            0,
            ValueLib.dvdt(100e18 << 128, 10 << 128, 100e18),
            100
        );
        assertApproxEqRel(
            -10476881009640969263111594805769011200, // + negOneX128,
            ValueLib.dvdt(110 << 128, 10 << 128, 90),
            1e6
        );
        assertApproxEqRel(
            14431618239950860598904080834236514304, // + negOneX128,
            ValueLib.dvdt(5000 << 128, 21 << 128, 7000),
            1e6
        );
        assertApproxEqRel(
            925466735054703244594257299557580800, // + negOneX128,
            ValueLib.dvdt(85 << 128, 12345 << 128, 500),
            1e9
        );
    }
}
