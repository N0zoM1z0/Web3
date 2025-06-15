# High-Level Overview

`DaoCollateral.sol` is a smart contract designed to facilitate the swapping of Liquid Staking Tokens (LSTs) for Ethereum-based tokens (ETH0) within our DAO. This contract enables users to swap their Liquid Staking Tokens for ETH0. Additionally, it provides the functionality to redeem ETH0 tokens back for Liquid Staking Tokens.

## Contract Summary

The contract provides the following main functions:

- **Swap:** Facilitates the conversion of Liquid Staking Tokens (LSTs), represented as collateral tokens, into ETH0. Upon initiating this function, users exchange their collateral tokens for ETH0 directly.

- **Redeem:** Allows users to redeem their ETH0. By invoking this function, users exchange their ETH0 for LSTs (collateral tokens) at the current exchange rate.

The contract also includes utility functions:

- **redeemFee:** This function retrieves the current redemption fee set by the DAO. Users can query this function to understand the fee percentage applied when redeeming ETH0 for LSTs.

- **isCBROn:** Returns a boolean value indicating whether the Counter Bank Run (CBR) mechanism is activated. The CBR mechanism is designed to manage potential bank runs by users and can be toggled on or off by the DAO administrators.

- **isRedeemPaused:** Indicates whether the redeem functionality is currently paused. When this function returns true, users are unable to redeem ETH0 for LSTs, typically due to maintenance or other operational reasons.

- **isSwapPaused:** Returns a boolean value indicating whether the swap functionality is currently paused. When this function returns true, users are unable to convert LSTs into ETH0, usually due to maintenance or other operational reasons.

## Inherited Contracts

- **Initializable (OZ):** Utilized to provide a safe and controlled way to initialize the contract's state variables. It ensures that the contract's initializer function can only be called once, preventing accidental or malicious reinitialization.

- **ReentrancyGuardUpgradeable (OZ):** Employed to protect against reentrancy attacks. It provides a modifier that can be applied to functions to prevent them from being called recursively or from being called from other functions that are also protected by the same guard.

- **PausableUpgradeable (OZ):** The `PausableUpgradeable` contract allows the contract administrators to pause certain functionalities in case of emergencies or necessary maintenance. It provides functions to pause and unpause specific operations within the contract to ensure user protection and contract stability.

- **EIP712Upgradeable (OZ):** Implements the Ethereum Improvement Proposal (EIP) 712 standard, defining a domain-specific message signing scheme. It enables contracts to produce and verify typed data signatures, enhancing the security of contract interactions.

## Functionality Breakdown

The DaoCollateral contract facilitates operations related to swapping and redeeming Liquid Staking Tokens for ETH0. The contract's functionality can be broken down into the following key components:

1. **Swap LST to ETH0**

   - **Sanity Check:**
     - Validates the LST token and the amount to ensure they are supported and non-zero or not too high.
   - **Price Quotation:**
     - Retrieves the ETH price quote for the specified amount of LST tokens using the oracle.
   - **Token Transfer:**
     - Transfers the specified amount of LST tokens from the user to the treasury.
   - **ETH0 Minting:**
     - Mints the equivalent amount of ETH0 based on the quoted price and transfers them to the user.

2. **Redeem**
   - **Sanity Check:**
     - Validates the ETH0 amount to ensure it is supported and non-zero.
   - **Price Quotation:**
     - Retrieves the equivalent amount of LST tokens for the specified amount of ETH0 using the oracle.
   - **ETH0 Burning:**
     - Burns the specified amount of ETH0 from the user.
   - **Token Transfer:**
     - Transfers the equivalent amount of LST tokens from the treasury to the user.
   - **Fee Calculation:**
     - Calculates the transaction fee as a percentage of the ETH0 amount.
   - **Fee Transfer:**
     - Mints the calculated fee amount in ETH0 and transfers it to the treasury yield address.

## Security Analysis

### Method: swap

```rust
function swap(...) public nonReentrant
	 whenSwapNotPaused
	 whenNotPaused
  {
	uint256 wadQuoteInETH = _swapCheckAndGetETHQuote(collateralToken, amount);
	if (wadQuoteInETH < minAmountOut) {
		revert AmountTooLow();
	}
	_transferCollateralTokenAndMintEth0(collateralToken, amount, wadQuoteInETH);
	emit Swap(msg.sender, collateralToken, amount, wadQuoteInETH);
}
```

1. The function is defined as `public`, allowing it to be called externally. The `nonReentrant` modifier ensures protection against reentrancy attacks, preventing recursive calls.
2. The `whenSwapNotPaused` modifier ensures that the function can only be executed when the swap functionality is not paused, adding a layer of administrative control.
3. The `whenNotPaused` modifier ensures that the function can only be executed when the entire contract is not paused, providing an additional safety mechanism.
4. Calls the `_swapCheckAndGetETHQuote` function to get the ETH equivalent quote of the LST token amount in WAD format (18 decimals), and stores the result in `wadQuoteInETH`.
5. Evaluates whether the ETH equivalent amount (`wadQuoteInETH`) is less than the minimum acceptable amount (`minAmountOut`).
6. If the condition is true, the function reverts the transaction with an `AmountTooLow` error, stopping the swap from proceeding.
7. Calls the `_transferCollateralTokenAndMintEth0` internal function to manage the transfer of LST tokens and the minting of ETH0 based on the ETH equivalent amount.
8. Emits a `Swap` event, logging details of the swap including the caller's address (`msg.sender`), the LST token address, the amount of LST tokens swapped, and the ETH equivalent amount.

### Method: redeem

```rust
function redeem(...) external
	nonReentrant
	whenRedeemNotPaused
	whenNotPaused
{
	if (amount ==  0) {
		revert AmountIsZero();
	}
	if (!_daoCollateralStorageV0().tokenMapping.isEth0Collateral(collateralToken)) {
		revert InvalidToken();
	}
	uint256 stableFee = _calculateFee(amount, collateralToken);
	uint256 returnedCollateral = _burnEth0TokenAndTransferCollateral(collateralToken, amount, stableFee);
	if (returnedCollateral < minAmountOut) {
		revert AmountTooLow();
	}
	emit Redeem(msg.sender, collateralToken, amount, returnedCollateral, stableFee);
}
```

1. The function is protected against reentrancy attacks by using the `nonReentrant` modifier, ensuring that the function cannot be called recursively or from other functions that are also protected by the same guard.
2. The `whenRedeemNotPaused` modifier checks if the redeem functionality is not paused, preventing the function from executing if the redeeming process is temporarily disabled.
3. The `whenNotPaused` modifier ensures that the overall contract is not paused, preventing the function from executing if the contract is temporarily disabled.
4. Checks if the `amount` specified for redemption is zero.
5. Reverts the transaction with the `AmountIsZero` error if the specified amount is zero, as zero-value transactions are not allowed.
6. Checks if the specified `collateralToken` is a valid ETH0 collateral token using the `isEth0Collateral` function from the `tokenMapping` object.
7. Reverts the transaction with the `InvalidToken` error if the specified `collateralToken` is not a recognized collateral token, ensuring that only valid tokens can be redeemed.
8. Calls the `_calculateFee` function to calculate the fee for the redemption, and stores the fee amount in the `stableFee` variable.
9. Calls the `_burnEth0TokenAndTransferCollateral` function to burn the specified amount of ETH0 and transfer the equivalent collateral to the user, accounting for the `stableFee`. The returned collateral amount is stored in the `returnedCollateral` variable.
10. Checks if the amount of collateral returned (`returnedCollateral`) is less than the minimum amount specified (`minAmountOut`).
11. Reverts the transaction with the `AmountTooLow` error if the returned collateral amount is less than the specified minimum, ensuring that the user receives at least the minimum expected amount.
12. Emits the `Redeem` event, logging the details of the redemption, including the caller's address, the `collateralToken`, the amount redeemed, the collateral returned, and the fee charged.
