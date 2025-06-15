// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IPriceFeed} from "./IPriceFeed.sol";
import {IStabilityPool} from "./IStabilityPool.sol";

interface IAddressesRegistry {

    function priceFeed() external view returns (IPriceFeed);
    function stabilityPool() external view returns (IStabilityPool);

}
