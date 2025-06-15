// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockNavOracle} from "./Mocks.sol";
import {IWstETH} from "src/interfaces/IWstETH.sol";

import {AggregatorV3Interface} from "src/interfaces/oracles/AggregatorV3Interface.sol";

import {LidoProxyWstETHPriceFeed} from "src/oracles/LidoWstEthOracle.sol";

import {WSTETH} from "src/constants.sol";

contract LidoProxyWstETHPriceFeedTests is Test {
    LidoProxyWstETHPriceFeed public priceFeed;
    address public mockWstEth;

    function setUp() public {
        mockWstEth = address(WSTETH);

        // Mock IWstETH decimals to return 18
        vm.mockCall(
            address(mockWstEth), abi.encodeWithSelector(IWstETH.decimals.selector), abi.encode(18)
        );

        // Mock stEthPerToken to return 1e18 (1:1 ratio)
        vm.mockCall(
            address(mockWstEth),
            abi.encodeWithSelector(IWstETH.stEthPerToken.selector),
            abi.encode(1e18)
        );

        priceFeed = new LidoProxyWstETHPriceFeed(address(mockWstEth));

        vm.warp(block.timestamp + 1000);

        uint256 forkId = vm.createFork("eth");
        vm.selectFork(forkId);
    }

    function testConstructor() external view {
        assertEq(priceFeed.WST_ETH_CONTRACT(), address(WSTETH));
        assertEq(priceFeed.decimals(), 18);
        assertEq(priceFeed.description(), "wstETH / ETH");
        assertEq(priceFeed.version(), 1);
    }

    function test_constructor_invalidDecimals() external {
        MockNavOracle invalidNavOracle = new MockNavOracle();
        vm.mockCall(
            address(invalidNavOracle),
            abi.encodeWithSelector(AggregatorV3Interface.decimals.selector),
            abi.encode(6) // Mock invalid decimals
        );

        vm.expectRevert(LidoProxyWstETHPriceFeed.InvalidDecimalsNumber.selector);
        new LidoProxyWstETHPriceFeed(address(invalidNavOracle));
    }

    function test_getRoundData() external view {
        console2.log("priceFeed.decimals()", priceFeed.decimals());
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.getRoundData(1);

        assertEq(roundId, 1);
        assertEq(answer, 1e18); // Threshold applied
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }

    function test_getRoundData_mainnet() external {
        vm.clearMockedCalls();
        console2.log("priceFeed.decimals()", priceFeed.decimals());
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.getRoundData(1);

        assertEq(roundId, 1);
        assertGt(answer, 1.2e18); // as of 13/05/2025
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }
}
