// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVault {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function deposit(uint256 amount0, uint256 amount1, uint256 minAmount0, uint256 minAmount1)
        external
        returns (uint256 shares, uint256 depositAmount0, uint256 depositAmount1);
    function withdraw(uint256 shares, uint256 minAmount0, uint256 minAmount1)
        external
        returns (uint256 amount0, uint256 amount1);
    function setStrategy(address _strategy) external;
    function balanceOf(address) external view returns (uint256);
    function addVestingPosition(uint256 amount, uint256 amount1, uint256 _duration) external;
    function price() external returns (uint256);
    function totalSupply() external view returns (uint256);
    function balances() external view returns (uint256, uint256);
    function twapPrice() external view returns (uint256);
    function checkPoolActivity() external returns (bool);
    function strategy() external returns (address);
}
