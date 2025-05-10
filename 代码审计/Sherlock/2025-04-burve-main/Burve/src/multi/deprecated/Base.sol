// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Store} from "../Store.sol";
import {TokenRegLib} from "../Token.sol";

/// A parent class for facets to share common utilities.
contract BurveFacetBase {
    /// Thrown when a token is paired with itself.
    error SelfEdge(address);

    modifier validTokens(address t0, address t1) {
        if (t0 == t1) revert SelfEdge(t0);
        TokenRegLib.getIdx(t0); // Will fail if its not registrered.
        TokenRegLib.getIdx(t1);
        _;
    }

    modifier validToken(address token) {
        TokenRegLib.getIdx(token);
        _;
    }
}
