// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {Mutex, MutexImpl, MutexLib, MutexBase} from "../src/Util/Mutex.sol";

contract MutexTest is PRBTest, StdCheats, MutexBase {
    using MutexImpl for Mutex;

    /// Call lock if relocking. Call unlock if unlocking
    function lockedFunc(bool relock, bool unlock) public mutexLocked {
        Mutex storage m = MutexLib.mutexStorage();
        assertTrue(m.isLocked());

        if (relock) {
            m.lock();
        }
        if (unlock) {
            m.unlock();
        }
    }

    function nestingDoll() public mutexLocked {
        nestingNestingDoll();
    }

    function nestingNestingDoll() public mutexLocked {
        assertTrue(false);
    }

    function fUnlock() public {
        Mutex storage m = MutexLib.mutexStorage();
        m.unlock();
    }

    function fLock() public {
        Mutex storage m = MutexLib.mutexStorage();
        m.lock();
    }

    function testMutexLock() public {
        Mutex storage m = MutexLib.mutexStorage();
        m.lock();
        assertTrue(m.isLocked());
        fUnlock(); // Test unlocking in a different closure.
        assertFalse(m.isLocked());

        vm.expectRevert(MutexImpl.DoubleUnlock.selector);
        fUnlock();

        fLock();
        m.lock();
        vm.expectRevert(MutexImpl.DoubleUnlock.selector);
        m.unlock();

        assertFalse(m.isLocked());
    }

    /// Test using the mutex modifier does what we want.
    function testMutexModifier() public {
        Mutex storage m = MutexLib.mutexStorage();

        lockedFunc(false, false);
        // Test it unlocked after.
        lockedFunc(false, false);

        vm.expectRevert(MutexImpl.MutexContention.selector);
        lockedFunc(true, false);
        m.unlock();
        vm.expectRevert(MutexImpl.MutexContention.selector);
        lockedFunc(true, true);
        m.unlock();

        vm.expectRevert(MutexImpl.DoubleUnlock.selector);
        lockedFunc(false, true);

        assertFalse(m.isLocked());
        vm.expectRevert(MutexImpl.MutexContention.selector);
        nestingDoll();
        m.unlock();
    }
}
