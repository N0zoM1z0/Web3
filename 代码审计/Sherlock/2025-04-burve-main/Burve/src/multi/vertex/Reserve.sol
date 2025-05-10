// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {MAX_TOKENS} from "./../Constants.sol";
import {VertexId} from "./Id.sol";
import {VaultProxy} from "./VaultProxy.sol";
import {VaultLib} from "./VaultProxy.sol";
import {ClosureId} from "../closure/Id.sol";
import {Store} from "../Store.sol";

struct Reserve {
    // The shares we have for the balance we have in each vault.
    uint256[MAX_TOKENS] shares;
}

library ReserveLib {
    ClosureId public constant RESERVEID = ClosureId.wrap(0);
    uint8 public constant SHARE_RESOLUTION = 100;

    /// Deposit into the reserve and get shares.
    /// @dev We round shares down.
    function deposit(
        VertexId vid,
        uint256 amount
    ) internal returns (uint256 shares) {
        VaultProxy memory vProxy = VaultLib.getProxy(vid);
        shares = deposit(vProxy, vid, amount);
        vProxy.commit();
    }

    /// Deposit into the reserve for shares with an existing VaultProxy
    function deposit(
        VaultProxy memory vProxy,
        VertexId vid,
        uint256 amount
    ) internal returns (uint256 shares) {
        Reserve storage reserve = Store.reserve();
        uint8 idx = vid.idx();
        uint128 balance = vProxy.balance(RESERVEID, true);
        vProxy.deposit(RESERVEID, amount);
        // If someone tries to share inflate attack this, they'd have to donate to the underlying vault,
        // which then splits the donation across existing deposits from other people using the vault,
        // including the other closures. So there's no way to inflate shares here.
        shares = (balance == 0)
            ? amount * SHARE_RESOLUTION
            : (amount * reserve.shares[idx]) / balance; // No need for mulDiv.
        reserve.shares[idx] += shares;
    }

    /// Query the value of the shares held in the base token in this reserve.
    /// @dev We round down the redeemed value for safety reasons.
    function query(
        VertexId vid,
        uint256 shares
    ) internal view returns (uint256 amount) {
        Reserve storage reserve = Store.reserve();
        uint8 idx = vid.idx();
        if (reserve.shares[idx] == 0) return 0; // avoid div by ZERO.
        VaultProxy memory vProxy = VaultLib.getProxy(vid);
        uint128 balance = vProxy.balance(RESERVEID, true);
        amount = (shares * balance) / reserve.shares[idx];
    }

    /// Withdraw the redemption value of the given shares to this contract from the vault.
    /// @dev We round down the redeemed value for safety reasons.
    function withdraw(
        VertexId vid,
        uint256 shares
    ) internal returns (uint256 amount) {
        Reserve storage reserve = Store.reserve();
        uint8 idx = vid.idx();
        if (reserve.shares[idx] == 0) return 0;
        VaultProxy memory vProxy = VaultLib.getProxy(vid);
        uint128 balance = vProxy.balance(RESERVEID, true);
        amount = (shares * balance) / reserve.shares[idx];
        vProxy.withdraw(RESERVEID, amount);
        vProxy.commit(); // <=== what if the commit fails?  revert
        reserve.shares[idx] -= shares; // <=== still no explicit check for underflow.
    }
}
