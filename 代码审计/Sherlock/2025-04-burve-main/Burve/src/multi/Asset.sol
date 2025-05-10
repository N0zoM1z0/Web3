// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ClosureId} from "./closure/Id.sol";
import {Store} from "./Store.sol";
import {FullMath} from "../FullMath.sol";
import {MAX_TOKENS} from "./Constants.sol";

/*
    Users can have value balances in each cid, but those values are deposited into
    Assets so that they can earn fees.
    Each CID can only have one asset and so when adding/removing/extracting/redeeming value
    users have to specify which CID.
 */

struct Asset {
    uint256 value;
    uint256 bgtValue; // Value - bgtValue is the non-bgt value.
    // Checkpoints from our Closure.
    uint256[MAX_TOKENS] earningsPerValueX128Check;
    uint256[MAX_TOKENS] unexchangedPerBgtValueX128Check;
    uint256 bgtPerValueX128Check;
    // When we modify value, we need to collect fees but we don't automatically withdraw them.
    // Instead they reside here until the user actually wants to collect fees earned.
    uint256[MAX_TOKENS] collectedBalances; // Again, these are shares in the reserve.
    uint256 bgtBalance;
}

struct AssetBook {
    mapping(address => mapping(ClosureId => Asset)) assets;
}

using AssetBookImpl for AssetBook global;

library AssetBookImpl {
    error InsufficientValue(uint256 actual, uint256 required);
    error InsufficientBgtValue(uint256 actual, uint256 required);
    /// Thrown when trying to remove too much value and not enough bgtValue.
    error InsufficientNonBgtValue(uint256 value, uint256 bgtValue);

    /// Add value to a cid. If the cid already has value, the fees earned will be collected!
    function add(
        AssetBook storage self,
        address recipient,
        ClosureId cid,
        uint256 value,
        uint256 bgtValue
    ) internal {
        collect(self, recipient, cid);
        Asset storage a = self.assets[recipient][cid];
        require(value >= bgtValue, InsufficientValue(value, bgtValue));
        a.value += value;
        a.bgtValue += bgtValue;
    }

    /// Query the value held by a user in a given cid and the fees acccrued so far.
    function query(
        AssetBook storage self,
        address recipient,
        ClosureId cid
    )
        internal
        view
        returns (
            uint256 value,
            uint256 bgtValue,
            uint256[MAX_TOKENS] memory feeBalances,
            uint256 bgtBalance
        )
    {
        Asset storage a = self.assets[recipient][cid];
        value = a.value;
        bgtValue = a.bgtValue;
        /* Get total fee balances */
        (
            uint256[MAX_TOKENS] storage epvX128,
            uint256 bpvX128,
            uint256[MAX_TOKENS] storage unepbvX128
        ) = Store.closure(cid).getCheck();

        uint256 nonBgtValue = a.value - a.bgtValue;
        for (uint8 i = 0; i < MAX_TOKENS; ++i) {
            // Fees
            feeBalances[i] =
                a.collectedBalances[i] +
                FullMath.mulX128(
                    (epvX128[i] - a.earningsPerValueX128Check[i]),
                    nonBgtValue,
                    false
                ) +
                FullMath.mulX128(
                    (unepbvX128[i] - a.unexchangedPerBgtValueX128Check[i]),
                    a.bgtValue,
                    false
                );
        }
        bgtBalance =
            a.bgtBalance +
            FullMath.mulX128(
                bpvX128 - a.bgtPerValueX128Check,
                a.bgtValue,
                false
            );
    }

    /// Remove value from this cid.
    function remove(
        AssetBook storage self,
        address owner,
        ClosureId cid,
        uint256 value, // Total
        uint256 bgtValue // BGT specific
    ) internal {
        collect(self, owner, cid);
        Asset storage a = self.assets[owner][cid];
        require(value >= bgtValue, InsufficientValue(value, bgtValue));
        require(value <= a.value, InsufficientValue(a.value, value));
        require(
            bgtValue <= a.bgtValue,
            InsufficientBgtValue(a.bgtValue, bgtValue)
        );
        unchecked {
            a.value -= value;
            a.bgtValue -= bgtValue;
        }
        require(
            a.value >= a.bgtValue,
            InsufficientNonBgtValue(a.value, a.bgtValue)
        );
    }

    /// Push all the currently earned fees into the collected balances and update checkpoints.
    /// @dev We basically always collect fees first whenever we interact with an asset.
    function collect(
        AssetBook storage self,
        address recipient,
        ClosureId cid
    ) internal {
        (
            uint256[MAX_TOKENS] storage epvX128,
            uint256 bpvX128,
            uint256[MAX_TOKENS] storage unepbvX128
        ) = Store.closure(cid).getCheck();
        Asset storage a = self.assets[recipient][cid];
        uint256 nonBgtValue = a.value - a.bgtValue;
        for (uint8 i = 0; i < MAX_TOKENS; ++i) {
            // Fees
            a.collectedBalances[i] +=
                FullMath.mulX128(
                    (epvX128[i] - a.earningsPerValueX128Check[i]),
                    nonBgtValue,
                    false
                ) +
                FullMath.mulX128(
                    (unepbvX128[i] - a.unexchangedPerBgtValueX128Check[i]),
                    a.bgtValue,
                    false
                );
            a.earningsPerValueX128Check[i] = epvX128[i];
            a.unexchangedPerBgtValueX128Check[i] = unepbvX128[i];
        }
        a.bgtBalance += FullMath.mulX128(
            bpvX128 - a.bgtPerValueX128Check,
            a.bgtValue,
            false
        );
        a.bgtPerValueX128Check = bpvX128;
    }

    /// Does not collect any fees earned, but simply returns the fee balances collected (as shares in reserve)
    /// and resets the current collected balances to 0.
    /// @dev Used by facets to collect fees earned. These amounts should be withdraw from the reserve.
    function claimFees(
        AssetBook storage self,
        address recipient,
        ClosureId cid
    )
        internal
        returns (uint256[MAX_TOKENS] memory feeBalances, uint256 bgtBalance)
    {
        collect(self, recipient, cid);
        Asset storage a = self.assets[recipient][cid];
        for (uint8 i = 0; i < MAX_TOKENS; ++i) {
            feeBalances[i] = a.collectedBalances[i];
            a.collectedBalances[i] = 0;
        }
        bgtBalance = a.bgtBalance;
        a.bgtBalance = 0;
    }
}
