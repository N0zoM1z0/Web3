// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {AggregatorV3Interface} from "src/interfaces/oracles/AggregatorV3Interface.sol";
import {IWstETH} from "src/interfaces/IWstETH.sol";
/**
 * @title  Oracle Wrapper Proxy for Lido wstETH Chainlink Compatible Price Feed
 * @notice A proxy contract that retrieves wstETH/ETH data from the Lido wstETH contract,
 *         converts it to an ETH denominated price and is compatible with
 *         the Chainlink AggregatorV3Interface.
 * @author Usual Lab
 */

contract LidoProxyWstETHPriceFeed is AggregatorV3Interface {
    /// @notice Emitted when pricefeed oracle has an invalid decimals number.
    error InvalidDecimalsNumber();

    /// @notice The address of the WST ETH Contract from which the wst/ETH conversion rate is fetched.
    address public immutable WST_ETH_CONTRACT;

    /// @notice The number of decimals used in price feed output.
    uint8 public constant PRICE_FEED_DECIMALS = 18;

    /**
     * @notice Constructs the wstETH/ETH Oracle Proxy Price Feed contract.
     * @param  wstEthContract_ The address of the wrapped stETH contract.
     */
    constructor(address wstEthContract_) {
        // Validation of the NAV oracle decimals.
        if (IWstETH(wstEthContract_).decimals() != PRICE_FEED_DECIMALS) {
            revert InvalidDecimalsNumber();
        }

        WST_ETH_CONTRACT = wstEthContract_;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() public pure returns (uint8) {
        return PRICE_FEED_DECIMALS;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external pure returns (string memory) {
        return "wstETH / ETH";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    /// @inheritdoc AggregatorV3Interface
    function getRoundData(uint80 roundId_)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        // Return mock data for all fields except answer
        roundId = roundId_;
        answer = int256(IWstETH(WST_ETH_CONTRACT).stEthPerToken());
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId_;
    }

    /// @inheritdoc AggregatorV3Interface
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        // Return mock data for all fields except answer
        roundId = 1;
        answer = int256(IWstETH(WST_ETH_CONTRACT).stEthPerToken());
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }
}
