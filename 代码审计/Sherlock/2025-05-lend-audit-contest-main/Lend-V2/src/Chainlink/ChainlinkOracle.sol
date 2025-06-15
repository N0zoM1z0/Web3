// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import "../PriceOracle.sol";
import "./AggregatorV3Interface.sol";

contract ChainlinkOracle is PriceOracle {
    error ChainlinkOracle_FeedNotFound(address lToken);
    error ChainlinkOracle_NoValidPrices(address lToken);

    uint256 public constant PRICE_SCALAR = 1e10;

    mapping(address lToken => address chainlinkFeed) lTokenToFeed;
    mapping(address lToken => uint256 lastValidPrice) lastValidPrices;

    constructor() {}

    function addLTokenToFeed(address lToken, address feed) external {
        lTokenToFeed[lToken] = feed;
    }

    function getUnderlyingPrice(LToken lToken) external view virtual override returns (uint256) {
        // Get address of chainlink feed
        address feed = lTokenToFeed[address(lToken)];

        if (feed == address(0)) revert ChainlinkOracle_FeedNotFound(address(lToken));

        // Query chainlink feed for price
        (, int256 price,,,) = AggregatorV3Interface(feed).latestRoundData();

        if (price <= 0) {
            uint256 lastValidPrice = lastValidPrices[address(lToken)];
            if (lastValidPrice == 0) revert ChainlinkOracle_NoValidPrices(address(lToken));
            return lastValidPrice;
        }

        // Scale price from 1e8 to 1e18
        return uint256(price) * PRICE_SCALAR;
    }
}
