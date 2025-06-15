# Yearn yBOLD contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Ethereum, Arbitrum, Base, Optimism, Sonic, Polygon
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
For Ethereum:
BOLD as the main asset for users deposit/withdraw
wstETH, rETH and WETH is the collateral that strategy can have claim from the stability pool which will be auctioned to BOLD.

For others:
No weird ERC20 and native token (ETH, AVAX etc)
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
All roles are trusted to modify the parameters they are authorized to manage on their respective contracts. However, if any role is able to set a value in a way that could result in the theft of depositor funds, this would be considered a valid finding.
No role should be capable of stealing from depositors or permanently blocking withdrawals.
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No
___

### Q: Is the codebase expected to comply with any specific EIPs?
No
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
**Keepers**
When BOLD from the stability pool is used for liquidations, depositors' BOLD balances are reduced, and collateral is distributed pro rata to them. Since the strategy is also a depositor, its underlying BOLD share will be reduced as well. In such cases, keepers will call `tend` to auction off the received collateral for BOLD in order to quickly restore the strategy’s BOLD position.

___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
yBOLD should always maintain a 1:1 ratio with BOLD, unless a loss occurs. In the event of a loss, the `Accountant.sol` contract will first cover the loss before distributing any fees to `st-yBOLD`.

When `process_report` is called on yBOLD, any gain must be fully minted as yBOLD to `Accountant.sol`, from which it will be distributed to `st-yBOLD`.

If `process_report` reports a loss, `Accountant.sol` will not take any fees until the yBOLD price per share returns to 1.

Auctions must start from the collateral price multiplied by a buffer percentage, where the price is fetched from the oracle used by Liquity.

Tending needs to be time-sensitive—once collateral is available for the strategy to claim, a keeper must call tend. The tend trigger must return true to signal that tending is required.

`protocol_fee_bps` is currently "0" for all Yearn V3 vaults. However, this can be set up to some other value in future. We would love to know if setting the protocol fee would break any of our invariants. Note that protocol fee recipient is never be the "self"
___

### Q: Please discuss any design choices you made.
1. When keepers call `harvest`, there may be cases where the strategy’s BOLD balance is temporarily reduced—due to liquidations—while the corresponding collateral is still being auctioned. In these scenarios, the strategy may report a loss compared to the previous harvest. To mitigate this, the strategy inherits from `BaseHealthCheck`, which enforces a maximum allowable loss via a `_lossLimitRatio`. Once the collateral is successfully auctioned for BOLD, subsequent harvests will reflect recovered value—assuming the auction proceeds fully offset the loss. However, if the collateral's price drops significantly, even the auctioned BOLD might not cover the reduction in total assets. In such cases, `_lossLimitRatio` will be adjusted, and the realized loss will be accepted.

2. To reduce exposure to fluctuations in the collateral-to-BOLD exchange rate, the strategy aims to call `tend()` as soon as collateral is available. Tending claims the collateral gains and initiates an auction to convert them back into BOLD.

3. In general, users may frontrun harvests if a loss is expected—a known and accepted behavior in Yearn’s design. For this strategy, since losses are often temporary (until the collateral is auctioned), there is no special withdrawal mechanism implemented to address this.

4. We are aware that the auctions can be DoSed. We will tackle this by modifying the Auction contract later. For now, auditors should assume that the Auction contract can only kickable by the respective Strategy.sol.
___

### Q: Please provide links to previous audits (if any).
None for the scope

Yearn V3 Vault Audits:
https://github.com/yearn/yearn-vaults-v3/tree/master/audits

Yearn V3 Tokenized Strategy Audits
https://github.com/yearn/tokenized-strategy/tree/master/audits
___

### Q: Please list any relevant protocol resources.
https://docs.yearn.fi/developers/v3/overview

https://github.com/yearn/tokenized-strategy-periphery
https://github.com/yearn/tokenized-strategy
https://github.com/yearn/yearn-vaults-v3/

Note that the versions of the above GitHub repositories used by the contracts in scope may differ from the ones currently on their respective main branches. Please do check the correct versions of the above contracts used by contracts in scope by verifying it from the lib/
___

### Q: Additional audit information.
**yBOLD** is an ERC-4626 smart contract, implemented as an instance of [VaultV3.vy](https://github.com/yearn/yearn-vaults-v3/blob/master/contracts/VaultV3.vy).
It allocates user-deposited BOLD across three strategies, each corresponding to a different stability pool. These strategies are defined in `Strategy.sol` (in scope) and built on top of Yearn’s base [TokenizedStrategy](https://github.com/yearn/tokenized-strategy/blob/master/src/TokenizedStrategy.sol) framework.

yBOLD dynamically reallocates BOLD among the strategies based on risk and yield, aiming to optimize returns for users. Users may also choose to deposit directly into the underlying strategies—if they are open to public deposits—rather than through the yBOLD vault.

An important detail: all profits generated by yBOLD are redirected to `Accountant.sol`. This means that yBOLD itself always remains 1:1 with BOLD and does not accumulate yield. It also means that the performance fee is effectively 100%, as depositors in yBOLD do not directly receive any yield. The `Accountant` mints all profits as yBOLD and forwards them to `st-yBOLD` (`Staker.sol`), which becomes the actual yield-bearing token.

---

**Setup:**

* Deploy the strategies (`Strategy.sol`). These can optionally be open to all depositors.

  * If a strategy is open to all (not limited to yBOLD), then `profitMaxUnlockTime` should be non-zero.
  * If only yBOLD can deposit, `profitMaxUnlockTime` can be set to zero.

* yBOLD (based on `VaultV3.vy`) will set its accountant to `Accountant.sol`.

  * `Accountant.sol` will take the entire profit as fees—minting all profit as yBOLD to itself.
  * `profitMaxUnlockTime` for yBOLD will be set to `0`.

* st-yBOLD (`Staker.sol`) will operate as a standard vault, meaning its `profitMaxUnlockTime` will not be `0`.

---

**Additional Note:**
Auditors may need to review additional inherited contracts such as `BaseHealthCheck`, auction logic, and the base ERC-4626 compounders. All relevant contracts can be found in the `lib/` directory.

---

**User Journey:**

* Deposit BOLD into yBOLD → receive yBOLD
* Use yBOLD freely in DeFi, or
* Deposit yBOLD into st-yBOLD → earn yield via st-yBOLD



# Audit scope

[yv3-liquityv2-sp-strategy @ 99bdf0a9ade3af6f68e7d6b008b3c5a379e94f16](https://github.com/johnnyonline/yv3-liquityv2-sp-strategy/tree/99bdf0a9ade3af6f68e7d6b008b3c5a379e94f16)
- [yv3-liquityv2-sp-strategy/src/Staker.sol](yv3-liquityv2-sp-strategy/src/Staker.sol)
- [yv3-liquityv2-sp-strategy/src/StakerFactory.sol](yv3-liquityv2-sp-strategy/src/StakerFactory.sol)
- [yv3-liquityv2-sp-strategy/src/Strategy.sol](yv3-liquityv2-sp-strategy/src/Strategy.sol)
- [yv3-liquityv2-sp-strategy/src/StrategyFactory.sol](yv3-liquityv2-sp-strategy/src/StrategyFactory.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/AggregatorV3Interface.sol](yv3-liquityv2-sp-strategy/src/interfaces/AggregatorV3Interface.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IAccountant.sol](yv3-liquityv2-sp-strategy/src/interfaces/IAccountant.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IActivePool.sol](yv3-liquityv2-sp-strategy/src/interfaces/IActivePool.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IAddressesRegistry.sol](yv3-liquityv2-sp-strategy/src/interfaces/IAddressesRegistry.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IAuction.sol](yv3-liquityv2-sp-strategy/src/interfaces/IAuction.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IAuctionFactory.sol](yv3-liquityv2-sp-strategy/src/interfaces/IAuctionFactory.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/ICollateralRegistry.sol](yv3-liquityv2-sp-strategy/src/interfaces/ICollateralRegistry.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IMultiTroveGetter.sol](yv3-liquityv2-sp-strategy/src/interfaces/IMultiTroveGetter.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IPriceFeed.sol](yv3-liquityv2-sp-strategy/src/interfaces/IPriceFeed.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/ISortedTroves.sol](yv3-liquityv2-sp-strategy/src/interfaces/ISortedTroves.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IStabilityPool.sol](yv3-liquityv2-sp-strategy/src/interfaces/IStabilityPool.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/IStrategyInterface.sol](yv3-liquityv2-sp-strategy/src/interfaces/IStrategyInterface.sol)
- [yv3-liquityv2-sp-strategy/src/interfaces/ITroveManager.sol](yv3-liquityv2-sp-strategy/src/interfaces/ITroveManager.sol)
- [yv3-liquityv2-sp-strategy/src/periphery/Accountant.sol](yv3-liquityv2-sp-strategy/src/periphery/Accountant.sol)
- [yv3-liquityv2-sp-strategy/src/periphery/AccountantFactory.sol](yv3-liquityv2-sp-strategy/src/periphery/AccountantFactory.sol)


