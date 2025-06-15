// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Lendtroller} from "../src/Lendtroller.sol";
import {LToken} from "../src/LToken.sol";
import {Script} from "forge-std/Script.sol";

contract SetSupplySpeeds is Script {
    LToken[] public lTokens = [
        LToken(0x0b2Cb90050409fEa7b19f7Dc854a8948c0d6A1a3),
        LToken(0x8B67Ab8b4eb1C387506c86Fce1628Ea8853CB7D6),
        LToken(0x880799E4450F5CfC1b89D07a50Fd6C88C47164C8),
        LToken(0x39D17CC6C63b95F145A1D01fD61423928DcBC492),
        LToken(0x1dAFDfe1Fb42E50B1De2c6c1e6d602e9cF951DbA)
    ];
    Lendtroller public lendtroller = Lendtroller(0x1eD0A99367C0Cff94b9A7cC288DCE077Ee0476e5);

    function run() public {
        vm.startBroadcast();
        // After all markets have been supported and collateral factors set:
        for (uint256 i = 0; i < lTokens.length; i++) {
            LToken[] memory marketArray = new LToken[](1);
            marketArray[0] = LToken(lTokens[i]);

            uint256[] memory supplySpeeds = new uint256[](1);
            uint256[] memory borrowSpeeds = new uint256[](1);

            // For testing, set a small nonzero speed to confirm indexes advance:
            supplySpeeds[0] = 1e14; // Example: 0.0001 LEND per block to suppliers
            borrowSpeeds[0] = 1e14; // Example: 0.0001 LEND per block to borrowers

            lendtroller._setLendSpeeds(marketArray, supplySpeeds, borrowSpeeds);
        }

        vm.stopBroadcast();
    }
}
