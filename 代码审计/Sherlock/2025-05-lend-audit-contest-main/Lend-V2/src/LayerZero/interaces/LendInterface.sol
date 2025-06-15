// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface Lend {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address dst, uint256 rawAmount) external returns (bool);
}
