// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ClosureId} from "../closure/Id.sol";
import {FullMath} from "../../FullMath.sol";

// In-memory data structure for stores a probability distribution over closures.
struct ClosureDist {
    bytes32 closurePtr;
    uint256 totalWeight;
    uint256[] weights;
}

function newClosureDist(
    ClosureId[] storage closures
) view returns (ClosureDist memory dist) {
    bytes32 ptr;
    assembly {
        ptr := closures.slot
    }
    dist.closurePtr = ptr;
    dist.weights = new uint256[](closures.length);
    dist.totalWeight = 0;
}

using ClosureDistImpl for ClosureDist global;

library ClosureDistImpl {
    // Thrown when a closure dist that is already normalized gets normalized again.
    error AlreadyNormalized(); // Shadowable.
    // Thrown when trying to scale with an unnormalized dist.
    error NotNormalized(); // Shadowable.

    // @dev This denormalizes a distribution.
    function add(
        ClosureDist memory self,
        uint256 idx,
        uint256 weight
    ) internal pure {
        self.weights[idx] += weight;
        self.totalWeight += weight;
    }

    function normalize(ClosureDist memory self) internal pure {
        if (self.totalWeight == 0) revert AlreadyNormalized();
        for (uint256 i = 0; i < self.weights.length; ++i) {
            uint256 weight = self.weights[i];
            self.weights[i] = (weight == self.totalWeight)
                ? type(uint256).max
                : FullMath.mulDivX256(self.weights[i], self.totalWeight, false);
        }
        self.totalWeight = 0;
    }

    // Scale an amount by the relative weight of idx in this distribution
    function scale(
        ClosureDist memory self,
        uint256 idx,
        uint256 amount,
        bool roundUp
    ) internal pure returns (uint256 scaled) {
        if (self.totalWeight != 0) revert NotNormalized();
        scaled = FullMath.mulX256(self.weights[idx], amount, roundUp);
    }

    function getClosures(
        ClosureDist memory self
    ) internal pure returns (ClosureId[] storage closures) {
        // The first slot in self is the closurePtr
        assembly {
            closures.slot := mload(self)
        }
    }
}
