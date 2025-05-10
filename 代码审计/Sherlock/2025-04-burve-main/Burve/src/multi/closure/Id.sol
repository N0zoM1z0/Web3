// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {VertexId} from "../vertex/Vertex.sol";
import {Store} from "../Store.sol";
import {TokenRegistry} from "../Token.sol";

type ClosureId is uint16;

using ClosureIdImpl for ClosureId global;

function newClosureId(address[] memory tokens) view returns (ClosureId) {
    uint16 cid = 0;
    TokenRegistry storage tokenReg = Store.tokenRegistry();
    for (uint256 i = 0; i < tokens.length; ++i) {
        uint16 idx = uint16(1 << tokenReg.tokenIdx[tokens[i]]);
        cid |= idx;
    }
    return ClosureId.wrap(cid);
}

library ClosureIdImpl {
    function isEq(
        ClosureId self,
        ClosureId other
    ) internal pure returns (bool) {
        return ClosureId.unwrap(self) == ClosureId.unwrap(other);
    }

    function contains(
        ClosureId self,
        VertexId vid
    ) internal pure returns (bool) {
        return (ClosureId.unwrap(self) & vid.bit()) != 0;
    }

    function contains(ClosureId self, uint8 idx) internal pure returns (bool) {
        return (ClosureId.unwrap(self) & (1 << idx)) != 0;
    }
}
