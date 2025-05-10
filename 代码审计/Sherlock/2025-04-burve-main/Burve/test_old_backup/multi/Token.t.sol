// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {Store} from "../../src/multi/Store.sol";
import {TokenRegistry, TokenRegLib} from "../../src/multi/Token.sol";

contract TokenTest is Test {
    function setUp() public {}

    function testBasic() public {
        TokenRegistry storage tReg = Store.tokenRegistry();
        assertEq(TokenRegLib.numVertices(), 0);
        // Add tokens
        tReg.register(address(1));
        assertEq(TokenRegLib.numVertices(), 1);
        tReg.register(address(2));
        tReg.register(address(3));
        tReg.register(address(4));
        assertEq(TokenRegLib.numVertices(), 4);
        // Test getIdx
        assertEq(TokenRegLib.getIdx(address(4)), 3);
        assertEq(TokenRegLib.getIdx(address(3)), 2);
        assertEq(TokenRegLib.getIdx(address(2)), 1);
        assertEq(TokenRegLib.getIdx(address(1)), 0);
        // Test for getIdx error.
        vm.expectRevert();
        TokenRegLib.getIdx(address(5));
    }

    function testEmpty() public {
        // Error while still empty
        vm.expectRevert();
        TokenRegLib.getIdx(address(0));
    }
}
