// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

error AlreadyClaimed();
error NothingToClaim();
error AlreadyWhitelisted();
error AmountTooBig();
error AmountTooLow();
error AmountIsZero();
error Blacklisted();

error ExpiredSignature(uint256 deadline);
error SameValue();

error Invalid();
error InvalidInput();
error InvalidToken();
error InvalidName();
error InvalidSigner(address owner);
error InvalidDeadline(uint256 approvalDeadline, uint256 intentDeadline);
error NoOrdersIdsProvided();
error InvalidSymbol();
error InvalidInputArraysLength();
error InvalidRates();

error NotAuthorized();
error NotClaimableYet();
error NullAddress();
error NullContract();

error OracleNotWorkingNotCurrent();
error OracleNotInitialized();
error OutOfBounds();
error InvalidTimeout();

error RedeemMustNotBePaused();
error RedeemMustBePaused();
error SwapMustNotBePaused();
error SwapMustBePaused();

error StablecoinDepeg();
error DepegThresholdTooHigh();

error BondNotStarted();
error BondFinished();
error BondNotFinished();

error BeginInPast();
error EndTimeBeforeStartTime();
error StartTimeInPast();
error AlreadyStarted();
error CBRIsTooHigh();
error CBRIsNull();

error RedeemFeeTooBig();
error RedeemFeeCannotBeZero();
error TooManyCollateralTokens();

error ApprovalFailed();

error AmountExceedBacking();
error InvalidOrderAmount(address account, uint256 amount);

error NullMerkleRoot();
error InvalidProof();

error StalePrice();
error InvalidPrice();

error AmountExceedCap();
error InvalidDecimalsNumber();
error MintCapTooSmall();
