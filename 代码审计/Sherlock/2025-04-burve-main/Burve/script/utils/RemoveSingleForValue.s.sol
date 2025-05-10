// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./BaseScript.sol";
import {ClosureId} from "../../src/multi/closure/Id.sol";
import {MAX_TOKENS} from "../../src/multi/Constants.sol";
import {FullMath} from "../../src/FullMath.sol";

contract RemoveSingleForValue is BaseScript {
    function run() external {
        // Load configuration from environment
        address recipient = vm.envOr("RECIPIENT", _getSender());
        uint16 closureId = uint16(vm.envOr("CLOSURE_ID", uint256(5)));
        address token = address(tokens[0]);
        uint128 maxValue = uint128(vm.envOr("MAX_VALUE", uint256(0))); // 0 means no maximum value requirement

        // Start broadcasting
        vm.startBroadcast(_getPrivateKey());

        (
            uint256 value,
            uint256 bgtValue,
            uint256[MAX_TOKENS] memory earnings,
            uint256 bgtEarnings
        ) = valueFacet.queryValue(_getSender(), closureId);

        uint256 bgtPercentX256 = FullMath.mulDiv(
            bgtValue,
            type(uint256).max,
            value
        );

        console2.log("\nPreparing to remove single token for value:");
        console2.log("Closure ID:", closureId);
        console2.log("Token:", MockERC20(token).symbol());

        console2.log("BGT Percent (X256):", bgtPercentX256);
        console2.log("Max Value:", maxValue);
        console2.log("Recipient:", recipient);

        console2.log("Value:", value);
        console2.log("BGT Value:", bgtValue);
        console2.log("BGT Earnings:", bgtEarnings);

        for (uint8 i = 0; i < _getNumTokens(); i++) {
            console2.log("Earnings for token", i, ":", earnings[i]);
        }

        // Remove single token for value
        uint256 valueGiven = valueFacet.removeSingleForValue(
            recipient,
            closureId,
            token,
            uint128(value),
            bgtPercentX256,
            maxValue
        );

        console2.log("\nValue given:", valueGiven);

        vm.stopBroadcast();
    }
}
