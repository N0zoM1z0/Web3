// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {IAdjustor} from "./IAdjustor.sol";
import {SafeCast} from "Commons/Math/Cast.sol";

// If a token is an ERC4626 on the base token of interest, this converts share (nominal) to base token (real).
// Using this adjustment eliminates the majority fo IL loss from moving pegs on ERC4626 tokens.
contract E4626ViewAdjustor is IAdjustor {
    error AssetMismatch(address incorrectAsset, address correctAsset);
    address public assetToken;

    constructor(address _assetToken) {
        assetToken = _assetToken;
    }

    function checkAsset(IERC4626 vault) internal view {
        address vaultAsset = vault.asset();
        if (vaultAsset != assetToken)
            revert AssetMismatch(vaultAsset, assetToken);
    }

    function getVault(address token) internal view returns (IERC4626 vault) {
        vault = IERC4626(token);
        checkAsset(vault);
    }

    function toNominal(
        address token,
        uint256 real,
        bool
    ) external view returns (uint256 nominal) {
        IERC4626 vault = getVault(token);
        return vault.convertToShares(real);
    }

    function toNominal(
        address token,
        int256 real,
        bool
    ) external view returns (int256 nominal) {
        IERC4626 vault = getVault(token);
        if (real >= 0) {
            return SafeCast.toInt256(vault.convertToShares(uint256(real)));
        } else {
            return -SafeCast.toInt256(vault.convertToShares(uint256(-real)));
        }
    }

    function toReal(
        address token,
        uint256 nominal,
        bool
    ) external view returns (uint256 real) {
        IERC4626 vault = getVault(token);
        return vault.convertToAssets(nominal);
    }

    function toReal(
        address token,
        int256 nominal,
        bool
    ) external view returns (int256 real) {
        IERC4626 vault = getVault(token);
        if (nominal >= 0) {
            return SafeCast.toInt256(vault.convertToAssets(uint256(nominal)));
        } else {
            return -SafeCast.toInt256(vault.convertToAssets(uint256(-nominal)));
        }
    }

    // We cannot reliably cache these because they rely on external vaults which may change between calls.
    function cacheAdjustment(address token) external {}
}
