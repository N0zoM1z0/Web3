// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {ClosureId, newClosureId} from "../../src/multi/closure/Id.sol";
import {TokenRegLib} from "../../src/multi/Token.sol";
import {Store} from "../../src/multi/Store.sol";

contract ClosureTest is Test {
    function setUp() public {}

    function testNewClosureId() public {
        {
            TokenRegLib.register(address(1));
            TokenRegLib.register(address(2));
            TokenRegLib.register(address(3));
        }
        address[] memory tokens = new address[](1);
        tokens[0] = address(1);
        ClosureId cid1 = newClosureId(tokens);
        tokens[0] = address(2);
        ClosureId cid2 = newClosureId(tokens);
        tokens[0] = address(3);
        ClosureId cid3 = newClosureId(tokens);
        assertFalse(cid1.isEq(cid2));
        assertFalse(cid1.isEq(cid3));
        assertFalse(cid2.isEq(cid3));
        tokens = new address[](2);
        tokens[0] = address(1);
        tokens[1] = address(2);
        ClosureId cid12 = newClosureId(tokens);
        tokens[1] = address(3);
        ClosureId cid13 = newClosureId(tokens);
        tokens[0] = address(2);
        ClosureId cid23 = newClosureId(tokens);
        assertFalse(cid1.isEq(cid12));
        assertFalse(cid1.isEq(cid13));
        assertFalse(cid1.isEq(cid23));
        assertFalse(cid2.isEq(cid12));
        assertFalse(cid2.isEq(cid13));
        assertFalse(cid2.isEq(cid23));
        assertFalse(cid3.isEq(cid12));
        assertFalse(cid3.isEq(cid13));
        assertFalse(cid3.isEq(cid23));
        tokens = new address[](3);
        tokens[0] = address(3);
        tokens[1] = address(1);
        tokens[2] = address(2);
        ClosureId cid123 = newClosureId(tokens);
        assertFalse(cid1.isEq(cid123));
        assertFalse(cid2.isEq(cid123));
        assertFalse(cid3.isEq(cid123));
        assertFalse(cid12.isEq(cid123));
        assertFalse(cid13.isEq(cid123));
        assertFalse(cid23.isEq(cid123));
    }
}
