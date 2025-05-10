// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {MAX_TOKENS} from "./../Constants.sol";
import {SimplexLib} from "../Simplex.sol";
import {VertexId, VertexLib} from "../vertex/Id.sol";
import {AdjustorLib} from "../Adjustor.sol";
import {ClosureId} from "./Id.sol";
import {FullMath} from "../../FullMath.sol";
import {ValueLib, SearchParams} from "../Value.sol";
import {ReserveLib} from "../vertex/Reserve.sol";
import {Store} from "../Store.sol";
import {UnsafeMath} from "Commons/Math/UnsafeMath.sol";

/// Holds the information relevant to a single closure
/// @dev NOTE Closures operate in nominal terms. Be sure to converted before interacting.
/// @dev It does convert to real when interacting with Vertex in trimming though.
struct Closure {
    ClosureId cid; // Indicates our token set.
    uint8 n; // number of tokens in this closure
    /* Edge info */
    uint256 targetX128; // targetValue of a single token. n * target is the total value.
    uint256 baseFeeX128; // Fees charge per swap for this closure.
    /* Earnings info */
    uint256 protocolTakeX128; // Protocol's rev share of fees earned.
    /* Current asset holdings */
    uint256[MAX_TOKENS] balances; // The balances we need for swapping in this closure.
    uint256 valueStaked; // The total amount of value tokens currently earning in this closure. <= n * target.
    uint256 bgtValueStaked; // Amount of value tokens directing earnings to BGT.
    /* Earnings for the two types of value */
    // NOTE These earnings are in share value within the reserve pool, so they can continue to compound and grow.
    uint256[MAX_TOKENS] earningsPerValueX128; // The earnings checkpoint for a single non-bgt value token.
    uint256 bgtPerBgtValueX128; // BGT earnings checkpoint for bgt value tokens.
    uint256[MAX_TOKENS] unexchangedPerBgtValueX128; // Backup for when exchanges are unavailable.
}

/// In-memory helper struct for saving stack space when iterating when modifying value from a single token.
struct SingleValueIter {
    uint256 scaleX128;
    uint8 vIdx;
    uint256 valueSumX128;
}

using ClosureImpl for Closure global;

library ClosureImpl {
    uint256 public constant ONEX128 = 1 << 128;
    // We set a hard limit on the token balance which keeps etX128 in value within 256 bits.
    // This is a little less than 80 Billion * 10e18.
    uint256 public constant HARD_BALANCE_CAP = 1 << 96;
    event WarningExcessValueDetected(
        ClosureId cid,
        uint256 maxValue,
        uint256 actualValue
    );
    error InsufficientStakeCapacity(
        ClosureId cid,
        uint256 maxValue,
        uint256 actualValue,
        uint256 attemptedStake
    );
    error InsufficientUnstakeAvailable(
        ClosureId cid,
        uint256 stakeValue,
        uint256 attemptedUnstake
    );
    error IrrelevantVertex(ClosureId cid, VertexId vid);
    /// Token balances have to stay between 0 and double the target value.
    error TokenBalanceOutOfBounds(
        ClosureId cid,
        uint8 idx,
        uint256 attemptedBalance,
        uint256 minBalance,
        uint256 maxBalance
    );
    /// Thrown when trying to unstake from a closure with a locked token.
    error CannotRemoveWithLockedVertex(ClosureId cid);

    /// Initialize a closure and add a small balance of each token to get it started. This balance is burned.
    function init(
        Closure storage self,
        ClosureId cid,
        uint256 target,
        uint256 baseFeeX128,
        uint256 protocolTakeX128
    ) internal returns (uint256[MAX_TOKENS] storage balancesNeeded) {
        self.cid = cid;
        self.targetX128 = target << 128;
        self.baseFeeX128 = baseFeeX128;
        self.protocolTakeX128 = protocolTakeX128;
        for (
            VertexId vIter = VertexLib.minId();
            !vIter.isStop();
            vIter = vIter.inc()
        ) {
            if (cid.contains(vIter)) {
                self.n += 1;
                // We don't need to check this assignment.
                self.balances[vIter.idx()] += target;
            }
        }
        require(self.n != 0, "InitEmptyClosure");
        // Tiny burned value.
        self.valueStaked += target * self.n;
        return self.balances;
    }

    /// Add value to a closure by adding to every token in the closure.
    /// @dev Value added must fit in 128 bits (which every sensible balance will).
    /// @return requiredBalances The amount of each token (in nominal terms) that we need to
    function addValue(
        Closure storage self,
        uint256 value,
        uint256 bgtValue
    ) internal returns (uint256[MAX_TOKENS] memory requiredBalances) {
        trimAllBalances(self);
        // Round up so they add dust.
        uint256 scaleX128 = FullMath.mulDivX256(
            value,
            self.n * self.targetX128,
            true
        );
        uint256 valueX128 = value << 128;
        // Technically, by rounding up there will be a higher target value than actual value in the pool.
        // This is not an issue as it causes redeems to be less by dust and swaps to be more expensive by dust.
        // Plus this will be fixed when someone adds/removes value with an exact token amount.
        self.targetX128 +=
            valueX128 /
            self.n +
            ((valueX128 % self.n) > 0 ? 1 : 0);
        self.valueStaked += value;
        self.bgtValueStaked += bgtValue;
        // Value is handled. Now handle balances.
        for (uint8 i = 0; i < MAX_TOKENS; ++i) {
            if (!self.cid.contains(i)) continue;
            requiredBalances[i] = FullMath.mulX128(
                scaleX128,
                self.balances[i],
                true
            );
            // This happens after because the vault will have
            self.setBalance(i, self.balances[i] + requiredBalances[i]);
        }
    }

    /// Add value to a closure by adding to a single token in the closure.
    function addValueSingle(
        Closure storage self,
        uint256 value,
        uint256 bgtValue,
        VertexId vid
    ) internal returns (uint256 requiredAmount, uint256 tax) {
        require(self.cid.contains(vid), IrrelevantVertex(self.cid, vid));
        // We still need to trim all balances here because value is changing.
        trimAllBalances(self);
        // Compute scale before modifying our target.
        uint256 scaleX128 = FullMath.mulDivX256(
            value,
            self.n * self.targetX128,
            true
        ) + ONEX128;
        {
            uint256 valueX128 = value << 128;
            self.targetX128 +=
                valueX128 /
                self.n +
                ((valueX128 % self.n) > 0 ? 1 : 0);
        }
        SingleValueIter memory valIter = SingleValueIter({
            scaleX128: scaleX128,
            vIdx: vid.idx(),
            valueSumX128: 0
        });

        // We first calculate what value is effectively "lost" by not adding the tokens.
        // And then we make sure to add that amount of value to the deposit token.
        uint256 fairVBalance = iterSingleValueDiff(self, valIter, true);
        requiredAmount = fairVBalance - self.balances[valIter.vIdx];
        // Now we have the missing value and the currently fair balance for our vertex.
        uint256 finalAmount;
        {
            uint256 veX128 = SimplexLib.getEX128(valIter.vIdx);
            uint256 currentValueX128 = ValueLib.v(
                self.targetX128,
                veX128,
                fairVBalance,
                false
            );
            // To get the required amount.
            finalAmount = ValueLib.x(
                self.targetX128,
                veX128,
                currentValueX128 + valIter.valueSumX128,
                true
            );
        }
        {
            uint256 untaxedRequired = finalAmount - fairVBalance;
            self.setBalance(valIter.vIdx, finalAmount);
            uint256 taxedRequired = UnsafeMath.divRoundingUp(
                untaxedRequired << 128,
                ONEX128 - self.baseFeeX128
            );
            tax = taxedRequired - untaxedRequired;
            requiredAmount += taxedRequired;
        }
        // This needs to happen after any fee earnings.
        self.valueStaked += value;
        self.bgtValueStaked += bgtValue;
    }

    /// Remove value from a closure by removing from every token in the closure.
    /// Note that fee claiming is separate and should be done on the asset. This merely changes the closure.
    /// @dev Value removed must fit in 128 bits (which every sensible balance will).
    /// @return withdrawnBalances The amount of each token (in nominal terms) that the remove takes out of the pool
    function removeValue(
        Closure storage self,
        uint256 value,
        uint256 bgtValue
    ) internal returns (uint256[MAX_TOKENS] memory withdrawnBalances) {
        trimAllBalances(self);
        // Round down to leave dust.
        uint256 scaleX128 = FullMath.mulDivX256(
            value,
            self.n * self.targetX128,
            false
        );
        uint256 valueX128 = value << 128;
        // We round down here to like addValue we keep more target value in the pool.
        self.targetX128 -= valueX128 / self.n;
        self.valueStaked -= value;
        self.bgtValueStaked -= bgtValue;
        // Value is handled. Now handle balances.
        for (uint8 i = 0; i < MAX_TOKENS; ++i) {
            if (!self.cid.contains(i)) continue;
            withdrawnBalances[i] = FullMath.mulX128(
                scaleX128,
                self.balances[i],
                false
            );
            self.setBalance(i, self.balances[i] - withdrawnBalances[i]);
        }
    }

    /// Remove value from a closure through a single token.
    function removeValueSingle(
        Closure storage self,
        uint256 value,
        uint256 bgtValue,
        VertexId vid
    ) internal returns (uint256 removedAmount, uint256 tax) {
        require(!isAnyLocked(self), CannotRemoveWithLockedVertex(self.cid));
        require(self.cid.contains(vid), IrrelevantVertex(self.cid, vid));
        trimAllBalances(self);
        uint256 scaleX128 = ONEX128 -
            FullMath.mulDivX256(value, self.n * self.targetX128, true);
        {
            uint256 valueX128 = value << 128;
            // Round leftover value up.
            self.targetX128 -= valueX128 / self.n;
        }
        SingleValueIter memory valIter = SingleValueIter({
            scaleX128: scaleX128,
            vIdx: vid.idx(),
            valueSumX128: 0
        });
        // We first calculate what value is effectively "added" by not removing the tokens.
        // And then we make sure to remove that amount of value with the out token.
        uint256 fairVBalance = iterSingleValueDiff(self, valIter, false);
        removedAmount = self.balances[valIter.vIdx] - fairVBalance;
        // Now we have the addedValue which we can remove, and the fair balance for our vertex.
        uint256 veX128 = SimplexLib.getEX128(valIter.vIdx);
        uint256 currentValueX128 = ValueLib.v(
            self.targetX128,
            veX128,
            fairVBalance,
            false
        );
        uint256 finalAmount = ValueLib.x(
            self.targetX128,
            veX128,
            currentValueX128 - valIter.valueSumX128,
            true
        );
        uint256 untaxedRemove = fairVBalance - finalAmount;
        self.setBalance(valIter.vIdx, finalAmount);
        tax = FullMath.mulX128(untaxedRemove, self.baseFeeX128, true);
        removedAmount += untaxedRemove - tax; // fee is already subtracted here.
        // This needs to happen last.
        self.valueStaked -= value;
        self.bgtValueStaked -= bgtValue;
    }

    /// Add an exact amount of one token and receive value in return.
    function addTokenForValue(
        Closure storage self,
        VertexId vid,
        uint256 amount,
        uint256 bgtPercentX256,
        SearchParams memory searchParams
    ) internal returns (uint256 value, uint256 bgtValue, uint256 tax) {
        require(self.cid.contains(vid), IrrelevantVertex(self.cid, vid));
        trimAllBalances(self);
        uint8 idx = vid.idx();
        // For simplicity, we tax the entire amount in first. This overcharges slightly but an exact solution
        // would overcomplicate the contract and any approximation is game-able.
        tax = FullMath.mulX128(amount, self.baseFeeX128, true);
        amount -= tax;
        // Use the ValueLib's newton's method to solve for the value added and update target.
        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        // This is tricky. We up the balance first for the ValueLib call, then set to do the checks.
        // We need to set the new target before we can setBalance, but we need up to balance to calc new target.
        self.balances[idx] += amount;
        uint256 newTargetX128;
        {
            (uint256[] memory mesX128, uint256[] memory mxs) = ValueLib
                .stripArrays(self.n, esX128, self.balances);
            newTargetX128 = ValueLib.t(
                searchParams,
                mesX128,
                mxs,
                self.targetX128
            );
        }
        // The pool is now entirely correct by just updating the target and value balances.
        value = ((newTargetX128 - self.targetX128) * self.n) >> 128; // Round down received value balance.
        bgtValue = FullMath.mulX256(value, bgtPercentX256, false); // Convention to round BGT down.
        self.targetX128 = newTargetX128;
        // Now that we set the new target we can set balance to check validity.
        self.setBalance(idx, self.balances[idx]);
        self.valueStaked += value;
        self.bgtValueStaked += bgtValue;
    }

    /// Remove an exact amount of one token and pay the requisite value.
    function removeTokenForValue(
        Closure storage self,
        VertexId vid,
        uint256 amount,
        uint256 bgtPercentX256,
        SearchParams memory searchParams
    ) internal returns (uint256 value, uint256 bgtValue, uint256 tax) {
        require(!isAnyLocked(self), CannotRemoveWithLockedVertex(self.cid));
        require(self.cid.contains(vid), IrrelevantVertex(self.cid, vid));
        trimAllBalances(self);
        uint8 idx = vid.idx();
        // We tax first so the amount which moves up the value they're paying.
        uint256 taxedRemove = UnsafeMath.divRoundingUp(
            amount << 128,
            ONEX128 - self.baseFeeX128
        );
        tax = taxedRemove - amount;
        // Use the ValueLib's newton's method to solve for the value removed and update target.
        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        // This is tricky and strange, but see addTokenForValue for reason.
        self.balances[idx] -= taxedRemove;
        uint256 newTargetX128;
        {
            (uint256[] memory mesX128, uint256[] memory mxs) = ValueLib
                .stripArrays(self.n, esX128, self.balances);
            newTargetX128 = ValueLib.t(
                searchParams,
                mesX128,
                mxs,
                self.targetX128 // TODO: Add better starting estimate logic
            );
        }
        // The pool is now entirely correct by just updating the target and value balances.
        uint256 valueX128 = ((self.targetX128 - newTargetX128) * self.n);
        value = valueX128 >> 128;
        if ((value << 128) > 0) value += 1; // We need to round up.
        bgtValue = FullMath.mulX256(value, bgtPercentX256, false); // Convention to round BGT down both ways.
        self.targetX128 = newTargetX128;
        self.setBalance(idx, self.balances[idx]);
        self.valueStaked -= value;
        self.bgtValueStaked -= bgtValue;
    }

    /// Swap in with an exact amount of one token for another.
    /// Convention is to always take fees from the in token.
    function swapInExact(
        Closure storage self,
        VertexId inVid,
        VertexId outVid,
        uint256 inAmount
    )
        internal
        returns (uint256 outAmount, uint256 tax, uint256 valueExchangedX128)
    {
        require(self.cid.contains(inVid), IrrelevantVertex(self.cid, inVid));
        require(self.cid.contains(outVid), IrrelevantVertex(self.cid, outVid));
        trimBalance(self, inVid);
        trimBalance(self, outVid);
        // The value in this pool won't change.
        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        // First tax the in token.
        uint8 inIdx = inVid.idx();
        tax = FullMath.mulX128(inAmount, self.baseFeeX128, true);
        inAmount -= tax;
        // Calculate the value added by the in token.
        valueExchangedX128 =
            ValueLib.v(
                self.targetX128,
                esX128[inIdx],
                self.balances[inIdx] + inAmount,
                false
            ) -
            ValueLib.v(
                self.targetX128,
                esX128[inIdx],
                self.balances[inIdx],
                true
            );
        self.setBalance(inIdx, self.balances[inIdx] + inAmount);
        uint8 outIdx = outVid.idx();
        // To round down the out amount, we want to remove value at lower values on the curve.
        // But we want to round up the newOutBalance which means we want a higher newOutValue.
        // Ultimately these are both valid and both negligible, so it doesn't matter.
        uint256 currentOutValueX128 = ValueLib.v(
            self.targetX128,
            esX128[outIdx],
            self.balances[outIdx],
            true
        );
        uint256 newOutValueX128 = currentOutValueX128 - valueExchangedX128;
        uint256 newOutBalance = ValueLib.x(
            self.targetX128,
            esX128[outIdx],
            newOutValueX128,
            true
        );
        outAmount = self.balances[outIdx] - newOutBalance;
        self.setBalance(outIdx, newOutBalance);
    }

    /// Swap out an exact amount of one token by swapping in another.
    /// We have to take fees from the in-token.
    function swapOutExact(
        Closure storage self,
        VertexId inVid,
        VertexId outVid,
        uint256 outAmount
    )
        internal
        returns (uint256 inAmount, uint256 tax, uint256 valueExchangedX128)
    {
        require(self.cid.contains(inVid), IrrelevantVertex(self.cid, inVid));
        require(self.cid.contains(outVid), IrrelevantVertex(self.cid, outVid));
        trimBalance(self, inVid);
        trimBalance(self, outVid);
        // The value in this pool won't change.
        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        uint8 inIdx = inVid.idx();
        uint8 outIdx = outVid.idx();
        // Calculate the value removed by the out token.
        valueExchangedX128 =
            ValueLib.v(
                self.targetX128,
                esX128[outIdx],
                self.balances[outIdx],
                true
            ) -
            ValueLib.v(
                self.targetX128,
                esX128[outIdx],
                self.balances[outIdx] - outAmount,
                false
            );
        self.setBalance(outIdx, self.balances[outIdx] - outAmount);
        // To round up the in amount, we want to add value at higher values on the curve.
        // But we want to round down the newInBalance which means we want a lower newInValue.
        // Ultimately these are both valid and both negligible, so it doesn't matter.
        uint256 currentInValueX128 = ValueLib.v(
            self.targetX128,
            esX128[inIdx],
            self.balances[inIdx],
            false
        );
        uint256 newInValueX128 = currentInValueX128 + valueExchangedX128;
        uint256 newInBalance = ValueLib.x(
            self.targetX128,
            esX128[inIdx],
            newInValueX128,
            false
        );
        uint256 untaxedInAmount = newInBalance - self.balances[inIdx];
        self.setBalance(inIdx, newInBalance);
        // Finally we tax the in amount.
        inAmount = UnsafeMath.divRoundingUp(
            untaxedInAmount << 128,
            ONEX128 - self.baseFeeX128
        );
        tax = inAmount - untaxedInAmount;
    }

    /// Remove staked value tokens from this closure. Asset checks if you have said value tokens to begin with.
    /// This doens't change the target or remove tokens. Just allows for someone use to stake now.
    function unstakeValue(
        Closure storage self,
        uint256 value,
        uint256 bgtValue
    ) internal {
        trimAllBalances(self);
        require(!isAnyLocked(self), CannotRemoveWithLockedVertex(self.cid));
        // Unstakers can't remove more than deminimus.
        if (self.valueStaked < value + SimplexLib.deMinimusValue())
            revert InsufficientUnstakeAvailable(
                self.cid,
                self.valueStaked,
                value
            );
        self.valueStaked -= value;
        self.bgtValueStaked -= bgtValue;
    }

    /// Stake value tokens in this closure if there is value to be redeemed.
    function stakeValue(
        Closure storage self,
        uint256 value,
        uint256 bgtValue
    ) internal {
        trimAllBalances(self);
        uint256 maxValue = (self.targetX128 * self.n) >> 128;
        if (self.valueStaked > maxValue + SimplexLib.deMinimusValue())
            emit WarningExcessValueDetected(
                self.cid,
                maxValue,
                self.valueStaked
            );
        if (self.valueStaked + value > maxValue)
            revert InsufficientStakeCapacity(
                self.cid,
                maxValue,
                self.valueStaked,
                value
            );

        self.valueStaked += value;
        self.bgtValueStaked += bgtValue;
    }

    /// Simulate swapping in with an exact amount of one token for another.
    function simSwapInExact(
        Closure storage self,
        VertexId inVid,
        VertexId outVid,
        uint256 inAmount
    ) internal view returns (uint256 outAmount, uint256 valueExchangedX128) {
        require(self.cid.contains(inVid), IrrelevantVertex(self.cid, inVid));
        require(self.cid.contains(outVid), IrrelevantVertex(self.cid, outVid));
        // The value in this pool won't change.
        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        // First tax the in token.
        uint8 inIdx = inVid.idx();
        uint256 tax = FullMath.mulX128(inAmount, self.baseFeeX128, true);
        inAmount -= tax;
        // Calculate the value added by the in token.
        valueExchangedX128 =
            ValueLib.v(
                self.targetX128,
                esX128[inIdx],
                self.balances[inIdx] + inAmount,
                false
            ) -
            ValueLib.v(
                self.targetX128,
                esX128[inIdx],
                self.balances[inIdx],
                true
            );
        uint8 outIdx = outVid.idx();
        // To round down the out amount, we want to remove value at lower values on the curve.
        // But we want to round up the newOutBalance which means we want a higher newOutValue.
        // Ultimately these are both valid and both negligible, so it doesn't matter.
        uint256 currentOutValueX128 = ValueLib.v(
            self.targetX128,
            esX128[outIdx],
            self.balances[outIdx],
            true
        );
        uint256 newOutValueX128 = currentOutValueX128 - valueExchangedX128;
        uint256 newOutBalance = ValueLib.x(
            self.targetX128,
            esX128[outIdx],
            newOutValueX128,
            true
        );
        outAmount = self.balances[outIdx] - newOutBalance;
    }

    /// Simulate swaping out an exact amount of one token by swapping in another.
    function simSwapOutExact(
        Closure storage self,
        VertexId inVid,
        VertexId outVid,
        uint256 outAmount
    ) internal view returns (uint256 inAmount, uint256 valueExchangedX128) {
        require(self.cid.contains(inVid), IrrelevantVertex(self.cid, inVid));
        require(self.cid.contains(outVid), IrrelevantVertex(self.cid, outVid));
        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        uint8 inIdx = inVid.idx();
        uint8 outIdx = outVid.idx();
        // Calculate the value removed by the out token.
        valueExchangedX128 =
            ValueLib.v(
                self.targetX128,
                esX128[outIdx],
                self.balances[outIdx],
                true
            ) -
            ValueLib.v(
                self.targetX128,
                esX128[outIdx],
                self.balances[outIdx] - outAmount,
                false
            );
        // To round up the in amount, we want to add value at higher values on the curve.
        // But we want to round down the newInBalance which means we want a lower newInValue.
        // Ultimately these are both valid and both negligible, so it doesn't matter.
        uint256 currentInValueX128 = ValueLib.v(
            self.targetX128,
            esX128[inIdx],
            self.balances[inIdx],
            false
        );
        uint256 newInValueX128 = currentInValueX128 + valueExchangedX128;
        uint256 newInBalance = ValueLib.x(
            self.targetX128,
            esX128[inIdx],
            newInValueX128,
            false
        );
        uint256 untaxedInAmount = newInBalance - self.balances[inIdx];
        // Finally we tax the in amount.
        inAmount = UnsafeMath.divRoundingUp(
            untaxedInAmount << 128,
            ONEX128 - self.baseFeeX128
        );
    }

    /// Return the current fee checkpoints.
    function getCheck(
        Closure storage self
    )
        internal
        view
        returns (
            uint256[MAX_TOKENS] storage earningsPerValueX128,
            uint256 bgtPerBgtValueX128,
            uint256[MAX_TOKENS] storage unexchangedPerBgtValueX128
        )
    {
        return (
            self.earningsPerValueX128,
            self.bgtPerBgtValueX128,
            self.unexchangedPerBgtValueX128
        );
    }

    /// Add REAL fees collected for a given token. Can't be more than 2**128.
    /// Called by higher level operations that actually collect balances after swaps and value changes.
    function addEarnings(
        Closure storage self,
        VertexId vid,
        uint256 earnings
    ) internal {
        uint8 idx = vid.idx();
        // Round protocol take down.
        uint256 protocolAmount = FullMath.mulX128(
            earnings,
            self.protocolTakeX128,
            false
        );
        SimplexLib.protocolTake(idx, protocolAmount);
        uint256 userAmount = earnings - protocolAmount;
        uint256 unspent;
        if (self.bgtValueStaked > 0) {
            // Round BGT take down.
            uint256 bgtExAmount = (userAmount * self.bgtValueStaked) /
                self.valueStaked;
            uint256 bgtEarned;
            (bgtEarned, unspent) = SimplexLib.bgtExchange(idx, bgtExAmount);
            self.bgtPerBgtValueX128 += (bgtEarned << 128) / self.bgtValueStaked;
            userAmount -= bgtExAmount;
        }
        // We total the shares earned and split after to reduce our vault deposits, and
        // we potentially lose one less dust.
        uint256 reserveShares = ReserveLib.deposit(vid, unspent + userAmount);
        if (unspent > 0) {
            // rare
            uint256 unspentShares = (reserveShares * unspent) /
                (userAmount + unspent);
            self.unexchangedPerBgtValueX128[idx] +=
                (unspentShares << 128) /
                self.bgtValueStaked; // Must be greater than 0 here.
            reserveShares -= unspentShares;
        }
        // Rest goes to non bgt value.
        self.earningsPerValueX128[idx] +=
            (reserveShares << 128) /
            (self.valueStaked - self.bgtValueStaked);
        // Denom is non-zero because all pools start with non-zero non-bgt value.
    }

    /* Helpers */

    /// Update the bgt earnings with the current staking balances.
    /// Called before any value changes, swaps, or fee collections.
    function trimAllBalances(Closure storage self) internal {
        uint256 nonBgtValueStaked = self.valueStaked - self.bgtValueStaked;
        for (
            VertexId vIter = VertexLib.minId();
            !vIter.isStop();
            vIter = vIter.inc()
        ) {
            if (self.cid.contains(vIter))
                _trimBalance(self, vIter, nonBgtValueStaked);
        }
    }

    /// Update the bgt earnings for a single token using the current staking balances.
    function trimBalance(Closure storage self, VertexId vid) internal {
        uint256 nonBgtValueStaked = self.valueStaked - self.bgtValueStaked;
        _trimBalance(self, vid, nonBgtValueStaked);
    }

    function _trimBalance(
        Closure storage self,
        VertexId vid,
        uint256 nonBgtValueStaked
    ) private {
        uint8 idx = vid.idx();
        // Roundup the balance we need.
        uint256 realBalance = AdjustorLib.toReal(idx, self.balances[idx], true);
        (uint256 earnings, uint256 bgtReal) = Store.vertex(vid).trimBalance(
            self.cid,
            realBalance,
            self.valueStaked,
            self.bgtValueStaked
        );
        // All pools start with non-zero nonbgtvalue
        self.earningsPerValueX128[idx] += (earnings << 128) / nonBgtValueStaked;
        if (self.bgtValueStaked > 0) {
            (uint256 bgtEarned, uint256 unspent) = SimplexLib.bgtExchange(
                idx,
                bgtReal
            );
            self.bgtPerBgtValueX128 += (bgtEarned << 128) / self.bgtValueStaked;
            // rare
            if (unspent > 0) {
                uint256 unspentShares = ReserveLib.deposit(vid, unspent);
                self.unexchangedPerBgtValueX128[idx] +=
                    (unspentShares << 128) /
                    self.bgtValueStaked;
            }
        }
    }

    function viewTrimAll(
        Closure storage self
    )
        internal
        view
        returns (
            uint256[MAX_TOKENS] memory realEarningsPerValueX128,
            uint256 bgtPerValueX128,
            uint256[MAX_TOKENS] memory unspentPerValueX128
        )
    {
        uint256 nonBgtValueStaked = self.valueStaked - self.bgtValueStaked;
        for (
            VertexId vIter = VertexLib.minId();
            !vIter.isStop();
            vIter = vIter.inc()
        ) {
            if (self.cid.contains(vIter)) {
                uint8 idx = vIter.idx();
                // Roundup the balance we need.
                uint256 realBalance = AdjustorLib.toReal(
                    idx,
                    self.balances[idx],
                    true
                );
                (uint256 earnings, uint256 bgtReal) = Store
                    .vertex(vIter)
                    .viewTrim(
                        self.cid,
                        realBalance,
                        self.valueStaked,
                        self.bgtValueStaked
                    );
                // All pools start with non-zero nonbgtvalue
                realEarningsPerValueX128[idx] +=
                    (earnings << 128) /
                    nonBgtValueStaked;
                if (self.bgtValueStaked > 0) {
                    (uint256 bgtEarned, uint256 unspent) = SimplexLib
                        .viewBgtExchange(idx, bgtReal);
                    bgtPerValueX128 += (bgtEarned << 128) / self.bgtValueStaked;
                    // rare
                    if (unspent > 0) {
                        unspentPerValueX128[idx] +=
                            (unspent << 128) /
                            self.bgtValueStaked;
                    }
                }
            }
        }
    }

    /// When we update the balance, we want to double check it stays within bounds.
    function setBalance(
        Closure storage self,
        uint8 idx,
        uint256 newBalance
    ) internal {
        // We make sure the balance is above the minimum according to the efficiency factor
        // which guarantees the value will be positive.
        // And also the balance does not go above twice the target, so we limit our exposure to any given token.
        uint256 minX = FullMath.mulX256(
            Store.simplex().minXPerTX128[idx],
            self.targetX128,
            true
        );
        uint256 twiceTarget = self.targetX128 >> 127;
        if (
            newBalance < minX ||
            twiceTarget < newBalance ||
            HARD_BALANCE_CAP < newBalance
        )
            revert TokenBalanceOutOfBounds(
                self.cid,
                idx,
                newBalance,
                minX,
                twiceTarget < HARD_BALANCE_CAP ? twiceTarget : HARD_BALANCE_CAP
            );
        self.balances[idx] = newBalance;
    }

    /// Helper method to save stack depth when calculating single value changes.
    function iterSingleValueDiff(
        Closure storage self,
        SingleValueIter memory valIter,
        bool roundUp
    ) internal view returns (uint256 vertexBalance) {
        uint256[MAX_TOKENS] storage esX128 = SimplexLib.getEsX128();
        for (uint8 i = 0; i < MAX_TOKENS; ++i) {
            if (!self.cid.contains(i)) continue;
            uint256 fairBalance = FullMath.mulX128(
                valIter.scaleX128,
                self.balances[i],
                true
            );
            if (i == valIter.vIdx) vertexBalance = fairBalance;
            else {
                uint256 eX128 = esX128[i];
                if (fairBalance < self.balances[i])
                    valIter.valueSumX128 += ValueLib.vDiff(
                        self.targetX128,
                        eX128,
                        fairBalance,
                        self.balances[i],
                        roundUp
                    );
                else
                    valIter.valueSumX128 += ValueLib.vDiff(
                        self.targetX128,
                        eX128,
                        self.balances[i],
                        fairBalance,
                        roundUp
                    );
            }
        }
    }

    /// Check if any of the tokens in this closure are locked.
    function isAnyLocked(
        Closure storage self
    ) internal returns (bool isLocked) {
        for (
            VertexId vIter = VertexLib.minId();
            !vIter.isStop();
            vIter = vIter.inc()
        ) {
            if (self.cid.contains(vIter)) {
                if (Store.vertex(vIter).isLocked()) return true;
            }
        }
        return false;
    }
}
