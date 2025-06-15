// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GatewayZEVMMock} from "../mocks/GatewayZEVMMock.sol";
import {Callable, MessageContext} from "@zetachain/protocol-contracts/contracts/evm/interfaces/IGatewayEVM.sol";
import {CallOptions, RevertOptions} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IGatewayZEVM.sol";
import {Account, Input} from "../libraries/AccountEncoder.sol";
import {console} from "../../lib/forge-std/src/console.sol";

contract GatewayEVMMock {
    address constant _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 chainId;
    address DODORouteProxy;
    mapping(address => address) public toZRC20; // erc20 => zrc20
    mapping(address => address) public toERC20; // zrc20 => erc20
    mapping(bytes => address) public toEVMAddress;
    GatewayZEVMMock public gatewayZEVM;

    error TargetContractCallFailed();

    function setGatewayZEVM(address _gatewayEVM) public {
        gatewayZEVM = GatewayZEVMMock(_gatewayEVM);
    }

    function setDODORouteProxy(address _dodoRouteProxy) public {
        DODORouteProxy = _dodoRouteProxy;
    }

    function setZRC20(address erc20, address zrc20) public {
        toZRC20[erc20] = zrc20;
        toERC20[zrc20] = erc20;
    }

    function setEVMAddress(bytes memory otherAddress, address evmAddress) public {
        toEVMAddress[otherAddress] = evmAddress;
    }

    function setChainId(uint256 _chainId) public {
        chainId = _chainId;
    }

    function decodeInput(bytes memory encoded) public pure returns (Account[] memory accounts, bytes memory data) {
        Input memory input = abi.decode(encoded, (Input));
        return (input.accounts, input.data);
    }
    
    function depositAndCall(
        address receiver,
        uint256 amount,
        address asset,
        bytes calldata payload,
        RevertOptions calldata revertOptions
    ) external {
        console.log(payload.length + revertOptions.revertMessage.length);
        
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        gatewayZEVM.depositAndCall(
            chainId,
            toZRC20[asset],
            amount,
            receiver,
            payload
        );
    }

    function depositAndCall(
        address receiver,
        bytes calldata payload,
        RevertOptions calldata /*revertOptions*/
    ) external payable {
        gatewayZEVM.depositAndCall(
            chainId,
            toZRC20[_ETH_ADDRESS_],
            msg.value,
            receiver,
            payload
        );
    }


    function withdraw(
        bytes memory receiver,
        uint256 amount,
        address zrc20,
        RevertOptions calldata /*revertOptions*/
    ) external payable {
        address asset = toERC20[zrc20];
        if(receiver.length == 20) {
            IERC20(asset).transfer(address(bytes20(receiver)), amount);
        } else {
            address to = toEVMAddress[receiver];
            IERC20(asset).transfer(to, amount);
        }    
    }

    function withdrawAndCall(
        bytes memory receiver,
        uint256 amount,
        address zrc20,
        bytes calldata message,
        CallOptions calldata /*callOptions*/,
        RevertOptions calldata /*revertOptions*/
    ) external payable {
        address asset = toERC20[zrc20];
        if(receiver.length == 20) {
            address targetContract = address(bytes20(receiver));
            IERC20(asset).approve(targetContract, amount);
            Callable(targetContract).onCall{value: msg.value}(
                MessageContext({
                    sender: address(this)
                }),
                message
            );
        } else {
            address targetContract = toEVMAddress[receiver];
            (, bytes memory data) = decodeInput(message);
            IERC20(asset).approve(targetContract, amount);
            Callable(targetContract).onCall{value: msg.value}(
                MessageContext({
                    sender: address(this)
                }),
                data
            );
        }
    }

    receive() external payable {}

    fallback() external payable {}
}