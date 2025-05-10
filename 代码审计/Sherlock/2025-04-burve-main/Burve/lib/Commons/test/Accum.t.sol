// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {Accum, AccumImpl} from "../src/Util/Accum.sol";

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract AccumTest is PRBTest, StdCheats {
    using AccumImpl for Accum;

    function testUintAccum() public {
        Accum a = AccumImpl.from(uint256(420024));
        Accum b = a.add(1000);
        assertEq(b.diff(a), 1000);
        assertEq(a.diff(b), type(uint256).max - 1000 + 1); // The one for underflowing.

        Accum c = b.diffAccum(a);
        assertEq(Accum.unwrap(c), 1000);
    }

    function testIntAccum() public {
        Accum a = AccumImpl.from(int256(1234567890));
        uint256 delta = 12345678901234; // Greater than a.
        Accum b = a.add(delta);
        assertEq(b.diff(a), delta);
        assertEq(a.diff(b), type(uint256).max - delta + 1); // The one for underflowing.

        Accum c = b.diffAccum(a);
        assertEq(Accum.unwrap(c), delta);

        // Start with a negative value.
        a = AccumImpl.from(int256(-1234567890));
        delta = 12345678901234; // Greater than a.
        b = a.add(delta);
        assertEq(b.diff(a), delta);
        assertEq(a.diff(b), type(uint256).max - delta + 1); // The one for underflowing.
    }
}
