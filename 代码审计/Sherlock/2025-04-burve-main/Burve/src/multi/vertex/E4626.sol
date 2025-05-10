// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {FullMath} from "../../FullMath.sol";
import {VaultTemp} from "./VaultPointer.sol";
import {ClosureId} from "../closure/Id.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";

/** A simple e4626 wrapper that tracks ownership by closureId
 * Note that there are plenty of E4626's that have lockups
 * and we'll have to separate balance from the currently-withdrawable-balance.
 **/
struct VaultE4626 {
    IERC20 token;
    IERC4626 vault;
    uint256 totalVaultShares; // Shares we own in the underlying vault.
    mapping(ClosureId => uint256) shares;
    uint256 totalShares;
}

using VaultE4626Impl for VaultE4626 global;

library VaultE4626Impl {
    /// Thrown when requesting a balance too large for a given cid.
    error InsufficientBalance(
        address vault,
        ClosureId cid,
        uint256 available,
        uint256 requested
    );

    /** Operational requirements */

    function init(
        VaultE4626 storage self,
        address _token,
        address _vault
    ) internal {
        self.token = IERC20(_token); // maybe ZERO? but we assume that admin behaves well.
        self.vault = IERC4626(_vault);
    }

    function del(VaultE4626 storage self) internal {
        self.token = IERC20(address(0));
        self.vault = IERC4626(address(0));
    }

    // The first function called on vaultProxy creation to prep ourselves for other operations.
    function fetch(
        VaultE4626 storage self,
        VaultTemp memory temp
    ) internal view {
        temp.vars[0] = self.vault.previewRedeem(self.totalVaultShares); // Total assets
        temp.vars[3] = self.vault.previewRedeem(
            self.vault.previewDeposit(1 << 128)
        ); // X128 fee discount factor.
    }

    // Actually make our deposit/withdrawal
    function commit(VaultE4626 storage self, VaultTemp memory temp) internal {
        uint256 assetsToDeposit = temp.vars[1];
        uint256 assetsToWithdraw = temp.vars[2];

        if (assetsToDeposit > 0 && assetsToWithdraw > 0) {
            // We can net out and save ourselves some fees.
            if (assetsToDeposit > assetsToWithdraw) {
                assetsToDeposit -= assetsToWithdraw;
                assetsToWithdraw = 0;
            } else if (assetsToWithdraw > assetsToDeposit) {
                assetsToDeposit = 0; // wrong order！！！
                assetsToWithdraw -= assetsToDeposit;
            } else {
                // Perfect net!
                return;
            }
        }

        if (assetsToDeposit > 0) {
            // Temporary approve the deposit.
            SafeERC20.forceApprove(
                self.token,
                address(self.vault),
                assetsToDeposit
            );
            self.totalVaultShares += self.vault.deposit(
                assetsToDeposit,
                address(this)
            );
            SafeERC20.forceApprove(self.token, address(self.vault), 0);
        } else if (assetsToWithdraw > 0) {
            // We don't need to hyper-optimize the receiver.
            self.totalVaultShares -= self.vault.withdraw(
                assetsToWithdraw,
                address(this),
                address(this)
            );
        }
    }

    /** Operations used by Vertex */

    function deposit(
        VaultE4626 storage self,
        VaultTemp memory temp,
        ClosureId cid,
        uint256 amount
    ) internal {
        uint256 newlyAdding = FullMath.mulX128(
            temp.vars[1],
            temp.vars[3],
            true // Round up to round shares down.
        );
        uint256 totalAssets = temp.vars[0] + newlyAdding - temp.vars[2];

        uint256 discountedAmount = FullMath.mulX128(
            amount,
            temp.vars[3],
            false // Round down to round shares down.
        );
        uint256 newShares = totalAssets == 0
            ? discountedAmount // <=== 存疑，待check 初始存入
            : FullMath.mulDiv(self.totalShares, discountedAmount, totalAssets);
            // deposit 用的是 discountedAmount计算的，而 commit 用的是 amount计算的！不一致！！！
        self.shares[cid] += newShares;
        self.totalShares += newShares;
        temp.vars[1] += amount;
    }

    function withdraw(
        VaultE4626 storage self,
        VaultTemp memory temp,
        ClosureId cid,
        uint256 amount
    ) internal {
        uint256 newlyAdding = FullMath.mulX128(
            temp.vars[1],
            temp.vars[3],
            false // Round down to round shares removed up.
        );
        // We need to remove the assets we will remove because we're removing from total shares along the way.
        uint256 totalAssets = temp.vars[0] + newlyAdding - temp.vars[2];
        // We don't check if we have enough assets for this cid to supply because
        // 1. The shares will underflow if we don't
        // 2. The outer check in vertex should suffice.
        uint256 sharesToRemove = FullMath.mulDiv(
            self.totalShares,
            amount,
            totalAssets
        ); // Rounds down, leaves some share dust in the vault.
        self.shares[cid] -= sharesToRemove;
        self.totalShares -= sharesToRemove;
        temp.vars[2] += amount;
    }

    /// Return the most we can withdraw right now.
    function withdrawable(
        VaultE4626 storage self
    ) internal view returns (uint128) {
        return min128(self.vault.maxWithdraw(address(this)));
    }

    /// Return the amount of tokens owned by a closure
    function balance(
        VaultE4626 storage self,
        VaultTemp memory temp,
        ClosureId cid,
        bool roundUp
    ) internal view returns (uint128 amount) {
        if (self.totalShares == 0) return 0;
        uint256 newlyAdding = FullMath.mulX128(
            temp.vars[1],
            temp.vars[3],
            roundUp
        );
        uint256 totalAssets = temp.vars[0] + newlyAdding - temp.vars[2];

        uint256 fullAmount = roundUp
            ? FullMath.mulDivRoundingUp(
                self.shares[cid],
                totalAssets,
                self.totalShares
            )
            : FullMath.mulDiv(self.shares[cid], totalAssets, self.totalShares);

        // For the pegged assets we're interested in,
        // it would be insane to have more than 2^128 of any token so this is unlikely.
        // And if it is hit, users will withdraw until it goes below because their LP is forcibly trading
        // below NAV.
        amount = min128(fullAmount);
    }

    /// Return the total amount of tokens owned by multiple closures
    function totalBalance(
        VaultE4626 storage self,
        VaultTemp memory temp,
        ClosureId[] storage cids,
        bool roundUp
    ) internal view returns (uint128 amount) {
        if (self.totalShares == 0) return 0;
        uint256 newlyAdding = FullMath.mulX128(
            temp.vars[1],
            temp.vars[3],
            roundUp
        );
        uint256 totalAssets = temp.vars[0] + newlyAdding - temp.vars[2];
        uint256 cidShares = 0;
        for (uint256 i = 0; i < cids.length; ++i) {
            cidShares += self.shares[cids[i]];
        }

        uint256 fullAmount = roundUp
            ? FullMath.mulDivRoundingUp(
                cidShares,
                totalAssets,
                self.totalShares
            )
            : FullMath.mulDiv(cidShares, totalAssets, self.totalShares);
        amount = min128(fullAmount);
    }

    /// Returns the total balance of everything.
    function totalBalance(
        VaultE4626 storage self,
        VaultTemp memory temp,
        bool roundUp
    ) internal view returns (uint256 amount) {
        if (self.totalShares == 0) return 0;
        uint256 newlyAdding = FullMath.mulX128(
            temp.vars[1],
            temp.vars[3],
            roundUp
        );
        amount = temp.vars[0] + newlyAdding - temp.vars[2];
    }

    /// Clamp an amount down to the largest uint128 value possible.
    function min128(uint256 amount) private pure returns (uint128) {
        return
            (amount > type(uint128).max) ? type(uint128).max : uint128(amount);
    }
}
