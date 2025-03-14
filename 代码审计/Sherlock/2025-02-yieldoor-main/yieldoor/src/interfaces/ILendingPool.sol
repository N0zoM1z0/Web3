// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DataTypes} from "../types/DataTypes.sol";

interface ILendingPool {
    struct ReserveData {
        uint256 borrowingIndex;
        uint256 lendingIndex;
        uint256 maxLeverage;
        uint256 supplyCap;
        uint256 currentReserves;
    }

    function borrow(address asset, uint256 amount) external;
    function repay(address asset, uint256 amount) external returns (uint256);
    function getCurrentBorrowingIndex(address asset) external view returns (uint256);
    function pullFunds(address asset, uint256 amount) external;
    function pushFunds(address asset, uint256 amount) external;
    function getLeverageParams(address asset) external returns (uint256, uint256);
    function initReserve(address asset) external;
    function deposit(address asset, uint256 amount, address onBehalfOf) external returns (uint256);
    function redeem(address underlyingAsset, uint256 yAssetAmount, address to) external returns (uint256);
    function borrowingRateOfReserve(address asset) external view returns (uint256);
    function setLeverageParams(address asset, uint256 _maxBorrow, uint256 _maxLeverage) external;
    function exchangeRateOfReserve(address asset) external returns (uint256);
    function getYTokenAddress(address asset) external returns (address);
    function setLeverager(address _leverager) external;
    function freezeReserve(address asset) external;
    function unFreezeReserve(address asset) external;
}
