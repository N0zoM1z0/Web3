// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ClosureId} from "../closure/Id.sol";
import {VaultE4626} from "./E4626.sol";

/// The types of vaults we can handle.
enum VaultType {
    UnImplemented,
    E4626
}

// The number of temporary variables used by vaults. See VaultTemp.
uint256 constant NUM_VAULT_VARS = 4;

/// An in-memory struct for holding temporary variables used by the vault implementations
struct VaultTemp {
    uint256[NUM_VAULT_VARS] vars;
}

/// An in-memory struct for dynamically dispatching to a specific vault.
struct VaultPointer {
    bytes32 slotAddress;
    VaultType vType;
    VaultTemp temp;
}

using VaultPointerImpl for VaultPointer global;

library VaultPointerImpl {
    error VaultTypeUnrecognized(VaultType);

    /// Queue up a deposit for a given cid.
    function deposit(
        VaultPointer memory self,
        ClosureId cid,
        uint256 amount
    ) internal {
        if (isNull(self) || amount == 0) return;

        if (self.vType == VaultType.E4626) {
            getE4626(self).deposit(self.temp, cid, amount);
        } else {
            revert VaultTypeUnrecognized(self.vType);
        }
    }

    /// Queue up a withdrawal for a given cid.
    function withdraw(
        VaultPointer memory self,
        ClosureId cid,
        uint256 amount
    ) internal {
        if (isNull(self) || amount == 0) return;

        if (self.vType == VaultType.E4626) {
            getE4626(self).withdraw(self.temp, cid, amount);
        } else {
            revert VaultTypeUnrecognized(self.vType);
        }
    }

    /// Query the most tokens that can actually be withdrawn.
    /// @dev This is the only one that makes a direct call to the vault,
    /// so be careful it returns a value that does not account for any pending deposits.
    function withdrawable(
        VaultPointer memory self
    ) internal view returns (uint256 _withdrawable) {
        if (isNull(self)) return 0;

        if (self.vType == VaultType.E4626) {
            return getE4626(self).withdrawable();
        } else {
            revert VaultTypeUnrecognized(self.vType);
        }
    }

    /// Query the balance available to the given cid.
    function balance(
        VaultPointer memory self,
        ClosureId cid,
        bool roundUp
    ) internal view returns (uint128 amount) {
        if (isNull(self)) return 0;

        if (self.vType == VaultType.E4626) {
            return getE4626(self).balance(self.temp, cid, roundUp);
        } else {
            revert VaultTypeUnrecognized(self.vType);
        }
    }

    /// Query the total balance of all the given cids.
    function totalBalance(
        VaultPointer memory self,
        ClosureId[] storage cids,
        bool roundUp
    ) internal view returns (uint128 amount) {
        if (isNull(self)) return 0;

        if (self.vType == VaultType.E4626) {
            return getE4626(self).totalBalance(self.temp, cids, roundUp);
        } else {
            revert VaultTypeUnrecognized(self.vType);
        }
    }

    /// Query the total balance of everything.
    function totalBalance(
        VaultPointer memory self,
        bool roundUp
    ) internal view returns (uint256 amount) {
        if (isNull(self)) return 0;

        if (self.vType == VaultType.E4626) {
            return getE4626(self).totalBalance(self.temp, roundUp);
        } else {
            revert VaultTypeUnrecognized(self.vType);
        }
    }

    /// Because vaults batch operations together, they do one final operation
    /// as needed during the commit step.
    function commit(VaultPointer memory self) internal {
        if (isNull(self)) return;

        if (self.vType == VaultType.E4626) {
            getE4626(self).commit(self.temp);
        } else {
            revert VaultTypeUnrecognized(self.vType);
        }
    }

    /// A convenience function that forces a commit and re-fetches from the underlying vault.
    function refresh(VaultPointer memory self) internal {
        if (isNull(self)) return;

        if (self.vType == VaultType.E4626) {
            VaultE4626 storage v = getE4626(self);
            v.commit(self.temp);
            clearTemp(self);
            v.fetch(self.temp);
        }
    }

    /* helpers */

    function getE4626(
        VaultPointer memory self
    ) private pure returns (VaultE4626 storage proxy) {
        assembly {
            proxy.slot := mload(self)
        }
    }

    function clearTemp(VaultPointer memory self) private pure {
        for (uint256 i = 0; i < NUM_VAULT_VARS; ++i) {
            self.temp.vars[i] = 0;
        }
    }

    function isNull(VaultPointer memory self) private pure returns (bool) {
        return self.slotAddress == bytes32(0);
    }
}
