// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {BaseHealthCheck, BaseStrategy} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";

import {IAccountant} from "./interfaces/IAccountant.sol";

contract LV2SPStakerStrategy is BaseHealthCheck {

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice The accountant of the vault, from which we claim rewards
    IAccountant public immutable ACCOUNTANT;

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _vault Address of the strategy's underlying vault
    /// @param _name Name of the strategy
    constructor(address _vault, string memory _name) BaseHealthCheck(_vault, _name) {
        ACCOUNTANT = IAccountant(IVault(_vault).accountant());
        require(address(ACCOUNTANT) != address(0), "!accountant");
    }

    // ===============================================================
    // Internal mutated functions
    // ===============================================================

    /// @inheritdoc BaseStrategy
    function _deployFunds(
        uint256 /* _amount */
    ) internal pure override {
        return;
    }

    /// @inheritdoc BaseStrategy
    function _freeFunds(
        uint256 /* _amount */
    ) internal pure override {
        return;
    }

    /// @inheritdoc BaseStrategy
    function _harvestAndReport() internal override returns (uint256 _totalAssets) {
        ACCOUNTANT.distribute(address(asset)); // Claim yBOLD

        // Return total balance
        _totalAssets = asset.balanceOf(address(this));
    }

}
