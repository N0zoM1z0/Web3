# Yieldoor contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Sonic, Base, Optimism, Arbitrum
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
Protocol will work only with standard ERC20 tokens.
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
The following limitations apply:
 - Owner is trusted.
 - No market will allow leverage higher than 5x.
 - Every market's max leverage will be set according to it. Any issue arising from the allowance of high leverage on a low liquidity/ very volatile pair, will be invalidated.
 - TWAP interval will be set individually for each pair. Assume values could range from 1-10 minutes.

___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No.
___

### Q: Is the codebase expected to comply with any specific EIPs?
No.
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
Protocol will run rebalancer bot which will often rebalance/ compound strategies. 
Protocol will also run our own liquidation bots, although everyone is welcome to run their own, as liquidations are permissionless.
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
- `currBorrowedUSD` for a vault should more or equal to the sum of all positions’ initBorrowedUsd . 
- If a user performs a deposit and then immediately withdraws the amount of shares they've just received, they should always get funds back in the same ratio as when they deposited them (excluding rounding down of a few wei).
___

### Q: Please discuss any design choices you made.
In Strategy, `balances` does not return the correct amounts, unless `collectFees` has been called right before that.
___

### Q: Please provide links to previous audits (if any).
N/A
___

### Q: Please list any relevant protocol resources.
Please refer to the following [document](https://docs.google.com/document/d/1PEDFyFjuce5BKG0jHqAE-DfQbxTjiHfBjbhpj46i3Xg) explaining what Yieldoor contracts do
___

### Q: Additional audit information.
Please refer to the following [Security Docs](https://docs.google.com/document/d/1FUjXMXBRBRVgOYSMGORTFmS9fj_nh-ifQhoY0jjhwPY)


# Audit scope

[yieldoor @ 177f210c0814798a07ad9b473fd3608cc989a40e](https://github.com/spacegliderrrr/yieldoor/tree/177f210c0814798a07ad9b473fd3608cc989a40e)
- [yieldoor/src/LendingPool.sol](yieldoor/src/LendingPool.sol)
- [yieldoor/src/Leverager.sol](yieldoor/src/Leverager.sol)
- [yieldoor/src/Strategy.sol](yieldoor/src/Strategy.sol)
- [yieldoor/src/Vault.sol](yieldoor/src/Vault.sol)
- [yieldoor/src/libraries/InterestRateUtils.sol](yieldoor/src/libraries/InterestRateUtils.sol)
- [yieldoor/src/libraries/ReserveLogic.sol](yieldoor/src/libraries/ReserveLogic.sol)
- [yieldoor/src/types/DataTypes.sol](yieldoor/src/types/DataTypes.sol)
- [yieldoor/src/yToken.sol](yieldoor/src/yToken.sol)


