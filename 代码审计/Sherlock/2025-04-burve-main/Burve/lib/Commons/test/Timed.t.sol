// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {Timed, TimedEntry} from "../src/Util/Timed.sol";

contract TimedTest is PRBTest, StdCheats {
    TimedSender public sender;

    function setUp() public {
        sender = new TimedSender(address(this));
    }

    function send(uint256 useId, bytes memory entry) internal {
        sender.precommit(useId, entry);
    }

    function precommit(uint256 useId, bytes calldata entry) external {
        Timed.precommit(useId, entry);
    }

    function testTimed() public {
        TimedEntry memory e = Timed.fetch(Timed.timedStore(), 0);
        assertEq(e.timestamp, 0); // There is no entry yet.

        uint256 val = 5;
        bytes memory entry = abi.encode(5);
        send(0, entry);

        // try to get the precommit
        e = Timed.fetch(Timed.timedStore(), 0);
        assertEq(e.timestamp, uint64(block.timestamp));
        // Get it with a fetch and delete
        e = Timed.fetchAndDelete(0);
        assertEq(e.timestamp, uint64(block.timestamp));
        assertEq(e.submitter, address(sender));
        uint256 res = abi.decode(e.entry, (uint256));
        assertEq(res, val);

        // It should be deleted now.
        e = Timed.fetch(Timed.timedStore(), 0);
        assertEq(e.timestamp, 0);

        // precommit something more complicated.
        entry = abi.encode(address(this), uint64(4), int128(100));
        send(5, entry);

        // Fetching the wrong useId won't get anything
        e = Timed.fetch(Timed.timedStore(), 0);
        assertEq(e.timestamp, 0);
        e = Timed.fetch(Timed.timedStore(), 2);
        assertEq(e.timestamp, 0);

        // The right one.
        e = Timed.fetch(Timed.timedStore(), 5);
        assertEq(e.timestamp, uint64(block.timestamp));
        assertEq(e.submitter, address(sender));
        (address a, uint64 b, int128 c) = abi.decode(e.entry, (address, uint64, int128));
        assertEq(a, address(this));
        assertEq(b, 4);
        assertEq(c, 100);

        // A fetch won't delete it. It'll still be here.
        e = Timed.fetch(Timed.timedStore(), 5);
        assertEq(e.timestamp, uint64(block.timestamp));

        // Delete it.
        Timed.deleteEntry(5);
        e = Timed.fetch(Timed.timedStore(), 5);
        assertEq(e.timestamp, 0);
    }

    function testFetchPrecommit() public {
        bytes memory data = abi.encode(uint256(101));
        send(1, data);
        data = abi.encode(uint256(202));
        send(2, data);

        vm.expectRevert(
            abi.encodeWithSelector(
                Timed.PrematureParamUpdate.selector, 1, uint64(block.timestamp) + 10, uint64(block.timestamp)
            )
        );
        Timed.fetchPrecommit(1, 10);
        vm.expectRevert(
            abi.encodeWithSelector(
                Timed.PrematureParamUpdate.selector, 1, uint64(block.timestamp) + 5, uint64(block.timestamp)
            )
        );
        // Roll but not far enough
        vm.roll(block.timestamp + 5);
        Timed.fetchPrecommit(1, 10);
        // Roll enough
        vm.roll(block.timestamp + 5);
        bytes memory entry = Timed.fetchPrecommit(1, 10);
        assertEq(abi.decode(entry, (uint256)), 101);

        // A fetch that doesn't exist.
        vm.expectRevert(abi.encodeWithSelector(Timed.NoPrecommitFound.selector, 3));
        Timed.fetchPrecommit(3, 0);

        // No delay also works.
        entry = Timed.fetchPrecommit(2, 0);
        assertEq(abi.decode(entry, (uint256)), 202);
    }

    function testExistingPrecommit() public {
        bytes memory data = abi.encode(uint256(1));
        send(1, data);
        vm.expectRevert(abi.encodeWithSelector(Timed.ExistingPrecommitFound.selector, 1));
        send(1, data);
    }
}

/// Helper contract to send bytes to the TimedTest as calldata
contract TimedSender {
    TimedTest public test;

    constructor(address _test) {
        test = TimedTest(_test);
    }

    function precommit(uint256 useId, bytes calldata entry) external {
        test.precommit(useId, entry);
    }
}
