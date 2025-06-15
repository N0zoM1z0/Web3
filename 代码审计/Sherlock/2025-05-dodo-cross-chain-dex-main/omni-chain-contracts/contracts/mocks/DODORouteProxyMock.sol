/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DODORouteProxyMock {
    address constant _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    mapping(address baseToken => mapping(address quoteToken => uint256 price))
        public prices;

    function setPrice(
        address baseToken,
        address quoteToken,
        uint256 price
    ) external {
        prices[baseToken][quoteToken] = price;
        prices[quoteToken][baseToken] = 1e36 / price;
    }

    function externalSwap(
        address fromToken,
        address toToken,
        address, // approveTarget
        address, // swapTarget
        uint256 fromTokenAmount,
        uint256, // minReturnAmount
        bytes memory, // feeData
        bytes memory, // callDataConcat
        uint256 // deadLine
    ) external payable returns (uint256 receiveAmount) {
        if(fromToken != _ETH_ADDRESS_) {
            IERC20(fromToken).transferFrom(
                msg.sender,
                address(this),
                fromTokenAmount
            );
        }
        receiveAmount = (fromTokenAmount * prices[fromToken][toToken]) / 1e18;
        if(toToken != _ETH_ADDRESS_) {
            IERC20(toToken).transfer(msg.sender, receiveAmount);
        } else {
            payable(msg.sender).transfer(receiveAmount);
        }
    }

    function mixSwap(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256, // expReturnAmount
        uint256, // minReturnAmount
        address[] memory, // mixAdapters
        address[] memory, // mixPairs
        address[] memory, // assetTo
        uint256, // directions
        bytes[] memory, // moreInfos
        bytes memory, // feeData
        uint256 // deadLine
    ) external payable returns (uint256 receiveAmount) {
        if(fromToken != _ETH_ADDRESS_) {
            IERC20(fromToken).transferFrom(
                msg.sender,
                address(this),
                fromTokenAmount
            );
        }
        receiveAmount = (fromTokenAmount * prices[fromToken][toToken]) / 1e18;
        if(toToken != _ETH_ADDRESS_) {
            IERC20(toToken).transfer(msg.sender, receiveAmount);
        } else {
            payable(msg.sender).transfer(receiveAmount);
        }
    }

    function dodoMutliSwap(
        uint256 fromTokenAmount,
        uint256, // minReturnAmount
        uint256[] memory, // splitNumber
        address[] memory midToken,
        address[] memory, // assetFrom
        bytes[] memory, // sequence,
        bytes memory, // feeData
        uint256 // deadLine
    ) external payable returns (uint256 receiveAmount) {
        address fromToken = midToken[0];
        address toToken = midToken[midToken.length - 1];
        IERC20(fromToken).transferFrom(
            msg.sender,
            address(this),
            fromTokenAmount
        );
        receiveAmount = (fromTokenAmount * prices[fromToken][toToken]) / 1e18;
        IERC20(toToken).transfer(msg.sender, receiveAmount);
    }

    function test() public {}
}