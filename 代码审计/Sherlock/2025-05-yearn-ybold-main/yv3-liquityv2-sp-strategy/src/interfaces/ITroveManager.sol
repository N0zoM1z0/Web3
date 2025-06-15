// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {ISortedTroves} from "./ISortedTroves.sol";
import {IStabilityPool} from "./IStabilityPool.sol";

interface ITroveManager {

    function sortedTroves() external view returns (ISortedTroves);
    function stabilityPool() external view returns (IStabilityPool);

}
