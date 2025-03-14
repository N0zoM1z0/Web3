// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ITokenDeployer {
    function deploy(string memory name, string memory symbol, uint8 decimals, address asset, uint256 id)
        external
        returns (address);
}
