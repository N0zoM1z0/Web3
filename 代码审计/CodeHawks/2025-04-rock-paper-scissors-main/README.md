# Rock Paper Scissors DApp

[//]: # (contest-details-open)

## About the Project

Rock Paper Scissors DApp is a fully decentralized implementation of the classic Rock Paper Scissors game on Ethereum. The protocol allows players to compete in a fair and transparent manner with bets placed in ETH or using special Winner Tokens.

Key features:

- Commit-reveal mechanism ensures fair play (no cheating)
- Support for both ETH and token-based games
- Multiple-turn matches with best-of-N scoring
- Automatic prize distribution and winner token rewards
- Timeout protection against non-responsive players

The smart contract system utilizes a commit-reveal pattern to prevent frontrunning and ensure players cannot see their opponent's move before committing their own.

## Contract Details

### Game Flow

1. Player A creates a game with ETH bet or token
2. Player B joins with matching bet
3. Both players commit hashed moves
4. Both players reveal moves
5. Winner is determined for current turn
6. Repeat 3-5 until all turns complete
7. Final winner receives prize and winner token

### Timeouts

- Join timeout: 24 hours by default
- Reveal timeout: Set when creating game (min 5 minutes)

### Fees

- 10% protocol fee on all ETH games
- No fees on token-only games

## Actors

- **Players**: Users who create or join games, commit and reveal moves, and participate in matches
- **Admin**: The protocol administrator who can update timeout parameters and withdraw accumulated fees
- **Contract Owner**: Initially the deployer of the contract, capable of setting a new admin

[//]: # (contest-details-close)

[//]: # (scope-open)

## Scope (contracts)

The following contracts are included in the project:

```
src/
├── RockPaperScissors.sol - Main game contract
└── WinningToken.sol - ERC20 token awarded to winners
```

## Compatibilities

**Blockchains:**

- Ethereum Mainnet
- All EVM-compatible chains

**Tokens:**

- ETH (for betting)
- RPSW (Rock Paper Scissors Winner Token) - internal ERC20 token

[//]: # (scope-close)

[//]: # (getting-started-open)

## Setup

### Build

```bash
# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts

# Build contracts
forge build
```

### Tests

```bash
# Run all tests
forge test

# Run tests with gas reporting
forge test --gas-report
```

### Deploy

```bash
# Deploy to local network
forge script scripts/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet (example for Goerli)
forge script scripts/Deploy.s.sol --rpc-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

[//]: # (getting-started-close)

[//]: # (known-issues-open)

## Known Issues

None Reported!

[//]: # (known-issues-close)
