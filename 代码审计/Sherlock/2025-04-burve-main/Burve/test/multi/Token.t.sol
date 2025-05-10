// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, stdError} from "forge-std/Test.sol";

import {MAX_TOKENS} from "../../src/multi/Constants.sol";
import {Store} from "../../src/multi/Store.sol";
import {TokenRegLib, TokenRegistry} from "../../src/multi/Token.sol";

contract TokenTest is Test {
    // -- register tests ----

    function testRegister() public {
        TokenRegistry storage tokenReg = Store.tokenRegistry();

        // register token 1
        vm.expectEmit(true, false, false, true);
        emit TokenRegLib.TokenRegistered(address(0x1));
        TokenRegLib.register(address(0x1));

        assertEq(tokenReg.tokens.length, 1);
        assertEq(tokenReg.tokenIdx[address(0x1)], 0);

        // register token 2
        vm.expectEmit(true, false, false, true);
        emit TokenRegLib.TokenRegistered(address(0x2));
        TokenRegLib.register(address(0x2));

        assertEq(tokenReg.tokens.length, 2);
        assertEq(tokenReg.tokenIdx[address(0x2)], 1);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertRegisterAtTokenCapacity() public {
        for (uint160 i = 0; i < MAX_TOKENS; i++) {
            TokenRegLib.register(address(i));
        }

        vm.expectRevert(
            abi.encodeWithSelector(TokenRegLib.AtTokenCapacity.selector)
        );
        TokenRegLib.register(address(uint160(MAX_TOKENS)));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertRegisterTokenAlreadyRegistered() public {
        TokenRegLib.register(address(0x1));

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegLib.TokenAlreadyRegistered.selector,
                address(0x1)
            )
        );
        TokenRegLib.register(address(0x1));
    }

    // -- numVertices tests ----

    function testNumVertices() public {
        assertEq(TokenRegLib.numVertices(), 0);

        for (uint160 i = 1; i <= MAX_TOKENS; i++) {
            TokenRegLib.register(address(i));
            assertEq(TokenRegLib.numVertices(), i);
        }
    }

    // -- getIdx tests ----

    function testGetIdx() public {
        TokenRegLib.register(address(0x1));
        TokenRegLib.register(address(0x2));
        TokenRegLib.register(address(0x3));

        assertEq(TokenRegLib.getIdx(address(0x1)), 0);
        assertEq(TokenRegLib.getIdx(address(0x2)), 1);
        assertEq(TokenRegLib.getIdx(address(0x3)), 2);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertGetIdxTokenNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegLib.TokenNotFound.selector,
                address(0x1)
            )
        );
        TokenRegLib.getIdx(address(0x1));
    }

    // -- getToken tests ----

    function testGetToken() public {
        TokenRegLib.register(address(0x1));
        TokenRegLib.register(address(0x2));
        TokenRegLib.register(address(0x3));

        assertEq(TokenRegLib.getToken(0), address(0x1));
        assertEq(TokenRegLib.getToken(1), address(0x2));
        assertEq(TokenRegLib.getToken(2), address(0x3));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertGetTokenIndexNotFound() public {
        TokenRegLib.register(address(0x1));
        TokenRegLib.register(address(0x2));
        TokenRegLib.register(address(0x3));

        vm.expectRevert(stdError.indexOOBError);
        TokenRegLib.getToken(3);
    }

    // -- isRegistered tests ----

    function testIsRegistered() public {
        assertFalse(TokenRegLib.isRegistered(address(0x1)));
        assertFalse(TokenRegLib.isRegistered(address(0x2)));
        assertFalse(TokenRegLib.isRegistered(address(0x3)));

        TokenRegLib.register(address(0x1));
        assertTrue(TokenRegLib.isRegistered(address(0x1)));
        assertFalse(TokenRegLib.isRegistered(address(0x2)));

        TokenRegLib.register(address(0x2));
        assertTrue(TokenRegLib.isRegistered(address(0x1)));
        assertTrue(TokenRegLib.isRegistered(address(0x2)));
        assertFalse(TokenRegLib.isRegistered(address(0x3)));
    }
}
