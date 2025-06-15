// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IZRC20} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import {GatewayEVMMock} from "../mocks/GatewayEVMMock.sol";
import {MessageContext} from "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";


contract GatewayZEVMMock {
    GatewayEVMMock public gatewayEVM;

    function setGatewayEVM(address _gatewayEVM) public {
        gatewayEVM = GatewayEVMMock(payable(_gatewayEVM));
    }

    function depositAndCall(
        uint256 chainId,
        address zrc20,
        uint256 amount,
        address target,
        bytes calldata message
    ) external {
        IZRC20(zrc20).transfer(target, amount);
        UniversalContract(target).onCall(
            MessageContext({
                origin: "",
                sender: address(this),
                chainID: chainId
            }), 
            zrc20, 
            amount, 
            message
        );
    }

    function withdraw(
        bytes memory receiver,
        uint256 amount,
        address zrc20,
        RevertOptions calldata revertOptions
    ) external {
        IZRC20(zrc20).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        gatewayEVM.withdraw(
            receiver,
            amount,
            zrc20,
            revertOptions
        );
    }

    function withdrawAndCall(
        bytes memory receiver,
        uint256 amount,
        address zrc20,
        bytes calldata message,
        CallOptions calldata callOptions,
        RevertOptions calldata revertOptions
    ) external {
        IZRC20(zrc20).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        gatewayEVM.withdrawAndCall(
            receiver,
            amount,
            zrc20,
            message,
            callOptions,
            revertOptions
        );
    }
}