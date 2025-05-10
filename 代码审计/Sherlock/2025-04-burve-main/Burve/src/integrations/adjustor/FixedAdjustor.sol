// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IAdjustor} from "./IAdjustor.sol";
import {FullMath} from "../../FullMath.sol";
import {AdminLib} from "Commons/Util/Admin.sol";
import {SafeCast} from "Commons/Math/Cast.sol";

/// An Adjustor that just stores the adjustment ratios.
contract FixedAdjustor is IAdjustor {
    // X128 multiplier
    mapping(address => uint256) public adjsX128;
    mapping(address => uint256) public invAdjsX128;

    constructor() {
        AdminLib.initOwner(msg.sender);
    }

    // Admin
    function setAdjustment(address token, uint256 _adjX128) external {
        AdminLib.validateOwner();
        adjsX128[token] = _adjX128;
        invAdjsX128[token] = FullMath.mulDivX256(1, _adjX128, false);
        // Technically inv can be off by rounding but will only appear in the case where
        // We want to round the result up and the mulX128 doesn't roundup itself.
        // This is acceptable for our purposes but may be worth consideration for others.
        // The initial adj is not going to be perfectly accurate anyways.
        // And by accepting this error we avoid a muldiv on each adjustment.
    }

    // Nothing to cache.
    function cacheAdjustment(address token) external {}

    /// Adjust real token values to a normalized value.
    /// @dev errors on overflow.
    function toNominal(
        address token,
        uint256 value,
        bool roundUp
    ) external view returns (uint256 normalized) {
        uint256 adjX128 = adjsX128[token];
        if (adjX128 == 0) return value;
        return FullMath.mulX128(adjX128, value, roundUp);
    }

    /// Normalize a real int.
    function toNominal(
        address token,
        int256 value,
        bool roundUp
    ) external view returns (int256 normalized) {
        uint256 adjX128 = adjsX128[token];
        if (adjX128 == 0) return value;
        if (value >= 0) {
            return
                SafeCast.toInt256(
                    FullMath.mulX128(adjX128, uint256(value), roundUp)
                );
        } else {
            return
                -SafeCast.toInt256(
                    FullMath.mulX128(adjX128, uint256(-value), roundUp)
                );
        }
    }

    /// Adjust a normalized token amount back to the real amount.
    function toReal(
        address token,
        uint256 value,
        bool roundUp
    ) external view returns (uint256 denormalized) {
        uint256 invAdjX128 = invAdjsX128[token];
        if (invAdjX128 == 0) return value;
        return FullMath.mulX128(invAdjX128, value, roundUp);
    }

    /// Convert a nominal int to a real int.
    function toReal(
        address token,
        int256 value,
        bool roundUp
    ) external view returns (int256 denormalized) {
        uint256 invAdjX128 = invAdjsX128[token];
        if (invAdjX128 == 0) return value;
        if (value >= 0) {
            return
                SafeCast.toInt256(
                    FullMath.mulX128(invAdjX128, uint256(value), roundUp)
                );
        } else {
            return
                -SafeCast.toInt256(
                    FullMath.mulX128(invAdjX128, uint256(-value), roundUp)
                );
        }
    }
}
