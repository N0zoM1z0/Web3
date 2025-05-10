// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

// ClosureId is limited to a uint16 meaning MAX_TOKENS can't actually exceed 16 without breaking the one-hot encoding.
uint8 constant MAX_TOKENS = 16;
