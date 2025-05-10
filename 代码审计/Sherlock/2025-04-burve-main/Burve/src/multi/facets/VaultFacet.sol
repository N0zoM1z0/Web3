// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {VertexLib, VertexId} from "../vertex/Id.sol";
import {VaultLib, VaultType} from "../vertex/VaultProxy.sol";
import {ClosureId} from "../closure/Id.sol";
import {AdminLib} from "Commons/Util/Admin.sol";
import {Timed} from "../../Timed.sol";

/// Admin-related functions for interacting with the install Vaults. Primarily for migrations.
/// @dev In the future we can upgrade this with a more rich set of rights to decentralize
/// to multiple parties for vetoing migrations.
contract VaultFacet {
    /// We add a delay from when a new vault is added so users can withdraw positions if they dislike the vault.
    /// This acts as a safeguard against potentially malicious vaults. With locking, this keeps Burve safe from rugs.
    /// 5 days was chosen as a reasonable time to broadcast to all our users and give them sufficient time to decide.
    uint32 public constant ADD_DELAY = 5 days;

    event VaultInstalled(address token, address vault);
    event VaultMigrated(address token, address fromVault, address toVault);
    event VaultVetoed(address token);

    /// Query which vaults are in use for a token.
    function viewVaults(
        address token
    ) external view returns (address active, address backup) {
        VertexId vid = VertexLib.newId(token);
        (active, backup) = VaultLib.getVaultAddresses(vid);
    }

    /// Add a backup vault for a token.
    function addVault(address token, address vault, VaultType vType) external {
        AdminLib.validateOwner();
        // This validates the token is installed.
        VertexLib.newId(token);
        bytes memory entry = abi.encode(vault, vType);
        Timed.memoryPrecommit(uint160(token), entry);
        // Timed will issue a precommit event.
    }

    /// Actually adds a new vault that was previously precommitted.
    function acceptVault(address token) external {
        AdminLib.validateOwner();
        bytes memory entry = Timed.fetchPrecommit(uint160(token), ADD_DELAY);
        (address vault, VaultType vType) = abi.decode(
            entry,
            (address, VaultType)
        );
        VertexId vid = VertexLib.newId(token);
        VaultLib.add(vid, token, vault, vType);
        emit VaultInstalled(token, vault);
    }

    /// Reject a vault migration.
    /// @dev This can be done before the delay so EVEN IF the owner key is compromised, an attacker
    /// can't migrate to a malicious vault. SAFETY FIRST. But of course, keep your key safe!
    /// Hardware wallets + multi-sigs plz and ty.
    function vetoVault(address token) external {
        AdminLib.validateOwner();
        Timed.deleteEntry(uint160(token));
        emit VaultVetoed(token);
    }

    /// Remove an active or backup vault as long as it is empty.
    function removeVault(address vault) external {
        AdminLib.validateOwner();
        VaultLib.remove(vault);
    }

    /// Withdraw from one vault and move it to another.
    /// This lets us progressively migrate one vault to another over time.
    function transferBalance(
        address fromVault,
        address toVault,
        uint16 cid,
        uint256 amount
    ) external {
        AdminLib.validateOwner();
        VaultLib.transfer(fromVault, toVault, ClosureId.wrap(cid), amount);
    }

    /// Swap the vault that new deposits go into from the active vault to the backup.
    /// @dev For most vaults we can hot swap immediately because we will still remove from the backup vault.
    /// However, for vaults with a minimum deposit duration, we will first transfer for a that period before swapping.
    function hotSwap(address token) external {
        AdminLib.validateOwner();
        // Validates the token.
        VertexId vid = VertexLib.newId(token);
        (address fromVault, address toVault) = VaultLib.hotSwap(vid);
        emit VaultMigrated(token, fromVault, toVault);
    }
}
