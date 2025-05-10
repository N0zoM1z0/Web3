// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {MAX_TOKENS} from "../../src/multi/Constants.sol";
import {ValueLib, SearchParams} from "../../src/multi/Value.sol";
import {Simplex, SimplexLib} from "../../src/multi/Simplex.sol";
import {Store} from "../../src/multi/Store.sol";

contract SimplexTest is Test {
    // -- earnings tests ----

    function testProtocolFees() public {
        uint256[MAX_TOKENS] memory protocolEarnings = SimplexLib
            .protocolEarnings();
        for (uint256 i = 0; i < MAX_TOKENS; i++) {
            assertEq(protocolEarnings[i], 0);
        }

        SimplexLib.protocolTake(0, 10e8);
        SimplexLib.protocolTake(1, 5e8);
        SimplexLib.protocolTake(2, 20e8);
        SimplexLib.protocolTake(3, 15e8);
        SimplexLib.protocolTake(4, 25e8);

        protocolEarnings = SimplexLib.protocolEarnings();
        assertEq(protocolEarnings[0], 10e8);
        assertEq(protocolEarnings[1], 5e8);
        assertEq(protocolEarnings[2], 20e8);
        assertEq(protocolEarnings[3], 15e8);
        assertEq(protocolEarnings[4], 25e8);

        for (uint256 i = 5; i < MAX_TOKENS; i++) {
            assertEq(protocolEarnings[i], 0);
        }
    }

    function testProtocolTake() public {
        SimplexLib.protocolTake(0, 10e8);
        SimplexLib.protocolTake(2, 5e8);

        Simplex storage simplex = Store.simplex();
        assertEq(simplex.protocolEarnings[0], 10e8);
        assertEq(simplex.protocolEarnings[1], 0);
        assertEq(simplex.protocolEarnings[2], 5e8);
    }

    function testProtocolGive() public {
        Simplex storage simplex = Store.simplex();

        uint256 amount = SimplexLib.protocolGive(0);
        assertEq(amount, 0);
        assertEq(simplex.protocolEarnings[0], 0);

        SimplexLib.protocolTake(1, 10e8);

        amount = SimplexLib.protocolGive(1);
        assertEq(amount, 10e8);
        assertEq(simplex.protocolEarnings[1], 0);
    }

    // -- esX128 tests ----

    function testGetEsX128Default() public view {
        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        for (uint256 i = 0; i < MAX_TOKENS; i++) {
            assertEq(esX128[i], 0);
        }

        Simplex storage simplex = Store.simplex();
        for (uint256 i = 0; i < MAX_TOKENS; i++) {
            assertEq(simplex.esX128[i], 0);
            assertEq(simplex.minXPerTX128[i], 0);
        }
    }

    function testGetEsX128Init() public {
        SimplexLib.init("ValueToken", "BVT", address(0x0));

        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        for (uint256 i = 0; i < MAX_TOKENS; i++) {
            assertEq(esX128[i], 10 << 128);
        }

        Simplex storage simplex = Store.simplex();
        for (uint256 i = 0; i < MAX_TOKENS; i++) {
            assertEq(simplex.esX128[i], 10 << 128);
            assertEq(
                simplex.minXPerTX128[i],
                ValueLib.calcMinXPerTX128(10 << 128)
            );
        }
    }

    function testGetEX128Default() public view {
        uint256 esX128 = SimplexLib.getEX128(0);
        assertEq(esX128, 0);

        esX128 = SimplexLib.getEX128(1);
        assertEq(esX128, 0);
    }

    function testGetEX128Init() public {
        SimplexLib.init("ValueToken", "BVT", address(0x0));

        uint256 esX128 = SimplexLib.getEX128(0);
        assertEq(esX128, 10 << 128);

        esX128 = SimplexLib.getEX128(1);
        assertEq(esX128, 10 << 128);
    }

    function testSetEX128() public {
        SimplexLib.setEX128(0, 20 << 128);
        SimplexLib.setEX128(1, 30 << 128);
        SimplexLib.setEX128(2, 40 << 128);

        assertEq(SimplexLib.getEX128(0), 20 << 128);
        assertEq(SimplexLib.getEX128(1), 30 << 128);
        assertEq(SimplexLib.getEX128(2), 40 << 128);

        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        assertEq(esX128[0], 20 << 128);
        assertEq(esX128[1], 30 << 128);
        assertEq(esX128[2], 40 << 128);

        Simplex storage simplex = Store.simplex();
        assertEq(simplex.esX128[0], 20 << 128);
        assertEq(simplex.esX128[1], 30 << 128);
        assertEq(simplex.esX128[2], 40 << 128);
        assertEq(simplex.minXPerTX128[0], ValueLib.calcMinXPerTX128(20 << 128));
        assertEq(simplex.minXPerTX128[1], ValueLib.calcMinXPerTX128(30 << 128));
        assertEq(simplex.minXPerTX128[2], ValueLib.calcMinXPerTX128(40 << 128));
    }

    // -- adjustor tests ----

    function testGetAdjustorDefault() public view {
        assertEq(SimplexLib.getAdjustor(), address(0x0));
    }

    function testGetAdjustorInit() public {
        address adjustor = makeAddr("initAdjustor");
        SimplexLib.init("ValueToken", "BVT", adjustor);
        assertEq(SimplexLib.getAdjustor(), adjustor);
    }

    function testSetAdjustor() public {
        address adjustor = makeAddr("setAdjustor");
        SimplexLib.setAdjustor(adjustor);
        assertEq(SimplexLib.getAdjustor(), adjustor);
    }

    // -- BGT exchanger tests ----

    function testGetBGTExchanger() public view {
        assertEq(SimplexLib.getBGTExchanger(), address(0x0));
    }

    function testSetBGTExchanger() public {
        address bgtExchanger = makeAddr("bgtExchanger");
        SimplexLib.setBGTExchanger(bgtExchanger);
        assertEq(SimplexLib.getBGTExchanger(), bgtExchanger);
    }

    // -- initTarget tests ----

    function testGetInitTargetDefault() public view {
        assertEq(SimplexLib.getInitTarget(), 0);
    }

    function testGetInitTargetInit() public {
        SimplexLib.init("ValueToken", "BVT", address(0x0));
        assertEq(SimplexLib.getInitTarget(), SimplexLib.DEFAULT_INIT_TARGET);
    }

    function testSetInitTarget() public {
        SimplexLib.setInitTarget(2e18);
        assertEq(SimplexLib.getInitTarget(), 2e18);

        SimplexLib.setInitTarget(0);
        assertEq(SimplexLib.getInitTarget(), 0);

        SimplexLib.setInitTarget(1e6);
        assertEq(SimplexLib.getInitTarget(), 1e6);
    }

    // -- searchParam tests ----

    function testGetSearchParamsDefault() public {
        SimplexLib.init("ValueToken", "BVT", address(0x0));

        SearchParams memory sp = SimplexLib.getSearchParams();
        assertEq(sp.maxIter, 5);
        assertEq(sp.deMinimusX128, 100);
        assertEq(sp.targetSlippageX128, 1e12);
    }
}
