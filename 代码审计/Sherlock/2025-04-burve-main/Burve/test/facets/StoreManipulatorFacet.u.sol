// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ClosureId} from "../../src/multi/closure/Id.sol";
import {Closure} from "../../src/multi/closure/Closure.sol";
import {Store} from "../../src/multi/Store.sol";
import {Simplex} from "../../src/multi/Simplex.sol";
import {MAX_TOKENS} from "../../src/multi/Constants.sol";
import {Vertex} from "../../src/multi/vertex/Vertex.sol";
import {VertexId, VertexLib} from "../../src/multi/vertex/Id.sol";

contract StoreManipulatorFacet {
    function setClosureValue(
        uint16 closureId,
        uint8 n,
        uint256 targetX128,
        uint256[MAX_TOKENS] memory balances,
        uint256 valueStaked,
        uint256 bgtValueStaked
    ) external {
        Closure storage c = Store.closure(ClosureId.wrap(closureId));
        c.n = n;
        c.targetX128 = targetX128;
        c.valueStaked = valueStaked;
        c.bgtValueStaked = bgtValueStaked;
        c.balances = balances;
    }

    function setClosureFees(
        uint16 closureId,
        uint256 baseFeeX128,
        uint256 protocolTakeX128,
        uint256[MAX_TOKENS] memory earningsPerValueX128,
        uint256 bgtPerBgtValueX128,
        uint256[MAX_TOKENS] memory unexchangedPerBgtValueX128
    ) external {
        Closure storage c = Store.closure(ClosureId.wrap(closureId));
        c.baseFeeX128 = baseFeeX128;
        c.protocolTakeX128 = protocolTakeX128;
        c.bgtPerBgtValueX128 = bgtPerBgtValueX128;
        c.earningsPerValueX128 = earningsPerValueX128;
        c.unexchangedPerBgtValueX128 = unexchangedPerBgtValueX128;
    }

    function setProtocolEarnings(
        uint256[MAX_TOKENS] memory _protocolEarnings
    ) external {
        Store.simplex().protocolEarnings = _protocolEarnings;
    }

    function getVertex(VertexId vid) external view returns (Vertex memory v) {
        return Store.vertex(vid);
    }
}
