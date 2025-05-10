// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {BurveFacets, InitLib} from "../src/multi/InitLib.sol";
import {SimplexDiamond as BurveDiamond} from "../src/multi/Diamond.sol";

contract DeployBurveDiamond is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BurveFacets memory facets = InitLib.deployFacets();
        BurveDiamond diamond = new BurveDiamond(facets, "ValueToken", "BVT");
        console2.log("Burve deployed at:", address(diamond));

        vm.stopBroadcast();
    }
}
