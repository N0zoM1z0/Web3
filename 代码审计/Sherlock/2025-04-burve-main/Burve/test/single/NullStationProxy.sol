// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IStationProxy} from "../../src/single/IStationProxy.sol";
import {TransferHelper} from "../../src/TransferHelper.sol";

contract NullStationProxy is IStationProxy {
    mapping(address sender => mapping(address lp => mapping(address owner => uint256 balance))) allowances;

    // Typically a station proxy will also have owner => lp token => amounts + checkpoints to be able to claim rewards.
    // Do nothing.
    function harvest() external {}

    /// @inheritdoc IStationProxy
    function depositLP(
        address lpToken,
        uint256 amount,
        address owner
    ) external {
        TransferHelper.safeTransferFrom(
            lpToken,
            msg.sender,
            address(this),
            amount
        );
        allowances[msg.sender][lpToken][owner] += amount;
    }

    /// @inheritdoc IStationProxy
    function withdrawLP(
        address lpToken,
        uint256 amount,
        address owner
    ) external {
        allowances[msg.sender][lpToken][owner] -= amount;
        TransferHelper.safeTransfer(lpToken, msg.sender, amount);
    }

    /// @inheritdoc IStationProxy
    function allowance(
        address spender,
        address lpToken,
        address owner
    ) external view returns (uint256 _allowance) {
        _allowance = allowances[spender][lpToken][owner];
    }

    /// @inheritdoc IStationProxy
    function migrate(IStationProxy newStationProxy) external {
        // Do nothing.
    }
}
