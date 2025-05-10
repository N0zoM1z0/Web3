// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./BaseScript.sol";
import {ClosureId} from "../../src/multi/closure/Id.sol";
import {MAX_TOKENS} from "../../src/multi/Constants.sol";

contract AddSingleForValue is BaseScript {
    function run() external {
        // Load configuration from environment
        address recipient = vm.envOr("RECIPIENT", _getSender());
        uint16 closureId = uint16(vm.envOr("CLOSURE_ID", uint256(5)));
        address token = address(tokens[0]);
        uint128 amount = uint128(vm.envOr("AMOUNT", uint256(1_000_000)));
        uint256 bgtPercentX256 = vm.envOr(
            "BGT_PERCENT_X256",
            uint256(1 << 255)
        ); // 0 means no BGT
        uint128 minValue = uint128(vm.envOr("MIN_VALUE", uint256(0))); // 0 means no minimum value requirement

        // Start broadcasting
        vm.startBroadcast(_getPrivateKey());

        console2.log("\nPreparing to add single token for value:");
        console2.log("Closure ID:", closureId);
        console2.log("Token:", MockERC20(token).symbol());
        console2.log("Amount to add:", amount);
        console2.log("BGT Percent (X256):", bgtPercentX256);
        console2.log("Min Value:", minValue);
        console2.log("Recipient:", recipient);

        _mintTokensForClosure(closureId, recipient, amount * 2);

        // Add single token for value
        uint256 valueReceived = valueFacet.addSingleForValue(
            recipient,
            closureId,
            token,
            amount,
            bgtPercentX256,
            minValue
        );

        console2.log("\nValue received:", valueReceived);

        vm.stopBroadcast();
    }
}
