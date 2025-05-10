// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./BaseScript.sol";
import {ClosureId} from "../../src/multi/closure/Id.sol";
import {MAX_TOKENS} from "../../src/multi/Constants.sol";

contract AddValueSingle is BaseScript {
    function run() external {
        // Load configuration from environment
        address recipient = vm.envOr("RECIPIENT", _getSender());
        uint16 closureId = uint16(vm.envOr("CLOSURE_ID", uint256(5)));
        uint128 valueAmount = uint128(vm.envOr("VALUE", uint256(1_000_000)));
        uint128 bgtValue = uint128(vm.envOr("BGT_VALUE", uint256(valueAmount))); // Default to full value if not specified
        address token = address(tokens[0]);
        uint128 maxRequired = uint128(vm.envOr("MAX_REQUIRED", uint256(0))); // 0 means no restriction

        // Start broadcasting
        vm.startBroadcast(_getPrivateKey());

        console2.log("\nPreparing to add value with single token:");
        console2.log("Closure ID:", closureId);
        console2.log("Value to add:", valueAmount);
        console2.log("BGT Value:", bgtValue);
        console2.log("Recipient:", recipient);
        console2.log("Token:", MockERC20(token).symbol());
        console2.log("Max Required:", maxRequired);

        _mintAndApprove(address(tokens[0]), _getSender(), 1_000_000_000); // over mint token

        // Add value to the closure using a single token
        uint256 requiredBalance = valueFacet.addValueSingle(
            recipient,
            closureId,
            valueAmount,
            bgtValue,
            token,
            maxRequired
        );

        console2.log("\nRequired balance:", requiredBalance);

        vm.stopBroadcast();
    }
}
