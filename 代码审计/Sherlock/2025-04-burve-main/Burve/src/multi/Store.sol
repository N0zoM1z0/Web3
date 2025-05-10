// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {AssetBook} from "./Asset.sol";
import {Closure} from "./closure/Closure.sol";
import {ClosureId} from "./closure/Id.sol";
import {Reserve} from "./vertex/Reserve.sol";
import {VaultStorage} from "./vertex/VaultProxy.sol";
import {Vertex} from "./vertex/Vertex.sol";
import {VertexId} from "./vertex/Id.sol";
import {TokenRegistry} from "./Token.sol";
import {Simplex} from "./Simplex.sol";
import {Locker} from "./facets/LockFacet.sol";
import {IAdjustor} from "../integrations/adjustor/IAdjustor.sol";

struct Storage {
    AssetBook assets;
    TokenRegistry tokenReg;
    VaultStorage _vaults;
    Simplex simplex;
    Locker _locker;
    Reserve _reserve;
    // Graph elements
    mapping(ClosureId => Closure) closures;
    mapping(VertexId => Vertex) vertices;
}

library Store {
    bytes32 public constant MULTI_STORAGE_POSITION =
        keccak256("multi.diamond.storage.20250113");

    error EmptyClosure(ClosureId);
    error UninitializedClosure(ClosureId);
    error UninitializedVertex(VertexId);

    function load() internal pure returns (Storage storage s) {
        bytes32 position = MULTI_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function vertex(VertexId vid) internal view returns (Vertex storage v) {
        v = load().vertices[vid];
        require(VertexId.unwrap(v.vid) != 0, UninitializedVertex(vid));
    }

    function tokenRegistry()
        internal
        view
        returns (TokenRegistry storage tokenReg)
    {
        return load().tokenReg;
    }

    function closure(ClosureId cid) internal view returns (Closure storage _c) {
        require(ClosureId.unwrap(cid) != 0, EmptyClosure(cid));
        _c = load().closures[cid];
        require(ClosureId.unwrap(_c.cid) != 0, UninitializedClosure(cid));
    }

    function vaults() internal view returns (VaultStorage storage v) {
        return load()._vaults;
    }

    function assets() internal view returns (AssetBook storage a) {
        return load().assets;
    }

    function simplex() internal view returns (Simplex storage s) {
        return load().simplex;
    }

    function locker() internal view returns (Locker storage l) {
        return load()._locker;
    }

    function adjustor() internal view returns (IAdjustor adj) {
        return IAdjustor(load().simplex.adjustor);
    }

    function reserve() internal view returns (Reserve storage r) {
        return load()._reserve;
    }
}
