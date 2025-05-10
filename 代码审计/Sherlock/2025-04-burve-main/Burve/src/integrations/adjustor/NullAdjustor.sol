// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
// Open zeppelin IERC20 doesn't have decimals for some reason.
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IAdjustor} from "./IAdjustor.sol";

/// No adjustments at all.
contract NullAdjustor is IAdjustor {
    function toNominal(
        address,
        uint256 real,
        bool
    ) external pure returns (uint256 nominal) {
        nominal = real;
    }

    function toNominal(
        address,
        int256 real,
        bool
    ) external pure returns (int256 nominal) {
        nominal = real;
    }

    /// Convert a uint to the real value by denormalizing the decimals back to their original value.
    function toReal(
        address,
        uint256 nominal,
        bool
    ) external pure returns (uint256 real) {
        real = nominal;
    }

    /// Convert an int to the real value by denormalizing the decimals back to their original value.
    function toReal(
        address,
        int256 nominal,
        bool
    ) external pure returns (int256 real) {
        real = nominal;
    }

    /// If an adjustment will be queried often, someone can call this to cache the result for cheaper views.
    function cacheAdjustment(address) external pure {}
}
