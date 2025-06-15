## Lend

Lend is a cross-chain lending and borrowing protocol that builds on top of the innovations from the original Compound V2.

Lend uses LayerZero technology to communicate with multiple interconnected chains to enable users to borrow from any of the connected chains using the collateral from any source chain.

For example, user Bob could:

- Supply on Arbitrum, Borrow on Base
- Supply on Base, Borrow on Base
- Supply on Arbitrum, Borrow on Base, Borrow on Optimism

Chains communicate via ABA messaging patterns to ensure state is synced between both parties whenever a cross-chain action is initiated.

### Contract Scope

There are 3 core contracts that have been created anew:

| Contract Name        | Contract Description                                                                                         | Lines of Code |
| -------------------- | ------------------------------------------------------------------------------------------------------------ | ------------- |
| LendStorage.sol      | Responsible for storing all of the data associated with a specific chain.                                    | 439           |
| CoreRouter.sol       | Core router, interacted with directly by users, and responsible for initiating core actions on the protocol. | 281           |
| CrossChainRouter.sol | Secondary router, interacted with directly by users, for initiating cross-chain actions on the protocol.     | 544           |
| Total                |                                                                                                              | 1264          |
