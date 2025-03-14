// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IStrategy {
    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    struct VestingPosition {
        int24 tickLower;
        int24 tickUpper;
        uint128 initialLiquidity;
        uint128 remainingLiquidity;
        uint256 startTs;
        uint256 endTs;
        uint256 lastUpdate;
    }

    function price() external view returns (uint256 _price);
    function addVestingPosition(uint256 amount0, uint256 amount1, uint256 _duration) external;
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes memory) external;
    function twapPrice() external view returns (uint256);
    function balances() external view returns (uint256 balance0, uint256 balance1);
    function collectFees() external;
    function withdrawPartial(uint256 shares, uint256 totalSupply) external returns (uint256 amount0, uint256 amount1);
    function idleBalances() external view returns (uint256, uint256);
    function checkPoolActivity() external returns (bool);
    function rebalance() external;
    function compound() external;
    function getMainPosition() external returns (Position memory);
    function getSecondaryPosition() external returns (Position memory);
    function getVestingPosition() external returns (VestingPosition memory);
}
