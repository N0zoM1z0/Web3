
# Plaza Finance contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Base
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
Standard ERC20. Tokens allowed are set by governance. We will initially use tokens like WETH, USDC, wstETH, WBTC, cbBTC.
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
Owner & GOV_ROLE are trusted parties.
DISTRIBUTOR_ROLE should be given to Distributor and Pool contracts & MINTER_ROLE should only be given to Pool.
SECURITY_COUNCIL_ROLE should only be trusted to pause/unpause contracts.

___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No
___

### Q: Is the codebase expected to comply with any specific EIPs?
EIP20 for LeverageToken & BondToken.
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
Issuance and redemption of tokens is expected to arbitraged (but it doesn't affect any mechanics if they are not).
Auction does a 10-day offer of the reserve asset (e.g. ETH) in exchange of a fixed amount of the coupon token (e.g. USDC). It expects to fulfil the entire quantity of coupons for at least any non-zero amount of the reserve tokens (initially set to 10 days but protocol allows arbitrary time).
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
Redemption of leverage token shouldn't be zero as long as there are bonds issued. Market should have started at a non-zero state. Exception of rounding issues on extremely low values of leverage token.
___

### Q: Please discuss any design choices you made.
Functions like distribute(), startAuction() at Pool or endAuction() at Auction contracts are meant to be called by anyone for legal reasons. Those methods have the appropriate constraints so they can only be called at the appropriate time. Also Bond holders are incentivised to execute those in order to get their coupons paid.
___

### Q: Please provide links to previous audits (if any).
https://convexitylabs.notion.site/EXT-Zellic-Audit-17a3b6744d7680ef96e3e2f44d414f20
___

### Q: Please list any relevant protocol resources.
https://docs.plaza.finance/
https://convexitylabs.notion.site/EXT-Audit-Public-Protocol-Documentation-12f3b6744d7680f9b330e318eac97896
https://convexitylabs.notion.site/EXT-Financial-Mechanism-Overview-46ecc3b204c04e66a21957fbcf5f4c05

https://convexitylabs.notion.site/EXT-Protocol-Architecture-Docs-09ed1ae22d9244ab8eec5f6ae8c0649f
From Architecture Docs: Merchant has been deprecated and replaced by Auction. LiFi/cross-chain flow is out of the scope of the competition
___



# Audit scope


[plaza-evm @ 092b96e78cee4a01077f3f4d4fbd91eccfcdeadf](https://github.com/Convexity-Research/plaza-evm/tree/092b96e78cee4a01077f3f4d4fbd91eccfcdeadf)
- [plaza-evm/src/Auction.sol](plaza-evm/src/Auction.sol)
- [plaza-evm/src/BalancerOracleAdapter.sol](plaza-evm/src/BalancerOracleAdapter.sol)
- [plaza-evm/src/BalancerRouter.sol](plaza-evm/src/BalancerRouter.sol)
- [plaza-evm/src/BondOracleAdapter.sol](plaza-evm/src/BondOracleAdapter.sol)
- [plaza-evm/src/BondToken.sol](plaza-evm/src/BondToken.sol)
- [plaza-evm/src/Distributor.sol](plaza-evm/src/Distributor.sol)
- [plaza-evm/src/LeverageToken.sol](plaza-evm/src/LeverageToken.sol)
- [plaza-evm/src/OracleFeeds.sol](plaza-evm/src/OracleFeeds.sol)
- [plaza-evm/src/OracleReader.sol](plaza-evm/src/OracleReader.sol)
- [plaza-evm/src/Pool.sol](plaza-evm/src/Pool.sol)
- [plaza-evm/src/PoolFactory.sol](plaza-evm/src/PoolFactory.sol)
- [plaza-evm/src/PreDeposit.sol](plaza-evm/src/PreDeposit.sol)
- [plaza-evm/src/lib/Decimals.sol](plaza-evm/src/lib/Decimals.sol)
- [plaza-evm/src/lib/ERC20Extensions.sol](plaza-evm/src/lib/ERC20Extensions.sol)
- [plaza-evm/src/lib/Utils.sol](plaza-evm/src/lib/Utils.sol)
- [plaza-evm/src/utils/Deployer.sol](plaza-evm/src/utils/Deployer.sol)


