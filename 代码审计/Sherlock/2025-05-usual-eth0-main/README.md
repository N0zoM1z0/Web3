# Usual ETH0 contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Ethereum.
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
We are integrating wstETH as a first collateral and we expect future LST to also be accruing.
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
No.
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No.
___

### Q: Is the codebase expected to comply with any specific EIPs?
We do not consider compliance to EIP's relevant unless they pose an attack vector.
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
A Chainlink stETH/ETH Feed Monitoring Bot watches for extreme deviations and auto-pauses DaoCollateral if Lido is ever hacked, so we get black-swan protection without daily oracle freezes.
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
We can't have more ETH0 than the corresponding ETH value inside our treasury. 

ETH0 minting is not allowed if it is not backed by at least the same ETH amount of collateralTokens,

e.g. When assuming 1 eth == 1 $stEth then:
If ETH0 total supply is 10 we should have at least 10 $stETH worth of $wstETH in the collateral treasury as a condition to allow to mint more ETH0.


___

### Q: Please discuss any design choices you made.
* Fee calculation rounding favors users over the protocol, e.g. In the _calculateFee() function of the DaoCollateral contract we are rounding down.
* We use the on-chain wstETH → stETH → ETH rate because it is the source of truth for backing, immune to market noise, cheaper in gas, and follows Aave’s precedent.
* The DaoCollateral contract (and other contracts in the protocol) cache contract addresses from the registry during initialization but do not update these cached addresses when the registry is modified . It is a deliberate architectural choice that prioritizes gas efficiency over immediate registry synchronization.
* In case of protocol surplus(i.e because the price of wstETH would be accruing over time) if eth0.mintCap would block the minting of new ETH0 we will raise the mint cap.
* CollateralTokens are not removable by design, they can however be soft-removed by changing their pricefeed / upgrade.
* We are adding collateral tokens without explicit oracle validation because we validate everything before launch and test on tenderly.
___

### Q: Please provide links to previous audits (if any).
Given that the ETH0 Protocol is significantly derived by the Usual RWA Protocol, the previous audit will give a lot of pointers.

https://github.com/sherlock-audit/2025-02-usual-labs-judging
___

### Q: Please list any relevant protocol resources.
Architecture Diagram: https://miro.com/app/board/uXjVIuuLLKQ=/?share_link_id=797555527778

On the Usual CollateralProtocol itself: https://tech.usual.money/ 



___

### Q: Additional audit information.
Overview
ETH0 is an ETH-pegged synthetic token fully collateralized by wrapped staked ETH (wstETH) as the first collateralToken. The ETH0 Beta adapts Usual Protocol's existing architecture—originally designed for USD0 and backed by RWA tokens—to an ETH-denominated collateral model using wstETH as the first collateralToken. ETH0 tokens maintain a 1:1 peg to ETH through controlled minting, redeeming, and robust oracle management. 

Key features of the ETH0 Beta:

- Minting and redeeming ETH0 using wstETH collateral 

- Price oracle integration for collateral valuation

- Upgradeable contract architecture

- Role-based access control

- Emergency pause/unpause mechanisms

- Diverted from default admin role usage compared to Usual Protocol V1	

Tokenmapping.sol, ClassicalOracle/Abstract Oracle and Utils are very close to the existing code of the Usual Protocol except for changes in copywriting ( i.e. USD -> ETH denomination).



# Audit scope

[eth0-protocol @ 8e7005f055f892827f91a1847e9497dd69c453c6](https://github.com/usual-dao/eth0-protocol/tree/8e7005f055f892827f91a1847e9497dd69c453c6)
- [eth0-protocol/src/TokenMapping.sol](eth0-protocol/src/TokenMapping.sol)
- [eth0-protocol/src/constants.sol](eth0-protocol/src/constants.sol)
- [eth0-protocol/src/daoCollateral/DaoCollateral.sol](eth0-protocol/src/daoCollateral/DaoCollateral.sol)
- [eth0-protocol/src/errors.sol](eth0-protocol/src/errors.sol)
- [eth0-protocol/src/interfaces/IDaoCollateral.sol](eth0-protocol/src/interfaces/IDaoCollateral.sol)
- [eth0-protocol/src/interfaces/IWstETH.sol](eth0-protocol/src/interfaces/IWstETH.sol)
- [eth0-protocol/src/interfaces/oracles/AggregatorV3Interface.sol](eth0-protocol/src/interfaces/oracles/AggregatorV3Interface.sol)
- [eth0-protocol/src/interfaces/oracles/IAggregator.sol](eth0-protocol/src/interfaces/oracles/IAggregator.sol)
- [eth0-protocol/src/interfaces/oracles/IDataPublisher.sol](eth0-protocol/src/interfaces/oracles/IDataPublisher.sol)
- [eth0-protocol/src/interfaces/oracles/IOracle.sol](eth0-protocol/src/interfaces/oracles/IOracle.sol)
- [eth0-protocol/src/interfaces/registry/IRegistryAccess.sol](eth0-protocol/src/interfaces/registry/IRegistryAccess.sol)
- [eth0-protocol/src/interfaces/registry/IRegistryContract.sol](eth0-protocol/src/interfaces/registry/IRegistryContract.sol)
- [eth0-protocol/src/interfaces/token/IEth0.sol](eth0-protocol/src/interfaces/token/IEth0.sol)
- [eth0-protocol/src/interfaces/tokenManager/ITokenMapping.sol](eth0-protocol/src/interfaces/tokenManager/ITokenMapping.sol)
- [eth0-protocol/src/oracles/AbstractOracle.sol](eth0-protocol/src/oracles/AbstractOracle.sol)
- [eth0-protocol/src/oracles/ClassicalOracle.sol](eth0-protocol/src/oracles/ClassicalOracle.sol)
- [eth0-protocol/src/oracles/LidoWstEthOracle.sol](eth0-protocol/src/oracles/LidoWstEthOracle.sol)
- [eth0-protocol/src/registry/RegistryAccess.sol](eth0-protocol/src/registry/RegistryAccess.sol)
- [eth0-protocol/src/registry/RegistryContract.sol](eth0-protocol/src/registry/RegistryContract.sol)
- [eth0-protocol/src/token/Eth0.sol](eth0-protocol/src/token/Eth0.sol)
- [eth0-protocol/src/utils/CheckAccessControl.sol](eth0-protocol/src/utils/CheckAccessControl.sol)
- [eth0-protocol/src/utils/normalize.sol](eth0-protocol/src/utils/normalize.sol)


