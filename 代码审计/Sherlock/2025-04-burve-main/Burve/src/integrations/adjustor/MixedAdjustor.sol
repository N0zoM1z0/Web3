// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IAdjustor} from "./IAdjustor.sol";
import {AdminLib} from "Commons/Util/Admin.sol";
import {NullAdjustor} from "./NullAdjustor.sol";

/// An Adjustor that uses a mix of other adjustors.
/// Ultimately, we use this adjustor in conjuction with other.
contract MixedAdjustor is IAdjustor {
    // Which adjustor to use for which token.
    mapping(address token => address adjustor) public adjAddr;
    // The default adjustor and one is not set for the token.
    address public defAdj;

    constructor() {
        AdminLib.initOwner(msg.sender);
        defAdj = address(new NullAdjustor());
    }

    /* Admin */

    function setAdjustor(address token, address adjustor) external {
        AdminLib.validateOwner();
        adjAddr[token] = adjustor;
    }

    function setDefaultAdjustor(address adjustor) external {
        AdminLib.validateOwner();
        defAdj = adjustor;
    }

    /* IAdjustor */

    function toNominal(
        address token,
        uint256 real,
        bool roundUp
    ) external view returns (uint256 nominal) {
        address adj = adjAddr[token];
        if (adj == address(0)) adj = defAdj;
        return IAdjustor(adj).toNominal(token, real, roundUp);
    }

    function toNominal(
        address token,
        int256 real,
        bool roundUp
    ) external view returns (int256 nominal) {
        address adj = adjAddr[token];
        if (adj == address(0)) adj = defAdj;
        return IAdjustor(adj).toNominal(token, real, roundUp);
    }

    function toReal(
        address token,
        uint256 nominal,
        bool roundUp
    ) external view returns (uint256 real) {
        address adj = adjAddr[token];
        if (adj == address(0)) adj = defAdj;
        return IAdjustor(adj).toReal(token, nominal, roundUp);
    }

    /// Convert an int to the real value by denormalizing the decimals back to their original value.
    function toReal(
        address token,
        int256 nominal,
        bool roundUp
    ) external view returns (int256 real) {
        address adj = adjAddr[token];
        if (adj == address(0)) adj = defAdj;
        return IAdjustor(adj).toReal(token, nominal, roundUp);
    }

    /// If an adjustment will be queried often, someone can call this to cache the result for cheaper views.
    function cacheAdjustment(address token) external {
        address adj = adjAddr[token];
        if (adj == address(0)) adj = defAdj;
        IAdjustor(adj).cacheAdjustment(token);
    }
}
