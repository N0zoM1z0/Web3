// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CrossChainRouter} from "../src/LayerZero/CrossChainRouter.sol";
import "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// Base EID = 40245
// Arb EID = 40231

contract SetPeer is Script {
    address crossChainRouter = 0xEB76a3714ABC8c09107cbD19AFcec0BAea6e4402;
    address peerCrossChainRouter = 0x08d87C7aB886e07e0847D56e2174203C442210DF;
    uint32 peerEid = 40245;

    function run() public {
        bytes32 peerCrossChainRouterAddress = bytes32(uint256(uint160(peerCrossChainRouter)));

        vm.startBroadcast();
        CrossChainRouter(payable(crossChainRouter)).setPeer(peerEid, peerCrossChainRouterAddress);
        vm.stopBroadcast();
    }
}
