// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IUsualUSDTB is IERC20 {
    function setMintCap(uint256 mintCap) external;

    function mintCap() external view returns (uint256);

    function wrap(address user, uint256 amount) external;

    function blacklist(address account) external;

    function unBlacklist(address account) external;

    function isBlacklisted(address account) external view returns (bool);

    function registryAccess() external view returns (address);

    function pause() external;

    function unpause() external;
}
