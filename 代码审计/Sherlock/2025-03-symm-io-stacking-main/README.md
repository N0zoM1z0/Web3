# Symmio, Staking and Vesting contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Base
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
Only whitelisted tokens can work with the codebase, and these include stable-coins such as USDC, USDT, and USDE and Tokens like SYMM.
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
All restricted roles are trusted. For example, in the staking contract, the number of reward tokens will not exceed 10–20.
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No
___

### Q: Is the codebase expected to comply with any specific EIPs?
EIP-1967
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
No
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
No
___

### Q: Please discuss any design choices you made.
In the staking contract, if no tokens are staked, rewards will not be distributed, nor will they be carried forward to the next phase of distribution. In such scenarios, the admin will withdraw those rewards and redistribute them into the staking contract once some tokens are staked. Additionally, the vesting contract will interact with Balancer V3 pools to add liquidity to the 80-20 SYMM-USDC pool.
___

### Q: Please provide links to previous audits (if any).
There has been no prior audit.
___

### Q: Please list any relevant protocol resources.
https://github.com/SYMM-IO/token/blob/main/contracts/staking/README.md
https://github.com/SYMM-IO/token/blob/main/contracts/vesting/README.md
https://docs.balancer.fi/
https://docs.symmio.foundation/token-related/tokenomics/staking-program
https://docs.symmio.foundation/token-related/tokenomics/vesting-and-early-unlock
___

### Q: Additional audit information.
We need to identify any vulnerabilities that could allow attackers to drain the contracts or disrupt the system's functionality in any way.


# Audit scope

[token @ 1d014156b1d9f0ab3259026127b9220eb2da3292](https://github.com/SYMM-IO/token/tree/1d014156b1d9f0ab3259026127b9220eb2da3292)
- [token/contracts/staking/SymmStaking.sol](token/contracts/staking/SymmStaking.sol)
- [token/contracts/vesting/SymmVesting.sol](token/contracts/vesting/SymmVesting.sol)
- [token/contracts/vesting/Vesting.sol](token/contracts/vesting/Vesting.sol)
- [token/contracts/vesting/interfaces/IMintableERC20.sol](token/contracts/vesting/interfaces/IMintableERC20.sol)
- [token/contracts/vesting/interfaces/IPermit2.sol](token/contracts/vesting/interfaces/IPermit2.sol)
- [token/contracts/vesting/interfaces/IPool.sol](token/contracts/vesting/interfaces/IPool.sol)
- [token/contracts/vesting/interfaces/IRouter.sol](token/contracts/vesting/interfaces/IRouter.sol)
- [token/contracts/vesting/libraries/LibVestingPlan.sol](token/contracts/vesting/libraries/LibVestingPlan.sol)


