// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Store} from "./Store.sol";
import {IAdjustor} from "../integrations/adjustor/IAdjustor.sol";
import {TokenRegLib} from "./Token.sol";

library AdjustorLib {
    function toReal(
        address token,
        uint256 nominal,
        bool roundUp
    ) internal view returns (uint256 real) {
        IAdjustor adj = Store.adjustor();
        real = adj.toReal(token, nominal, roundUp);
    }

    function toReal(
        uint8 idx,
        uint256 nominal,
        bool roundUp
    ) internal view returns (uint256 real) {
        IAdjustor adj = Store.adjustor();
        real = adj.toReal(TokenRegLib.getToken(idx), nominal, roundUp);
    }

    function toNominal(
        uint8 idx,
        uint256 real,
        bool roundUp
    ) internal view returns (uint256 nominal) {
        IAdjustor adj = Store.adjustor();
        nominal = adj.toNominal(TokenRegLib.getToken(idx), real, roundUp);
    }

    function toNominal(
        address token,
        uint256 real,
        bool roundUp
    ) internal view returns (uint256 nominal) {
        IAdjustor adj = Store.adjustor();
        nominal = adj.toNominal(token, real, roundUp);
    }
}
