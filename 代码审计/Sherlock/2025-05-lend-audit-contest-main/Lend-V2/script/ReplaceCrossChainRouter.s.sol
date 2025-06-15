// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {LendStorage} from "../src/LayerZero/LendStorage.sol";
import {CoreRouter} from "../src/LayerZero/CoreRouter.sol";
import {CrossChainRouter} from "../src/LayerZero/CrossChainRouter.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/// @dev - Important to run the @SetPeer.s.sol script after this one to connect chains.
contract ReplaceCrossChainRouter is Script {
    CoreRouter public coreRouter = CoreRouter(payable(0xc54267526D3C3D55dC3B39c6d7E9b7992d313899));

    LendStorage public lendStorage = LendStorage(0xcaD8f438040514d2C8f5a4ae38C6ff5E74f3b85F);

    address priceOracle = 0xDF213b7171e27947a1D0265b92E0129E1A671455;

    address lendtroller = 0x00479E804dDAb9D5542e18F1DA2B369e53112B4A;

    address oldCrossChainRouter = 0xeEeF7523d3874400b9a55075124525A25302E9Ce;

    address layerZeroEndpoint;

    uint32 currentEid;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();

        (layerZeroEndpoint,,,, currentEid,,) = helperConfig.getActiveNetworkConfig();

        vm.startBroadcast();

        CrossChainRouter crossChainRouter = new CrossChainRouter(
            layerZeroEndpoint,
            msg.sender,
            address(lendStorage),
            lendtroller,
            priceOracle,
            payable(address(coreRouter)),
            currentEid
        );

        coreRouter.setCrossChainRouter(address(crossChainRouter));

        lendStorage.setAuthorizedContract(address(crossChainRouter), true);

        lendStorage.setAuthorizedContract(oldCrossChainRouter, false);

        vm.stopBroadcast();
    }
}
