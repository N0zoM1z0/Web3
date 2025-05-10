// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/*
import {Store} from "../Store.sol";
import {Edge, EdgeImpl} from "../Edge.sol";
import {Vertex, VertexId, newVertexId} from "../Vertex.sol";
import {AssetStorage} from "../Asset.sol";
import {VaultStorage} from "../VaultProxy.sol";
import {SimplexStorage} from "./SimplexFacet.sol";
import {ClosureId, newClosureId} from "../Closure.sol";
import {TokenRegLib, TokenRegistry} from "../Token.sol";
contract ViewFacet {
    function getClosureId(
        address[] memory tokens
    ) external view returns (ClosureId) {
        return newClosureId(tokens);
    }

    function getEdge(
        address token0,
        address token1
    ) external view returns (Edge memory) {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        return Store.edge(token0, token1);
    }

    function getPriceX128(
        address token0,
        address token1,
        uint128 balance0,
        uint128 balance1
    ) external view returns (uint256 priceX128) {
        Edge storage self = Store.edge(token0, token1);
        return self.getPriceX128(balance0, balance1);
    }

    function getAssetShares(
        address owner,
        ClosureId cid
    ) external view returns (uint256 shares, uint256 totalShares) {
        AssetStorage storage assets = Store.assets();
        shares = assets.shares[owner][cid];
        totalShares = assets.totalShares[cid];
    }

    function getDefaultEdge() external view returns (Edge memory) {
        return Store.simplex().defaultEdge;
    }

    /// @notice Get the index of a token in the registry
    /// @return idx The index of the token, or revert if not registered
    function getTokenIndex(address token) external view returns (uint8 idx) {
        return TokenRegLib.getIdx(token);
    }

    /// @notice Check if a token is in a closure
    /// @param closureId The closure ID to check
    /// @param token The token address to check
    /// @return True if the token is in the closure
    function isTokenInClosure(
        uint16 closureId,
        address token
    ) external view returns (bool) {
        ClosureId cid = ClosureId.wrap(closureId);
        uint8 idx = TokenRegLib.getIdx(token);
        return cid.contains(newVertexId(idx));
    }
}
 */
