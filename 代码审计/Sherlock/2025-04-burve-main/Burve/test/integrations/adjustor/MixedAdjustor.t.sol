// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {AdminLib} from "Commons/Util/Admin.sol";

import {IAdjustor} from "../../../src/integrations/adjustor/IAdjustor.sol";
import {FixedAdjustor} from "../../../src/integrations/adjustor/FixedAdjustor.sol";
import {MixedAdjustor} from "../../../src/integrations/adjustor/MixedAdjustor.sol";
import {NullAdjustor} from "../../../src/integrations/adjustor/NullAdjustor.sol";

interface IUintAdjustor {
    function toNominal(
        address token,
        uint256 real,
        bool roundUp
    ) external view returns (uint256 nominal);

    function toReal(
        address token,
        uint256 nominal,
        bool roundUp
    ) external view returns (uint256 real);
}

interface IIntAdjustor {
    function toNominal(
        address token,
        int256 real,
        bool roundUp
    ) external view returns (int256 nominal);

    function toReal(
        address token,
        int256 nominal,
        bool roundUp
    ) external view returns (int256 real);
}

contract MixedAdjustorTest is Test {
    MixedAdjustor public adj;
    address public owner;
    address public tokenA;
    address public tokenB;
    address public fixedAdj;

    function setUp() public {
        owner = makeAddr("owner");
        tokenA = makeAddr("tokenA");
        tokenB = makeAddr("tokenB");

        vm.startPrank(owner);

        adj = new MixedAdjustor();

        FixedAdjustor _fixedAdj = new FixedAdjustor();
        _fixedAdj.setAdjustment(tokenA, uint256(20 << 128));
        _fixedAdj.setAdjustment(tokenB, uint256(10 << 128));
        fixedAdj = address(_fixedAdj);

        vm.stopPrank();
    }

    // -- constructor tests ----

    function testCreate() public {
        assertNotEq(adj.defAdj(), address(0x0));
    }

    // -- setAdjustor tests ----

    function testSetAdjustor() public {
        vm.startPrank(owner);

        // check tokenA
        assertEq(adj.adjAddr(tokenA), address(0x0));
        address adjustorA = makeAddr("adjustorA");
        adj.setAdjustor(tokenA, adjustorA);
        assertEq(adj.adjAddr(tokenA), adjustorA);

        // check tokenB
        assertEq(adj.adjAddr(tokenB), address(0x0));
        address adjustorB = makeAddr("adjustorB");
        adj.setAdjustor(tokenB, adjustorB);
        assertEq(adj.adjAddr(tokenB), adjustorB);

        vm.stopPrank();
    }

    function testRevertSetAdjustorNotOwner() public {
        vm.expectRevert(AdminLib.NotOwner.selector);
        adj.setAdjustor(tokenA, address(0x0));
    }

    // -- setDefaultAdjustor tests ----

    function testSetDefaultAdjustor() public {
        vm.startPrank(owner);

        address defAdjustor = makeAddr("defaultAdjustor");
        adj.setDefaultAdjustor(defAdjustor);
        assertEq(adj.defAdj(), defAdjustor);

        vm.stopPrank();
    }

    function testRevertSetDefaultAdjustorNotOwner() public {
        vm.expectRevert(AdminLib.NotOwner.selector);
        adj.setDefaultAdjustor(address(0x0));
    }

    // -- toNominal uint tests

    function testToNominalUintCallsDefaultAdjustor() public {
        address token = tokenA;
        uint256 real = 10e18;
        bool roundUp = true;

        // rounding up
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(
                IUintAdjustor.toNominal.selector,
                token,
                real,
                roundUp
            )
        );
        adj.toNominal(token, real, roundUp);

        // rounding down
        token = tokenB;
        real = 1e6;
        roundUp = false;
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(
                IUintAdjustor.toNominal.selector,
                token,
                real,
                roundUp
            )
        );
        adj.toNominal(token, real, roundUp);
    }

    function testToNominalUintMatchesDefaultAdjustorResult() public {
        address token = tokenA;
        uint256 real = 10e18;
        bool roundUp = true;

        uint256 nominal;

        // rounding up
        nominal = IAdjustor(adj.defAdj()).toNominal(token, real, roundUp);
        assertEq(adj.toNominal(token, real, roundUp), nominal);

        // rounding down
        token = tokenB;
        real = 1e6;
        roundUp = false;
        nominal = IAdjustor(adj.defAdj()).toNominal(token, real, roundUp);
        assertEq(adj.toNominal(token, real, roundUp), nominal);
    }

    function testToNominalUintCallsSetAdjustor() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        adj.setAdjustor(tokenB, fixedAdj);
        vm.stopPrank();

        address token = tokenA;
        uint256 real = 10e18;
        bool roundUp = true;

        // rounding up
        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(
                IUintAdjustor.toNominal.selector,
                token,
                real,
                roundUp
            )
        );
        adj.toNominal(token, real, roundUp);

        // rounding down
        token = tokenB;
        real = 1e6;
        roundUp = false;
        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(
                IUintAdjustor.toNominal.selector,
                token,
                real,
                roundUp
            )
        );
        adj.toNominal(token, real, roundUp);
    }

    function testToNominalUintMatchesSetAdjustorResult() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        adj.setAdjustor(tokenB, fixedAdj);
        vm.stopPrank();

        address token = tokenA;
        uint256 real = 10e18;
        bool roundUp = true;

        uint256 nominal;

        // rounding up
        nominal = IAdjustor(fixedAdj).toNominal(token, real, roundUp);
        assertEq(adj.toNominal(token, real, roundUp), nominal);

        // rounding down
        token = tokenB;
        real = 1e6;
        roundUp = false;
        nominal = IAdjustor(fixedAdj).toNominal(token, real, roundUp);
        assertEq(adj.toNominal(token, real, roundUp), nominal);
    }

    // -- toNominal int tests

    function testToNominalIntCallsDefaultAdjustor() public {
        address token = tokenA;
        int256 real = 10e18;
        bool roundUp = true;

        // rounding up
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(
                IIntAdjustor.toNominal.selector,
                token,
                real,
                roundUp
            )
        );
        adj.toNominal(token, real, roundUp);

        // rounding down
        token = tokenB;
        real = -1e6;
        roundUp = false;
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(
                IIntAdjustor.toNominal.selector,
                token,
                real,
                roundUp
            )
        );
        adj.toNominal(token, real, roundUp);
    }

    function testToNominalIntMatchesDefaultAdjustorResult() public {
        address token = tokenA;
        int256 real = 10e18;
        bool roundUp = true;

        int256 nominal;

        // rounding up
        nominal = IAdjustor(adj.defAdj()).toNominal(token, real, roundUp);
        assertEq(adj.toNominal(token, real, roundUp), nominal);

        // rounding down
        token = tokenB;
        real = -1e6;
        roundUp = false;
        nominal = IAdjustor(adj.defAdj()).toNominal(token, real, roundUp);
        assertEq(adj.toNominal(token, real, roundUp), nominal);
    }

    function testToNominalIntCallsSetAdjustor() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        adj.setAdjustor(tokenB, fixedAdj);
        vm.stopPrank();

        address token = tokenA;
        int256 real = 10e18;
        bool roundUp = true;

        // rounding up
        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(
                IIntAdjustor.toNominal.selector,
                token,
                real,
                roundUp
            )
        );
        adj.toNominal(token, real, roundUp);

        // rounding down
        token = tokenB;
        real = -1e6;
        roundUp = false;
        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(
                IIntAdjustor.toNominal.selector,
                token,
                real,
                roundUp
            )
        );
        adj.toNominal(token, real, roundUp);
    }

    function testToNominalIntMatchesSetAdjustorResult() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        adj.setAdjustor(tokenB, fixedAdj);
        vm.stopPrank();

        address token = tokenA;
        int256 real = 10e18;
        bool roundUp = true;

        int256 nominal;

        // rounding up
        nominal = IAdjustor(fixedAdj).toNominal(token, real, roundUp);
        assertEq(adj.toNominal(token, real, roundUp), nominal);

        // rounding down
        token = tokenB;
        real = -1e6;
        roundUp = false;
        nominal = IAdjustor(fixedAdj).toNominal(token, real, roundUp);
        assertEq(adj.toNominal(token, real, roundUp), nominal);
    }

    // toReal uint tests

    function testToRealUintCallsDefaultAdjustor() public {
        address token = tokenA;
        uint256 nominal = 10e18;
        bool roundUp = true;

        // rounding up
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(
                IUintAdjustor.toReal.selector,
                token,
                nominal,
                roundUp
            )
        );
        adj.toReal(token, nominal, roundUp);

        // rounding down
        token = tokenB;
        nominal = 1e6;
        roundUp = false;
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(
                IUintAdjustor.toReal.selector,
                token,
                nominal,
                roundUp
            )
        );
        adj.toReal(token, nominal, roundUp);
    }

    function testToRealUintMatchesDefaultAdjustorResult() public {
        address token = tokenA;
        uint256 nominal = 10e18;
        bool roundUp = true;

        uint256 real;

        // rounding up
        real = IAdjustor(adj.defAdj()).toReal(token, nominal, roundUp);
        assertEq(adj.toReal(token, nominal, roundUp), real);

        // rounding down
        token = tokenB;
        nominal = 1e6;
        roundUp = false;
        real = IAdjustor(adj.defAdj()).toReal(token, nominal, roundUp);
        assertEq(adj.toReal(token, nominal, roundUp), real);
    }

    function testToRealUintCallsSetAdjustor() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        adj.setAdjustor(tokenB, fixedAdj);
        vm.stopPrank();

        address token = tokenA;
        uint256 nominal = 10e18;
        bool roundUp = true;

        // rounding up
        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(
                IUintAdjustor.toReal.selector,
                token,
                nominal,
                roundUp
            )
        );
        adj.toReal(token, nominal, roundUp);

        // rounding down
        token = tokenB;
        nominal = 1e6;
        roundUp = false;
        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(
                IUintAdjustor.toReal.selector,
                token,
                nominal,
                roundUp
            )
        );
        adj.toReal(token, nominal, roundUp);
    }

    function testToRealUintMatchesSetAdjustorResult() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        adj.setAdjustor(tokenB, fixedAdj);
        vm.stopPrank();

        address token = tokenA;
        uint256 nominal = 10e18;
        bool roundUp = true;

        uint256 real;

        // rounding up
        real = IAdjustor(fixedAdj).toReal(token, nominal, roundUp);
        assertEq(adj.toReal(token, nominal, roundUp), real);

        // rounding down
        token = tokenB;
        nominal = 1e6;
        roundUp = false;
        real = IAdjustor(fixedAdj).toReal(token, nominal, roundUp);
        assertEq(adj.toReal(token, nominal, roundUp), real);
    }

    // toReal int tests

    function testToRealIntCallsDefaultAdjustor() public {
        address token = tokenA;
        int256 nominal = 10e18;
        bool roundUp = true;

        // rounding up
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(
                IIntAdjustor.toReal.selector,
                token,
                nominal,
                roundUp
            )
        );
        adj.toReal(token, nominal, roundUp);

        // rounding down
        token = tokenB;
        nominal = -1e6;
        roundUp = false;
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(
                IIntAdjustor.toReal.selector,
                token,
                nominal,
                roundUp
            )
        );
        adj.toReal(token, nominal, roundUp);
    }

    function testToRealIntMatchesDefaultAdjustorResult() public {
        address token = tokenA;
        int256 nominal = 10e18;
        bool roundUp = true;

        int256 real;

        // rounding up
        real = IAdjustor(adj.defAdj()).toReal(token, nominal, roundUp);
        assertEq(adj.toReal(token, nominal, roundUp), real);

        // rounding down
        token = tokenB;
        nominal = -1e6;
        roundUp = false;
        real = IAdjustor(adj.defAdj()).toReal(token, nominal, roundUp);
        assertEq(adj.toReal(token, nominal, roundUp), real);
    }

    function testToRealIntCallsSetAdjustor() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        adj.setAdjustor(tokenB, fixedAdj);
        vm.stopPrank();

        address token = tokenA;
        int256 nominal = 10e18;
        bool roundUp = true;

        // rounding up
        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(
                IIntAdjustor.toReal.selector,
                token,
                nominal,
                roundUp
            )
        );
        adj.toReal(token, nominal, roundUp);

        // rounding down
        token = tokenB;
        nominal = -1e6;
        roundUp = false;
        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(
                IIntAdjustor.toReal.selector,
                token,
                nominal,
                roundUp
            )
        );
        adj.toReal(token, nominal, roundUp);
    }

    function testToRealIntMatchesSetAdjustorResult() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        adj.setAdjustor(tokenB, fixedAdj);
        vm.stopPrank();

        address token = tokenA;
        int256 nominal = 10e18;
        bool roundUp = true;

        int256 real;

        // rounding up
        real = IAdjustor(fixedAdj).toReal(token, nominal, roundUp);
        assertEq(adj.toReal(token, nominal, roundUp), real);

        // rounding down
        token = tokenB;
        nominal = -1e6;
        roundUp = false;
        real = IAdjustor(fixedAdj).toReal(token, nominal, roundUp);
        assertEq(adj.toReal(token, nominal, roundUp), real);
    }

    // -- cacheAdjustment tests ----

    function testCacheAdjustmentCallsDefaultAdjustor() public {
        vm.expectCall(
            adj.defAdj(),
            abi.encodeWithSelector(IAdjustor.cacheAdjustment.selector, tokenA)
        );
        adj.cacheAdjustment(tokenA);
    }

    function testCacheAdjustmentCallsSetAdjustor() public {
        vm.startPrank(owner);
        adj.setAdjustor(tokenA, fixedAdj);
        vm.stopPrank();

        vm.expectCall(
            fixedAdj,
            abi.encodeWithSelector(IAdjustor.cacheAdjustment.selector, tokenA)
        );
        adj.cacheAdjustment(tokenA);
    }
}
