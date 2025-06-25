# Symbiotic Relay contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the **Issues** page in your private contest repo (label issues as **Medium** or **High**)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Ethereum
BSC
Tron
Base
Arbitrum
Hyperliquid L1
Avalanche
Polygon
Berachain
Unichain
Sonic
Cronos
BSquared
Bitlayer
CORE
OP Mainnet
Hemi
Taiko
Gnosis
Mantle
Linea
Blast
Celo
ZKsync Era
Scroll
WorldChain
Swellchain
Manta
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of [weird tokens](https://github.com/d-xo/weird-erc20) you want to integrate?
The system is permissionless; the only limitation is rebasing tokens
___

### Q: Are there any limitations on values set by admins (or other roles) in the codebase, including restrictions on array lengths?
- Constructor inputs like NETWORK_REGISTRY, NETWORK_MIDDLEWARE_SERVICE and others mean Symbiotic core contracts deployment, and are considered to be correctly set up (e.g., using https://docs.symbiotic.fi/deployments/mainnet)
- Regarding permissions "inside" the network: In general, the system allows a high granularity of roles across all the contracts. However, the most important part to mention here is the `Settlement.setGenesis()` function with a needed permission, which ideally should be called only once at the start, as it can affect the validator set (which represents the network) and, hence, the network's decisions. 
- Regarding permissions in the sense of external parties: Basically, all the permissions directly or indirectly belong to the network, and in most cases, different setups mean different security assumptions inside its system (e.g., possible configurations are 1) all the actions are performed based on the majority decision, 2) fully controlled by the protocol's (network's) team). There are a couple of exceptions, such as "slasher" and "rewarder" addresses in `BaseSlashing` and `BaseRewards`, which affect the stakers directly and should be thoroughly considered by them.
___

### Q: Are there any limitations on values set by admins (or other roles) in protocols you integrate with, including restrictions on array lengths?
No, but it's important to mention that the code under the contest is an SDK, so the number of use-cases can be wide and, in the end, it is up to the user of this SDK (network/protocol) to decide on external trust assumptions (e.g., threre is shared vault with several stake consumers and with a custom route for slashed funds; it is up to the network if to consume the stake from this vault or not)
___

### Q: Is the codebase expected to comply with any specific EIPs?
No, the codebase only uses some subjects (ERC20, precompiles) from EIPs, but doesn't implement any
___

### Q: Are there any off-chain mechanisms involved in the protocol (e.g., keeper bots, arbitrage bots, etc.)? We assume these mechanisms will not misbehave, delay, or go offline unless otherwise specified.
There is an off-chain part of the Symbiotic Relay that implements the validator set usage itself, including message signing, maintenance of validator set headers (which represent the validator set itself) through epochs, and signature aggregations. Mainly, it consumes `VotingPowerProvider.getVotingPowers(At)()`, `KeyRegistry.getKeys(At)()`, all of the `ValSetDriver` functions for validator set derivation and futher interactions with `Settlement`, `EpochManager.getCurrentEpochStart()` (and other epochs-related functions), most functions from `Settlement` for synchronisations, commitments, and verifications. Example dependency on this off-chain part: if any validator set has committed a malicious header by its majority, it is acceptable from the on-chain side.
___

### Q: What properties/invariants do you want to hold even if breaking them has a low/unknown impact?
No
___

### Q: Please discuss any design choices you made.
- Each basic contract’s storage is located in an unstructured way, which allows for more convenient utilisation of them when developing a complete system (with proxies, non-standard storage layout schemes, etc)
- We aimed to find an ideal balance between development UX (e.g., through forcefully exposed to external environment functions), bytecode size limitations, and gas costs. Hence,
    - Most of the functionality is virtual, so it can be overridden/reused easily
    - In rare cases, we used external libraries to save bytecode, but implemented internal functions in the contracts which don’t increase bytecode when not used
- Most of the data regarding the middleware’s state is historical. This simplifies the implementation of the off-chain part.
___

### Q: Please provide links to previous audits (if any).
https://github.com/symbioticfi/middleware-sdk/blob/main/audits/Bailsec-RelaySmartContracts.pdf
___

### Q: Please list any relevant protocol resources.
https://docs.symbiotic.fi/

___

### Q: Additional audit information.
As is the default, a high severity issue is worth 5 times the value of a medium severity issue. To encourage placing more of an emphasis on the main scope, vulnerabilities found in the ZK and Network portions have a reduced weight. An issue in the ZK or Network portion will be worth 0.1x weight of a normal medium or high. This means a **Medium** issue in that area is worth a tenth of a Medium in the main scope.

For the [`circuit.go`](https://github.com/sherlock-audit/2025-06-symbiotic-relay/blob/main/middleware-sdk/pkg/proof/circuit.go) file, only the `func (circuit *Circuit) Define` is considered in-scope, while the function `func setCircuitData` is considered OOS and issues related to it will be considered invalid.


# Audit scope

[middleware-sdk @ 57f80a92a614f4df812cd0495e3b214bc5d954ec](https://github.com/symbioticfi/middleware-sdk/tree/57f80a92a614f4df812cd0495e3b214bc5d954ec)
- [middleware-sdk/examples/MyKeyRegistry.sol](middleware-sdk/examples/MyKeyRegistry.sol)
- [middleware-sdk/examples/MyNetwork.sol](middleware-sdk/examples/MyNetwork.sol)
- [middleware-sdk/examples/MySettlement.sol](middleware-sdk/examples/MySettlement.sol)
- [middleware-sdk/examples/MyValSetDriver.sol](middleware-sdk/examples/MyValSetDriver.sol)
- [middleware-sdk/examples/MyVotingPowerProvider.sol](middleware-sdk/examples/MyVotingPowerProvider.sol)
- [middleware-sdk/pkg/proof/circuit.go](middleware-sdk/pkg/proof/circuit.go)
- [middleware-sdk/src/contracts/libraries/keys/KeyBlsBn254.sol](middleware-sdk/src/contracts/libraries/keys/KeyBlsBn254.sol)
- [middleware-sdk/src/contracts/libraries/keys/KeyEcdsaSecp256k1.sol](middleware-sdk/src/contracts/libraries/keys/KeyEcdsaSecp256k1.sol)
- [middleware-sdk/src/contracts/libraries/sigs/SigBlsBn254.sol](middleware-sdk/src/contracts/libraries/sigs/SigBlsBn254.sol)
- [middleware-sdk/src/contracts/libraries/sigs/SigEcdsaSecp256k1.sol](middleware-sdk/src/contracts/libraries/sigs/SigEcdsaSecp256k1.sol)
- [middleware-sdk/src/contracts/libraries/structs/Checkpoints.sol](middleware-sdk/src/contracts/libraries/structs/Checkpoints.sol)
- [middleware-sdk/src/contracts/libraries/structs/PersistentSet.sol](middleware-sdk/src/contracts/libraries/structs/PersistentSet.sol)
- [middleware-sdk/src/contracts/libraries/utils/InputNormalizer.sol](middleware-sdk/src/contracts/libraries/utils/InputNormalizer.sol)
- [middleware-sdk/src/contracts/libraries/utils/KeyTags.sol](middleware-sdk/src/contracts/libraries/utils/KeyTags.sol)
- [middleware-sdk/src/contracts/libraries/utils/ValSetVerifier.sol](middleware-sdk/src/contracts/libraries/utils/ValSetVerifier.sol)
- [middleware-sdk/src/contracts/modules/base/NetworkManager.sol](middleware-sdk/src/contracts/modules/base/NetworkManager.sol)
- [middleware-sdk/src/contracts/modules/base/OzEIP712.sol](middleware-sdk/src/contracts/modules/base/OzEIP712.sol)
- [middleware-sdk/src/contracts/modules/base/PermissionManager.sol](middleware-sdk/src/contracts/modules/base/PermissionManager.sol)
- [middleware-sdk/src/contracts/modules/common/permissions/OzAccessControl.sol](middleware-sdk/src/contracts/modules/common/permissions/OzAccessControl.sol)
- [middleware-sdk/src/contracts/modules/common/permissions/OzAccessManaged.sol](middleware-sdk/src/contracts/modules/common/permissions/OzAccessManaged.sol)
- [middleware-sdk/src/contracts/modules/common/permissions/OzOwnable.sol](middleware-sdk/src/contracts/modules/common/permissions/OzOwnable.sol)
- [middleware-sdk/src/contracts/modules/key-registry/KeyRegistry.sol](middleware-sdk/src/contracts/modules/key-registry/KeyRegistry.sol)
- [middleware-sdk/src/contracts/modules/network/Network.sol](middleware-sdk/src/contracts/modules/network/Network.sol)
- [middleware-sdk/src/contracts/modules/settlement/Settlement.sol](middleware-sdk/src/contracts/modules/settlement/Settlement.sol)
- [middleware-sdk/src/contracts/modules/settlement/sig-verifiers/SigVerifierBlsBn254Simple.sol](middleware-sdk/src/contracts/modules/settlement/sig-verifiers/SigVerifierBlsBn254Simple.sol)
- [middleware-sdk/src/contracts/modules/settlement/sig-verifiers/SigVerifierBlsBn254ZK.sol](middleware-sdk/src/contracts/modules/settlement/sig-verifiers/SigVerifierBlsBn254ZK.sol)
- [middleware-sdk/src/contracts/modules/settlement/sig-verifiers/libraries/ExtraDataStorageHelper.sol](middleware-sdk/src/contracts/modules/settlement/sig-verifiers/libraries/ExtraDataStorageHelper.sol)
- [middleware-sdk/src/contracts/modules/valset-driver/EpochManager.sol](middleware-sdk/src/contracts/modules/valset-driver/EpochManager.sol)
- [middleware-sdk/src/contracts/modules/valset-driver/ValSetDriver.sol](middleware-sdk/src/contracts/modules/valset-driver/ValSetDriver.sol)
- [middleware-sdk/src/contracts/modules/voting-power/VotingPowerProvider.sol](middleware-sdk/src/contracts/modules/voting-power/VotingPowerProvider.sol)
- [middleware-sdk/src/contracts/modules/voting-power/base/VotingPowerCalcManager.sol](middleware-sdk/src/contracts/modules/voting-power/base/VotingPowerCalcManager.sol)
- [middleware-sdk/src/contracts/modules/voting-power/common/voting-power-calc/EqualStakeVPCalc.sol](middleware-sdk/src/contracts/modules/voting-power/common/voting-power-calc/EqualStakeVPCalc.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/BaseRewards.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/BaseRewards.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/BaseSlashing.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/BaseSlashing.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/MultiToken.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/MultiToken.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/OpNetVaultAutoDeploy.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/OpNetVaultAutoDeploy.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/OperatorVaults.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/OperatorVaults.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/OperatorsBlacklist.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/OperatorsBlacklist.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/OperatorsJail.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/OperatorsJail.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/OperatorsWhitelist.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/OperatorsWhitelist.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/SharedVaults.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/SharedVaults.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/logic/BaseRewardsLogic.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/logic/BaseRewardsLogic.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/logic/BaseSlashingLogic.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/logic/BaseSlashingLogic.sol)
- [middleware-sdk/src/contracts/modules/voting-power/extensions/logic/OpNetVaultAutoDeployLogic.sol](middleware-sdk/src/contracts/modules/voting-power/extensions/logic/OpNetVaultAutoDeployLogic.sol)
- [middleware-sdk/src/contracts/modules/voting-power/logic/VotingPowerProviderLogic.sol](middleware-sdk/src/contracts/modules/voting-power/logic/VotingPowerProviderLogic.sol)
- [middleware-sdk/src/interfaces/modules/base/INetworkManager.sol](middleware-sdk/src/interfaces/modules/base/INetworkManager.sol)
- [middleware-sdk/src/interfaces/modules/base/IOzEIP712.sol](middleware-sdk/src/interfaces/modules/base/IOzEIP712.sol)
- [middleware-sdk/src/interfaces/modules/base/IPermissionManager.sol](middleware-sdk/src/interfaces/modules/base/IPermissionManager.sol)
- [middleware-sdk/src/interfaces/modules/common/permissions/IOzAccessControl.sol](middleware-sdk/src/interfaces/modules/common/permissions/IOzAccessControl.sol)
- [middleware-sdk/src/interfaces/modules/common/permissions/IOzAccessManaged.sol](middleware-sdk/src/interfaces/modules/common/permissions/IOzAccessManaged.sol)
- [middleware-sdk/src/interfaces/modules/common/permissions/IOzOwnable.sol](middleware-sdk/src/interfaces/modules/common/permissions/IOzOwnable.sol)
- [middleware-sdk/src/interfaces/modules/key-registry/IKeyRegistry.sol](middleware-sdk/src/interfaces/modules/key-registry/IKeyRegistry.sol)
- [middleware-sdk/src/interfaces/modules/network/INetwork.sol](middleware-sdk/src/interfaces/modules/network/INetwork.sol)
- [middleware-sdk/src/interfaces/modules/network/ISetMaxNetworkLimitHook.sol](middleware-sdk/src/interfaces/modules/network/ISetMaxNetworkLimitHook.sol)
- [middleware-sdk/src/interfaces/modules/settlement/ISettlement.sol](middleware-sdk/src/interfaces/modules/settlement/ISettlement.sol)
- [middleware-sdk/src/interfaces/modules/settlement/sig-verifiers/ISigVerifier.sol](middleware-sdk/src/interfaces/modules/settlement/sig-verifiers/ISigVerifier.sol)
- [middleware-sdk/src/interfaces/modules/settlement/sig-verifiers/ISigVerifierBlsBn254Simple.sol](middleware-sdk/src/interfaces/modules/settlement/sig-verifiers/ISigVerifierBlsBn254Simple.sol)
- [middleware-sdk/src/interfaces/modules/settlement/sig-verifiers/ISigVerifierBlsBn254ZK.sol](middleware-sdk/src/interfaces/modules/settlement/sig-verifiers/ISigVerifierBlsBn254ZK.sol)
- [middleware-sdk/src/interfaces/modules/settlement/sig-verifiers/zk/IVerifier.sol](middleware-sdk/src/interfaces/modules/settlement/sig-verifiers/zk/IVerifier.sol)
- [middleware-sdk/src/interfaces/modules/valset-driver/IEpochManager.sol](middleware-sdk/src/interfaces/modules/valset-driver/IEpochManager.sol)
- [middleware-sdk/src/interfaces/modules/valset-driver/IValSetDriver.sol](middleware-sdk/src/interfaces/modules/valset-driver/IValSetDriver.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/IVotingPowerProvider.sol](middleware-sdk/src/interfaces/modules/voting-power/IVotingPowerProvider.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/base/IVotingPowerCalcManager.sol](middleware-sdk/src/interfaces/modules/voting-power/base/IVotingPowerCalcManager.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/common/voting-power-calc/IEqualStakeVPCalc.sol](middleware-sdk/src/interfaces/modules/voting-power/common/voting-power-calc/IEqualStakeVPCalc.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/IBaseRewards.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/IBaseRewards.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/IBaseSlashing.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/IBaseSlashing.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/IMultiToken.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/IMultiToken.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/IOpNetVaultAutoDeploy.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/IOpNetVaultAutoDeploy.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/IOperatorVaults.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/IOperatorVaults.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/IOperatorsBlacklist.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/IOperatorsBlacklist.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/IOperatorsJail.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/IOperatorsJail.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/IOperatorsWhitelist.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/IOperatorsWhitelist.sol)
- [middleware-sdk/src/interfaces/modules/voting-power/extensions/ISharedVaults.sol](middleware-sdk/src/interfaces/modules/voting-power/extensions/ISharedVaults.sol)


