// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./BaseScript.sol";
import {ClosureId} from "../../src/multi/closure/Id.sol";

contract ValueToken is BaseScript {
    function run() external {
        // Load configuration from environment
        uint16 closureId = uint16(vm.envOr("CLOSURE_ID", uint256(0)));
        uint256 value = vm.envUint("VALUE");
        uint256 bgtValue = vm.envOr("BGT_VALUE", uint256(value)); // Default to full value if not specified
        bool isMint = vm.envBool("IS_MINT"); // true for mint, false for burn

        // Start broadcasting
        vm.startBroadcast(_getPrivateKey());

        console2.log(
            "\nPreparing to",
            isMint ? "mint" : "burn",
            "value tokens:"
        );
        console2.log("Closure ID:", closureId);
        console2.log("Value:", value);
        console2.log("BGT Value:", bgtValue);

        if (isMint) {
            // Mint value tokens by unstaking value
            valueTokenFacet.mint(value, bgtValue, closureId);
            console2.log("\nSuccessfully minted", value, "value tokens");
        } else {
            // Burn value tokens to stake value
            valueTokenFacet.burn(value, bgtValue, closureId);
            console2.log("\nSuccessfully burned", value, "value tokens");
        }

        vm.stopBroadcast();
    }
}
