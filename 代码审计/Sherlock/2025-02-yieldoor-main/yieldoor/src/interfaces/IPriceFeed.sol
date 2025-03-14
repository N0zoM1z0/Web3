// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPriceFeed {
    function getPrice(address asset) external view returns (uint256);
    function hasPriceFeed(address asset) external view returns (bool);
    function setChainlinkPriceFeed(address asset, address feed, uint256 heartbeat) external;
}
