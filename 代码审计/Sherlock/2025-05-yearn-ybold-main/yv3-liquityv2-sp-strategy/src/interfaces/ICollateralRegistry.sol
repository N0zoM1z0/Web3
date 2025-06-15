// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {ITroveManager} from "./ITroveManager.sol";

interface ICollateralRegistry {

    function totalCollaterals() external view returns (uint256);
    function getToken(
        uint256 _index
    ) external view returns (address);
    function getTroveManager(
        uint256 _index
    ) external view returns (ITroveManager);

}
