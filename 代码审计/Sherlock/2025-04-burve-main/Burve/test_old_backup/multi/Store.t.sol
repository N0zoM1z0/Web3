// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {Store} from "../../src/multi/Store.sol";
import {Edge} from "../../src/multi/Edge.sol";

contract StoreTest is Test {
    function testEdge() public {
        Edge storage def = Store.simplex().defaultEdge;
        def.amplitude = 100;

        // If we fetch an edge right now, we would get the default edge.
        address x = address(0x1234);
        address y = address(0x5678);
        Edge storage e = Store.edge(x, y);
        assertEq(e.amplitude, 100);
        Edge storage raw = Store.rawEdge(x, y);
        assertEq(raw.amplitude, 0);

        // If we assign to it, which we won't in practice, the default edge is overwritten.
        e.amplitude = 101;
        assertEq(raw.amplitude, 0);
        assertEq(def.amplitude, 101);

        // And once we assign to raw, then edge gets us the real edge.
        raw.amplitude = 200;
        assertEq(e.amplitude, 101);
        e = Store.edge(x, y);
        assertEq(e.amplitude, 200);
        assertEq(def.amplitude, 101);
        e.amplitude = 201;
        raw = Store.rawEdge(x, y);
        assertEq(raw.amplitude, 201);

        // Getting something else still gets us our default edge.
        Edge storage other = Store.edge(address(0x1010), address(0x2020));
        assertEq(other.amplitude, 101);
    }
}
