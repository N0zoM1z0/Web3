# Superfluid Locker System contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
- Ethereum
- Optimism
- BNB Smart Chain
- Gnosis
- Polygon
- Base
- Arbitrum One
- Celo
- Avalanche
- Scroll
- Degen Chain

___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
The project integrates the SUP Token, a Superfluid SuperToken that can be found at this address on Base : https://basescan.org/address/0xa69f80524381275A7fFdb3AE01c54150644c8792

(Note that in most of the codebase, SUP Token is named FLUID Token.)

In the context of liquidity provision feature, the project interacts with native ETH (gas token) and WETH. 

For more info regarding SuperTokens, see https://docs.superfluid.finance/docs/category/super-tokens
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
Always assume that owner / admin protected function parameters are valid and cross-checked before transaction submission.

- FluidEPProgramManager.sol :
	- Signers are trusted
	- `FluidEPProgramManager::startFunding` :
		- it is assumed that the FluidTreasury will have granted allowance to this contract for the desired amount prior to this call
		- it is assumed that users (specifically lockers) will have units in the corresponding program distribution pool prior to this call
		- similarly, when subsidy switch is turned ON, it is assumed that users (specifically lockers) will have units in the corresponding staker distribution pool prior to this call
		- For reference, during the initial phase, the subsidyFundingRate will be set to 0. After some time, the subsidyFundingRate will be increased to 500 (i.e. 5%). It is known that the subsidies will only start flowing for the program funded after the rate is updated.
		
- FluidLocker.sol :
	- Each locker is "owned" by an individual account (lockerOwner).
	- UNLOCK_AVAILABLE boolean will be updated using the Beacon Proxy upgrade approach. It is intended that there are no setters for this boolean.

- Fontaine.sol
	- `Fonainte::initialize` :
		- it is assumed that users (specifically lockers) will have units in the Staker and LP GDA distribution pools prior to this call.

- SupVestingFactory.sol
	- `admin` & `treasury` are trusted
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No.
___

### Q: Is the codebase expected to comply with any specific EIPs?
N/A
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
In order to grant units in Superfluid GDA pools, we rely on a third party tool : Stack (see stack.so). 
Stack essentially allocates "points" to users based on onchain activity. 
On user requests (i.e. when users need to claim these points that are representing pool units), Stack generate a signature that contains user related details and the amount of units to be claimed. The contract verifies that the signature is originated from a Stack whitelisted signer and allocate the units once the signature is verified.

Additionally, Superfluid will run some offchain monitoring system to ensure that programs do not overrun their duration (see `FluidProgramDetails::duration` in FluidEPProgramManager). Upon detecting an approaching end of a program a transaction call to `stopFunding` will be performed, ensuring that the different streams inherent to a program are closed on time. It is assumed that these calls will be performed on time.

In regards with the token vesting mechanism (`SupVesting`), the protocol integrate with Superfluid `VestingScheduler` contracts that rely on offchain automation. These automations are managed and monitored by the Superfluid Foundation. They guarantee that the vesting are being started & terminated on-time.
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
- While the boolean `UNLOCK_AVAILABLE` is set to `false` (initial phase), the sum of all tokens distributed through `FluidEPProgramManager` should be equal to the sum of all tokens inside the `FluidLocker` instances plus the undistributed amount (still held in the `FluidEPProgramManager` contract)

- While the boolean `UNLOCK_AVAILABLE` is set to `true`, token distributed to lockers can only be unlocked through : 
	- the `FluidLocker::unlock` function
	- the `FluidLocker::withdrawLiquidity` function (under specific circumstances, see below)
	When unlocking tokens, users shall pay tax based on the unlocking duration they select.
	Users are exempt of taxes in 3 specific cases :
	- when calling `FluidLocker::unlock` function with a unlocking duration of `365 days`
	- when calling `FluidLocker::withdrawLiquidity` after having provided liquidity for over 6 months.
	- when claiming UniswapV3 SUP/ETH pool fees

- Token distributed through the `FluidEPProgramManager` should always land in a `FluidLocker` instance (until withdrawn).
    
- The sum of all the token distributed to `FluidLocker` instance and distributed to the tax distribution pool (if `subsidyFundingRate` is not null) should be equal to the sum of all token distributed through the `FluidEPProgramManager`.
___

### Q: Please discuss any design choices you made.
- `FluidEPProgramManager::stopFunding` function permissionless.
    
    - This ensure that any actor is able to close the streams to the program pool and the tax pool when a program reaches its completion. This is important as funds from multiple program will be held by the `FluidEPProgramManager` contract and stream will not necessarily be liquidated if there are still funds to provision them.
    - Superfluid Foundation Team will necessarily monitor the program and their end date but having this method permissionless also allow external actors to participate in the healthiness of the protocol.
    - 
- `FluidEPProgramManager::stopFunding` can create dust.
    
    - Superfluid streams involve flow rates which imply calculation inaccuracy due to Solidity lack of floating points number supports. This means that when stopping program (although early stops compensation are in place) some dust loss may incur to users. The design accepts and acknowledge this fact it would require an extra intensive calculation for a very minimal amount of token per user (less than a gwei in order of magnitude). These funds will not necessarily be lost forever as other program will essentially stream these funds at some point in time.
    
- `FluidLocker::stake` - Stakers units in the Stakers' tax distribution pools :
    
    - Due to Superfluid General Distribution Agreement implementation and technical limitations, the units held by stakers are downscaled. GDA pool do not allow the total amount of units in a GDA pool to be higher than the flow rate. Therefore, the down scaling factor is 1 Token staked is equal 1 units. This imply that staking less that 1 Token will not provide the user's with GDA pool units, therefore will not yield any returns.
    
- `FluidLocker::provideLiquidity` - providing liquidity will perform a market buy operation
	- In order to create a bit of buy pressure on the LP Pair (SUP/ETH), every time a locker owner decides to provide liquidity from their locker, 1% of the ETH contributed will be used to buy SUP. 
	- Note that this function (`FluidLocker::_pump`) do not use slippage protection. Dev team assumed that the slippage protection occurring in `FluidLocker::_createPosition` is sufficient to protect the `_pump` call.
	- Additionally to the above benefits, this mechanism also add a level of commitment to prevent users from attempting to frontrun large tax distribution events. 
- `FluidLocker::withdrawLiquidity` - tax bypassing mechanism 
	- In order to incentivise Locker owners to provide liquidity to the SUP/ETH pool, the lockers offer a feature to bypass exit tax when providing liquidity for over 6 months. eligible users will be able to withdraw (both ETH AND SUP) from there lockers after having LP'd for over 6 months.  They are able to decide which amount to withdraw instantly to their EOA - not withdrawing the complete position do not cancel the tax-free opportunity, users will still be able to withdraw the rest of their tax-free position later.

- `FluidLocker::collectFees` - accrued fees can be collected in Locker owner's EOA directly.

- `EPProgramManager.sol`: this contract will NOT be deployed. Only `FluidEPProgramManager.sol` is deployed and used in the production system.

- `SupVesting.sol` : This contract is meant to be used to distribute the SUP Token to investor and team members as part of a token vesting.
	- it is meant to be used for at most 50-100 recipients. We are aware that the `SupVestingFactory::totalSupply` function could malfunction in case there are a large number of recipients. This shall not be considered a valid issue.
___

### Q: Please provide links to previous audits (if any).
Previous Audit link can be found here : 
https://audits.sherlock.xyz/contests/648

___

### Q: Please list any relevant protocol resources.
Superfluid Docs : https://docs.superfluid.finance/

Superfluid SuperToken Docs : https://docs.superfluid.finance/docs/protocol/super-tokens/overview

Superfluid GDA Docs : https://docs.superfluid.finance/docs/protocol/distributions/overview

Uniswap V3 Docs : https://docs.uniswap.org/contracts/v3/overview

Stack Docs : https://docs.stack.so/overview 
___

### Q: Additional audit information.
It is suggested to look at the Uniswap related functions : 
- `FluidLocker::provideLiquidity`
- `FluidLocker::withdrawLiquidity`
- `FluidLocker::collectFees` 

We also encourage Watson to ensure that locker owners will not be able to bypass the tax mechanism (aside from the feature allowing it described above).

We highly encourage Watson to look at the `SupVesting` & `SupVestingFactory` contracts.

Please note that the audited scope is meant to be used to upgrade currently live production system.

Live contracts can be found at below addresses on BASE Mainnet : 

| Contract                        | Address                                    |
| ------------------------------- | ------------------------------------------ |
| SUPToken (SuperToken)           | 0xa69f80524381275A7fFdb3AE01c54150644c8792 |
| FluidEPProgramManager (Logic)   | 0xee117cD6F04FB85c5bb1bBeB59Bf1F9E16E05764 |
| FluidEPProgramManager (Proxy)   | 0x1e32cf099992E9D3b17eDdDFFfeb2D07AED95C6a |
| StakingRewardController (Logic) | 0x4f69302E435f6D6c9eD40719098B13265027D8C2 |
| StakingRewardController (Proxy) | 0xb19Ae25A98d352B36CED60F93db926247535048b |
| FluidLocker (Logic)             | 0x939659D22aC378426EdF5e71Fc9bD5B89065F8A4 |
| FluidLocker (Beacon)            | 0x664161f0974F5B17FB1fD3FDcE5D1679E829176c |
| Fontaine (Logic)                | 0xbFe2ceE2Cc266f26Aaf434Ef69e390FC2a0033fA |
| Fontaine (Beacon)               | 0xA26FbA47Da24F7DF11b3E4CF60Dcf7D1691Ae47d |
| FluidLockerFactory (Logic)      | 0xf6EED68979870941AEF88914534F67d06Ae15B80 |
| FluidLockerFactory (Proxy)      | 0xA6694cAB43713287F7735dADc940b555db9d39D9 |


# Audit scope

[fluid @ 6cb9f19564f1af239d18916e68eaa2a62597497a](https://github.com/superfluid-finance/fluid/tree/6cb9f19564f1af239d18916e68eaa2a62597497a)
- [fluid/packages/contracts/src/EPProgramManager.sol](fluid/packages/contracts/src/EPProgramManager.sol)
- [fluid/packages/contracts/src/FluidEPProgramManager.sol](fluid/packages/contracts/src/FluidEPProgramManager.sol)
- [fluid/packages/contracts/src/FluidLocker.sol](fluid/packages/contracts/src/FluidLocker.sol)
- [fluid/packages/contracts/src/FluidLockerFactory.sol](fluid/packages/contracts/src/FluidLockerFactory.sol)
- [fluid/packages/contracts/src/Fontaine.sol](fluid/packages/contracts/src/Fontaine.sol)
- [fluid/packages/contracts/src/StakingRewardController.sol](fluid/packages/contracts/src/StakingRewardController.sol)
- [fluid/packages/contracts/src/interfaces/IEPProgramManager.sol](fluid/packages/contracts/src/interfaces/IEPProgramManager.sol)
- [fluid/packages/contracts/src/interfaces/IStakingRewardController.sol](fluid/packages/contracts/src/interfaces/IStakingRewardController.sol)
- [fluid/packages/contracts/src/vesting/SupVesting.sol](fluid/packages/contracts/src/vesting/SupVesting.sol)
- [fluid/packages/contracts/src/vesting/SupVestingFactory.sol](fluid/packages/contracts/src/vesting/SupVestingFactory.sol)

[protocol-monorepo @ 413399318428a78ef869b0c79547692a85e7b61e](https://github.com/superfluid-org/protocol-monorepo/tree/413399318428a78ef869b0c79547692a85e7b61e)
- [protocol-monorepo/packages/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol](protocol-monorepo/packages/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol)
- [protocol-monorepo/packages/ethereum-contracts/contracts/utils/MacroForwarder.sol](protocol-monorepo/packages/ethereum-contracts/contracts/utils/MacroForwarder.sol)


