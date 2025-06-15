# DODO Cross-Chain DEX contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
ZetaChain, Ethereum, Polygon, Arbitrum, Base, BNB Chain.
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
The project only integrate tokens inside ZetaChain supported asset list.

For token supported, please refer to: https://www.zetachain.com/docs/developers/tokens/zrc20/#supported-assets
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
Owner and Bot are trusted.
EddyTreasurySafe is only trusted to collect the fees correctly.
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No.
___

### Q: Is the codebase expected to comply with any specific EIPs?
No.
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
If the receiver of refund info is not an EOA address, refund bots collect the tokens and process the refund manually.
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
No.
___

### Q: Please discuss any design choices you made.
This project is a cross-chain DEX supporting both same-chain and cross-chain swaps. It integrates DODO Router for token swap. It applies ZetaChain's cross-chain infrastructure to handle token cross-chaining. It also uses ZetaChain's onRevert and onAbort functions to handle failed transactions. 

For onRevert and onAbort logics, please refer to: https://www.zetachain.com/docs/developers/chains/zetachain/#revert-transactions
___

### Q: Please provide links to previous audits (if any).
None.
___

### Q: Please list any relevant protocol resources.
https://www.zetachain.com/docs/
___

### Q: Additional audit information.
None.


# Audit scope

[omni-chain-contracts @ 2fe44d3da76b721e4d32addfecb04ca97a39cb0d](https://github.com/Skyewwww/omni-chain-contracts/tree/2fe44d3da76b721e4d32addfecb04ca97a39cb0d)
- [omni-chain-contracts/contracts/GatewayCrossChain.sol](omni-chain-contracts/contracts/GatewayCrossChain.sol)
- [omni-chain-contracts/contracts/GatewaySend.sol](omni-chain-contracts/contracts/GatewaySend.sol)
- [omni-chain-contracts/contracts/GatewayTransferNative.sol](omni-chain-contracts/contracts/GatewayTransferNative.sol)
- [omni-chain-contracts/contracts/interfaces/IDODORouteProxy.sol](omni-chain-contracts/contracts/interfaces/IDODORouteProxy.sol)
- [omni-chain-contracts/contracts/interfaces/IUniswapV2Factory.sol](omni-chain-contracts/contracts/interfaces/IUniswapV2Factory.sol)
- [omni-chain-contracts/contracts/interfaces/IUniswapV2Router01.sol](omni-chain-contracts/contracts/interfaces/IUniswapV2Router01.sol)
- [omni-chain-contracts/contracts/interfaces/IWETH9.sol](omni-chain-contracts/contracts/interfaces/IWETH9.sol)
- [omni-chain-contracts/contracts/libraries/AccountEncoder.sol](omni-chain-contracts/contracts/libraries/AccountEncoder.sol)
- [omni-chain-contracts/contracts/libraries/BytesHelperLib.sol](omni-chain-contracts/contracts/libraries/BytesHelperLib.sol)
- [omni-chain-contracts/contracts/libraries/SafeMath.sol](omni-chain-contracts/contracts/libraries/SafeMath.sol)
- [omni-chain-contracts/contracts/libraries/SwapDataHelperLib.sol](omni-chain-contracts/contracts/libraries/SwapDataHelperLib.sol)
- [omni-chain-contracts/contracts/libraries/TransferHelper.sol](omni-chain-contracts/contracts/libraries/TransferHelper.sol)
- [omni-chain-contracts/contracts/libraries/UniswapV2Library.sol](omni-chain-contracts/contracts/libraries/UniswapV2Library.sol)


