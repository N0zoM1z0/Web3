// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface AggregatorV3Interface {

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

}
