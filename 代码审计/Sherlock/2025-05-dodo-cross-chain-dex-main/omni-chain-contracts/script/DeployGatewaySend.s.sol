// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {GatewaySend} from "../contracts/GatewaySend.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployGatewaySend is Script {
    address constant gateway = 0x0c487a766110c85d301D96E33579C5B317Fa4995;         // replace with config.defaultAddress.Gateway
    address constant dodoRouteProxy = 0x5fa9e06111814840398ceF6E9563d400F6ed3a8d;  // replace with config.defaultAddress.DODORouteProxy
    address constant dodoApprove = 0x66c45FF040e86DC613F239123A5E21FFdC3A3fEC;     // replace with config.defaultAddress.DODOApprove
    uint256 constant gasLimit = 1000000;

    function run() external {
        vm.startBroadcast();

        console.log("Deploying GatewaySend...");
        
        GatewaySend logic = new GatewaySend();
        bytes memory data = abi.encodeWithSelector(
            GatewaySend.initialize.selector,
            gateway,
            dodoRouteProxy,
            dodoApprove,
            gasLimit
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), data);

        console.log("Proxy deployed at:", address(proxy));
        console.log("Implementation deployed at:", address(logic));

        vm.stopBroadcast();
    }
}
