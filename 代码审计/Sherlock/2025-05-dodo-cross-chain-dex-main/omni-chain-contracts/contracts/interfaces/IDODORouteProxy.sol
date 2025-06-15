// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDODORouteProxy {
    function mixSwap(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 expReturnAmount,
        uint256 minReturnAmount,
        address[] memory mixAdapters,
        address[] memory mixPairs,
        address[] memory assetTo,
        uint256 directions,
        bytes[] memory moreInfo,
        bytes memory feeData,
        uint256 deadline
    ) external payable returns (uint256);
}
