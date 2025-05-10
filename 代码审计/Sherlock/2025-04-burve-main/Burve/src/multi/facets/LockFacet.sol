// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {AdminLib} from "Commons/Util/Admin.sol";
import {Store} from "../Store.sol";
import {VertexLib} from "../vertex/Id.sol";

struct Locker {
    mapping(address => bool) lockers;
    mapping(address => bool) unlockers;
}

/// Methods for handling vertex locking.
/// @dev At the moment, there is no automatic locking, only manual.
contract LockFacet {
    function lock(address token) external {
        if (!Store.locker().lockers[msg.sender]) {
            AdminLib.validateOwner();
        }

        Store.vertex(VertexLib.newId(token)).lock();
    }

    function unlock(address token) external {
        if (!Store.locker().unlockers[msg.sender]) {
            AdminLib.validateOwner();
        }
        Store.vertex(VertexLib.newId(token)).unlock();
    }

    function isLocked(address token) external view returns (bool) {
        return Store.vertex(VertexLib.newId(token)).isLocked();
    }

    /* Admin */

    function addLocker(address admin) external {
        AdminLib.validateOwner();
        Store.locker().lockers[admin] = true;
    }

    function removeLocker(address admin) external {
        AdminLib.validateOwner();
        Store.locker().lockers[admin] = false;
    }

    function addUnlocker(address admin) external {
        AdminLib.validateOwner();
        Store.locker().unlockers[admin] = true;
    }

    function removeUnlocker(address admin) external {
        AdminLib.validateOwner();
        Store.locker().unlockers[admin] = false;
    }
}
