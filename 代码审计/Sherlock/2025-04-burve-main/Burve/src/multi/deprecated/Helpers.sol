// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
import {RFTLib} from "Commons/Util/RFT.sol";
import {MAX_TOKENS, TokenRegistry} from "../Token.sol";
import {Store} from "../Store.sol";

library PayLib {
    function sendFunds(
        address recipient,
        uint256[MAX_TOKENS] memory balances,
        bytes calldata data
    ) internal {
        TokenRegistry storage tokenReg = Store.tokenRegistry();
        uint256 n = tokenReg.tokens.length;
        address[] memory tokens = new address[](n);
        int256[] memory balanceChanges = new int256[](n);
        for (uint8 i = 0; i < n; ++i) {
            tokens[i] = tokenReg.tokens[i];
            balanceChanges[i] = -int256(balances[i]);
        }
        RFTLib.settle(recipient, tokens, balanceChanges, data);
    }

    function recieveFunds(
        address payer,
        uint256[MAX_TOKENS] memory balances,
        bytes calldata data
    ) internal {
        TokenRegistry storage tokenReg = Store.tokenRegistry();
        uint256 n = tokenReg.tokens.length;
        address[] memory tokens = new address[](n);
        int256[] memory balanceChanges = new int256[](n);
        for (uint8 i = 0; i < n; ++i) {
            tokens[i] = tokenReg.tokens[i];
            balanceChanges[i] = int256(balances[i]);
        }
        RFTLib.settle(payer, tokens, balanceChanges, data);
    }

    function sendFunds(
        address recipient,
        address token,
        uint256 balance,
        bytes calldata data
    ) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory balanceChanges = new int256[](1);
        balanceChanges[0] = -int256(balance);
        RFTLib.settle(recipient, tokens, balanceChanges, data);
    }

    function receiveFunds(
        address payer,
        address token,
        uint256 balance,
        bytes calldata data
    ) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory balanceChanges = new int256[](1);
        balanceChanges[0] = int256(balance);
        RFTLib.settle(payer, tokens, balanceChanges, data);
    }
}
