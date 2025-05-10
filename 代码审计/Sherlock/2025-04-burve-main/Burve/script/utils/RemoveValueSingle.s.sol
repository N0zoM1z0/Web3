// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./BaseScript.sol";
import {ClosureId} from "../../src/multi/closure/Id.sol";
import {MAX_TOKENS} from "../../src/multi/Constants.sol";

contract RemoveValueSingle is BaseScript {
    function run() external {
        // Load configuration from environment
        address recipient = vm.envOr("RECIPIENT", _getSender());
        uint16 closureId = uint16(vm.envOr("CLOSURE_ID", uint256(5)));
        address token = address(tokens[0]);
        uint128 minReceive = uint128(vm.envOr("MIN_RECEIVE", uint256(0))); // 0 means no minimum requirement

        // Start broadcasting
        vm.startBroadcast(_getPrivateKey());

        (
            uint256 value,
            uint256 bgtValue,
            uint256[MAX_TOKENS] memory earnings,
            uint256 bgtEarnings
        ) = valueFacet.queryValue(_getSender(), closureId);

        console2.log("\nPreparing to remove value for single token:");
        console2.log("Closure ID:", closureId);
        console2.log("Value to remove:", value);
        console2.log("BGT Value:", bgtValue);
        console2.log("Token:", MockERC20(token).symbol());
        console2.log("Min Receive:", minReceive);
        console2.log("Recipient:", recipient);

        // Remove value and receive single token
        uint256 removedBalance = valueFacet.removeValueSingle(
            recipient,
            closureId,
            uint128(value),
            uint128(bgtValue),
            token,
            minReceive
        );

        console2.log("\nRemoved balance:", removedBalance);

        vm.stopBroadcast();
    }
}
