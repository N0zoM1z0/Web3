# LEND contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Base
Ethereum
Sonic
Monad
BNB
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
Whitelisted only (e.g BTC, ETH, USDC, DAI, USDT). ERC20 standard.
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
Owner is trusted
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No, governance is trusted.
___

### Q: Is the codebase expected to comply with any specific EIPs?
No.
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
No
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
No
___

### Q: Please discuss any design choices you made.
N/A
___

### Q: Please provide links to previous audits (if any).
N/A
___

### Q: Please list any relevant protocol resources.
All links on site https://www.lend.finance/
___

### Q: Additional audit information.
Builds on top of Compound V2.


# Audit scope

[Lend-V2 @ 5c9398fef079319ecc4e8457b11533d0d8838ee0](https://github.com/tenfinance/Lend-V2/tree/5c9398fef079319ecc4e8457b11533d0d8838ee0)
- [Lend-V2/src/LayerZero/CoreRouter.sol](Lend-V2/src/LayerZero/CoreRouter.sol)
- [Lend-V2/src/LayerZero/CrossChainRouter.sol](Lend-V2/src/LayerZero/CrossChainRouter.sol)
- [Lend-V2/src/LayerZero/LendStorage.sol](Lend-V2/src/LayerZero/LendStorage.sol)


