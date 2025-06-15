// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {IAuction} from "./IAuction.sol";

interface IAuctionFactory {

    function createNewAuction(
        address _want
    ) external returns (IAuction);

}
