// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {MAX_TOKENS} from "./Constants.sol";
import {Store} from "./Store.sol";

struct TokenRegistry {
    address[] tokens;
    mapping(address => uint8) tokenIdx;
}

library TokenRegLib {
    /// Thrown when registering a token if the token registry is at capacity.
    error AtTokenCapacity();
    /// Thrown when registering a token if that token has already been registered.
    error TokenAlreadyRegistered(address token);
    /// Thrown during token address lookup if the token is not registered.
    error TokenNotFound(address token);
    /// Thrown during token index lookup if the index does not exist.
    error IndexNotFound(uint8 idx);

    /// Emitted when a new token is registered.
    event TokenRegistered(address token);

    /// @notice Registers a new token in the token registry.
    /// @dev Reverts if the token is already registered or if the registry is at capacity.
    /// @param token The address of the token to register.
    /// @return idx The index of the token in the registry.
    function register(address token) internal returns (uint8 idx) {
        TokenRegistry storage tokenReg = Store.tokenRegistry();

        if (tokenReg.tokens.length >= MAX_TOKENS) revert AtTokenCapacity();
        if (
            tokenReg.tokens.length > 0 &&
            (tokenReg.tokenIdx[token] != 0 || tokenReg.tokens[0] == token) // 学习这里的检查逻辑！！！ 要考虑idx=0的token的情况！！！
        ) revert TokenAlreadyRegistered(token);

        idx = uint8(tokenReg.tokens.length);
        tokenReg.tokenIdx[token] = idx;
        tokenReg.tokens.push(token);

        emit TokenRegistered(token);
    }

    /// @notice Returns the number of tokens in the registry.
    /// @return n The number of tokens in the registry.
    function numVertices() internal view returns (uint8 n) {
        return uint8(Store.tokenRegistry().tokens.length);
    }

    /// @notice Returns the index of a token in the registry.
    /// @dev Reverts if the token is not registered.
    /// @param token The address of the token to look up.
    /// @return idx The index of the token in the registry.
    function getIdx(address token) internal view returns (uint8 idx) {
        TokenRegistry storage tokenReg = Store.tokenRegistry();
        idx = tokenReg.tokenIdx[token];
        if (
            idx == 0 &&
            (tokenReg.tokens.length == 0 || tokenReg.tokens[0] != token)
        ) revert TokenNotFound(token);
    }

    /// @notice Returns the address of a token at a given index in the registry.
    /// @dev Reverts if the index does not exist.
    /// @param idx The index of the token to look up.
    /// @return token The address of the token at the given index.
    function getToken(uint8 idx) internal view returns (address token) {
        return Store.tokenRegistry().tokens[idx];
    }

    /// @notice Checks if a token is registered in the registry.
    /// @param token The address of the token to check.
    function isRegistered(address token) internal view returns (bool) {
        TokenRegistry storage tokenReg = Store.tokenRegistry();
        uint8 idx = tokenReg.tokenIdx[token];
        return
            !(idx == 0 &&
                (tokenReg.tokens.length == 0 || tokenReg.tokens[0] != token));
    }
}
