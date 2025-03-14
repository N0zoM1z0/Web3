// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

import "forge-std/Test.sol";

enum TypePriceFeed {
    NONE,
    CHAINLINK,
    TWAP,
    TWAP_AND_CHAINLINK
}

struct Data {
    TypePriceFeed feedType;
    address feed1;
    address feed2; // this would usally be address(0), unless TWAP_AND_CHAINLINK
    uint256 timeInterval;
}

/// @title PriceFeed
/// @author deadrosesxyz
/// Out-of-scope for the Sherlock audit, sorry frens

contract PriceFeed is Ownable {
    mapping(address => Data) public pricefeeds;

    constructor() Ownable(msg.sender) {}

    function setChainlinkPriceFeed(address asset, address feed, uint256 heartbeat) external onlyOwner {
        Data memory data;

        data.feedType = TypePriceFeed.CHAINLINK;
        data.feed1 = feed;
        data.timeInterval = heartbeat;

        pricefeeds[asset] = data;
    }

    function hasPriceFeed(address asset) public view returns (bool) {
        return pricefeeds[asset].feed1 != address(0);
    }

    function getPrice(address asset) public view returns (uint256 price) {
        Data memory data = pricefeeds[asset];
        if (data.feedType == TypePriceFeed.CHAINLINK) return _getChainlinkPrice(data);
    }

    function _getChainlinkPrice(Data memory data) internal view returns (uint256) {
        (, int256 answer,, /* uint256 updatedAt */ ,) = AggregatorV3Interface(data.feed1).latestRoundData();
        require(answer > 0);
        // require(block.timestamp - updatedAt <= heartbeat);
        return uint256(answer);
    }
}
