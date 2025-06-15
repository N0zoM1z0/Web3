// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import {LToken} from "../../LToken.sol";

interface UniswapAnchoredViewInterface {
    function getUnderlyingPrice(LToken lToken) external view returns (uint256);
}
