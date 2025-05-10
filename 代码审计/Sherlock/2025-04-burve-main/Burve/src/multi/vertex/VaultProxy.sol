// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {VertexId} from "./Id.sol";
import {VaultPointer, VaultType} from "./VaultPointer.sol";
import {VaultE4626} from "./E4626.sol";
import {Store} from "../Store.sol";
import {ClosureId} from "../closure/Id.sol";

// Holds overall vault information.
struct VaultStorage {
    // Vaults in use.
    mapping(VertexId => address vault) vaults;
    // Vaults we're potentially transfering into.
    mapping(VertexId => address vault) backups;
    // Vault info.
    mapping(address vault => VaultType) vTypes;
    mapping(address vault => VaultE4626) e4626s;
    mapping(address vault => VertexId) usedBy;
}

/// Each vertex has a primary vault and a backup vault it may be migrating to.
/// The combination of the two is a VaultProxy.
/// Fetching a VaultProxy and operating on the Vault Storage is done through VaultLib.
library VaultLib {
    // If we have fewer than this many tokens left in a vault, we can remove it.
    uint256 public constant BALANCE_DE_MINIMUS = 10;

    // Thrown when a vault has already been added before.
    error VaultExists(address);
    // Thrown when removing a vault that still holds a substantive balance.
    error RemainingVaultBalance(uint256);
    // This vault type is not currently supported.
    error VaultTypeNotRecognized(VaultType);
    // Thrown during a get if the vault can't be found.
    error VaultNotFound(address);
    // Thrown when there is already a primary and a backup vault.
    error VertexVaultsOccupied(VertexId);
    // Thrown when removing a vault that is still in use.
    error VaultInUse(address, VertexId);
    // Thrown when deleting or swapping a vault but there is no backup for the vertex.
    error NoBackup(VertexId);

    /// Add a vault for a vertex. There needs to at least be one per vertex.
    /// Adds as the primary vault if one does not exist yet, then the backup vault.
    function add(
        VertexId vid,
        address token,
        address vault,
        VaultType vType
    ) internal {
        VaultStorage storage vStore = Store.vaults();
        // First add to vault tracking.
        if (vStore.vaults[vid] == address(0)) {
            // Add as the primary vault
            vStore.vaults[vid] = vault;
        } else if (vStore.backups[vid] == address(0)) {
            // Add as a backup.
            vStore.backups[vid] = vault;
        } else {
            revert VertexVaultsOccupied(vid);
        }

        // Now add vault details.
        if (vStore.vTypes[vault] != VaultType.UnImplemented)
            revert VaultExists(vault);
        vStore.vTypes[vault] = vType;
        if (vType == VaultType.E4626) vStore.e4626s[vault].init(token, vault);
        else revert VaultTypeNotRecognized(vType);
        vStore.usedBy[vault] = vid;
    }

    function remove(address vault) internal {
        VaultPointer memory vPtr = getVault(vault);
        uint256 outstanding = vPtr.totalBalance(false);
        if (outstanding > BALANCE_DE_MINIMUS)
            revert RemainingVaultBalance(outstanding);

        VaultStorage storage vStore = Store.vaults();
        VertexId vid = vStore.usedBy[vault];
        if (vStore.vaults[vid] == vault) revert VaultInUse(vault, vid);

        // We are not the active vault, so we're the backup and we have no tokens. Okay to remove.
        delete vStore.backups[vid];

        VaultType vType = vStore.vTypes[vault];
        delete vStore.vTypes[vault];
        // Vault specific operation.
        if (vType == VaultType.E4626) vStore.e4626s[vault].del();
        else revert VaultTypeNotRecognized(vType);
        // VertexId delete.
        vStore.usedBy[vault] = VertexId.wrap(0);
    }

    /// Move an amount of tokens from one vault to another.
    /// @dev This implicitly requires that the two vaults are based on the same token
    /// and there can only be two vaults for a given token.
    function transfer(
        address fromVault,
        address toVault,
        ClosureId cid,
        uint256 amount
    ) internal {
        VaultPointer memory from = getVault(fromVault);
        from.withdraw(cid, amount);
        from.commit();
        VaultPointer memory to = getVault(toVault);
        to.deposit(cid, amount);
        to.commit();
    }

    /// Swap the active vault we deposit into.
    function hotSwap(
        VertexId vid
    ) internal returns (address fromVault, address toVault) {
        VaultStorage storage vStore = Store.vaults();
        // If there is no backup, then we can't do this.
        if (vStore.backups[vid] == address(0)) revert NoBackup(vid);
        // Swap.
        address active = vStore.vaults[vid];
        address backup = vStore.backups[vid];
        vStore.vaults[vid] = backup;
        vStore.backups[vid] = active;
        return (active, backup);
    }

    /* Getters */

    /// Get the active and backup addresses for a vault.
    function getVaultAddresses(
        VertexId vid
    ) internal view returns (address active, address backup) {
        VaultStorage storage vStore = Store.vaults();
        active = vStore.vaults[vid];
        backup = vStore.backups[vid];
    }

    /// Fetch a VaultProxy for the vertex's active vaults.
    function getProxy(
        VertexId vid
    ) internal view returns (VaultProxy memory vProxy) {
        VaultStorage storage vStore = Store.vaults();
        vProxy.active = getVault(vStore.vaults[vid]);
        address backup = vStore.backups[vid];
        if (backup != address(0)) vProxy.backup = getVault(backup);
    }

    /// Fetch a Vault
    function getVault(
        address vault
    ) internal view returns (VaultPointer memory vPtr) {
        VaultStorage storage vStore = Store.vaults();
        vPtr.vType = vStore.vTypes[vault];
        if (vPtr.vType == VaultType.E4626) {
            VaultE4626 storage v = vStore.e4626s[vault];
            assembly {
                mstore(vPtr, v.slot) // slotAddress is the first field.
            }
            v.fetch(vPtr.temp);
        } else {
            revert VaultNotFound(vault);
        }
    }
}

// An in-memory struct used by vertices to interact with vaults.
struct VaultProxy {
    VaultPointer active;
    VaultPointer backup;
}

using VaultProxyImpl for VaultProxy global;

library VaultProxyImpl {
    error VaultTypeUnrecognized(VaultType);

    /// We simply deposit into the active vault pointer.
    function deposit(
        VaultProxy memory self,
        ClosureId cid,
        uint256 amount
    ) internal {
        self.active.deposit(cid, amount);
    }

    /// Withdraw from the active vault, and then the backup if we can't fulfill it entirely.
    function withdraw(
        VaultProxy memory self,
        ClosureId cid,
        uint256 amount
    ) internal {
        // We effectively don't allow withdraws beyond uint128 due to the capping in balance.
        uint128 available = self.active.balance(cid, false);
        uint256 maxWithdrawable = self.active.withdrawable();
        if (maxWithdrawable < available) available = uint128(maxWithdrawable);

        if (amount > available) {
            self.active.withdraw(cid, available);
            self.backup.withdraw(cid, amount - available); // 这里没有check够不够啊
        } else {
            self.active.withdraw(cid, amount);
        }
    }

    /// How much can we withdraw from the vaults right now?
    function withdrawable(
        VaultProxy memory self
    ) internal view returns (uint256 _withdrawable) {
        return self.active.withdrawable() + self.backup.withdrawable();
    }

    /// Query the balance available to the given cid.
    function balance(
        VaultProxy memory self,
        ClosureId cid,
        bool roundUp
    ) internal view returns (uint128 amount) {
        return
            self.active.balance(cid, roundUp) +
            self.backup.balance(cid, roundUp);
    }

    /// Query the total balance of all the given cids.
    function totalBalance(
        VaultProxy memory self,
        ClosureId[] storage cids,
        bool roundUp
    ) internal view returns (uint128 amount) {
        return
            self.active.totalBalance(cids, roundUp) +
            self.backup.totalBalance(cids, roundUp);
    }

    /// Query the total balance of everything.
    function totalBalance(
        VaultProxy memory self,
        bool roundUp
    ) internal view returns (uint256 amount) {
        return
            self.active.totalBalance(roundUp) +
            self.backup.totalBalance(roundUp);
    }

    /// Because vaults batch operations together, they do one final operation
    /// as needed during the commit step.
    function commit(VaultProxy memory self) internal {
        self.active.commit();
        self.backup.commit();
    }

    /// A convenience function that forces a commit and re-fetches from the underlying vault.
    function refresh(VaultProxy memory self) internal {
        self.active.refresh();
        self.backup.refresh();
    }
}
