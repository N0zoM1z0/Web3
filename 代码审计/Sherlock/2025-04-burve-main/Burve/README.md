# Burve Protocol

[![License: BUSL-1.1](https://img.shields.io/badge/License-BUSL--1.1-blue.svg)](https://github.com/Uniswap/v3-core/blob/main/LICENSE)

Burve is a next-generation decentralized exchange protocol that implements advanced automated market making functionality using a diamond proxy pattern for upgradability and modularity.

## Overview

Burve Protocol introduces a novel approach to decentralized trading with the following key features:

-   **Diamond Proxy Architecture**: Utilizes the Diamond standard (EIP-2535) for modular and upgradeable smart contracts
-   **Advanced AMM Logic**: Implements sophisticated automated market making algorithms for efficient trading
-   **Multi-Token Support**: Handles multiple token pairs with optimized liquidity management
-   **Flexible Swapping**: Provides precise control over trades with customizable price limits
-   **Secure Liquidity Provision**: Robust mechanisms for adding and removing liquidity

## Architecture

The protocol is built using a modular architecture with the following main components:

### Core Facets

-   **SwapFacet**: Handles token swap operations with customizable parameters
-   **LiqFacet**: Manages liquidity provision and removal
-   **SimplexFacet**: Implements simplex-based calculations
-   **EdgeFacet**: Manages token pair relationships and pricing
-   **ViewFacet**: Provides view functions for protocol state

## Getting Started

### Prerequisites

-   [Foundry](https://github.com/foundry-rs/foundry)
-   Solidity ^0.8.27

### Installation

1. Clone the repository:

```bash
git clone [https://github.com/itos-finance/Burve](https://github.com/itos-finance/Burve)
cd Burve
```

2. Install dependencies:

```bash
forge install
```

3. Build the project:

```bash
forge build
```

### Testing

Run the test suite:

```bash
forge test
```

### Verification

```bash
forge verify-contract --chain-id 1 --etherscan-api-key <your_etherscan_api_key> --constructor-args <constructor_args> <contract_address> <contract_source_path>
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Documentation

For detailed documentation about the protocol's architecture and usage, please visit our [documentation site](https://docs.hyperplex.xyz).

## Contact

-   Website: [https://www.hyperplex.xyz/](https://www.hyperplex.xyz/)
-   Twitter: [@Hyperplex_xyz](https://twitter.com/Hyperplex_xyz)
-   Discord: [Burve Community](https://discord.gg/radbcrYT)

## Deployment

### Prerequisites

1. Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install dependencies:

```bash
forge install
```

3. Create a `.env` file with your deployment private key:

```bash
DEPLOYER_PRIVATE_KEY=your_private_key_here
```

### Deploy Contracts

#### Local Development with Anvil

1. Start Anvil local testnet:

```bash
anvil
```

2. Use Anvil's default account (no need to set DEPLOYER_PRIVATE_KEY):

```bash
# Deploy using Anvil's default account
forge script script/Deploy.s.sol:DeployBurve --rpc-url http://localhost:8545 --broadcast
```

#### Testnet/Mainnet Deployment

For deploying to actual networks, set your deployer key:

```bash
export DEPLOYER_PRIVATE_KEY=your_private_key_here
forge script script/Deploy.s.sol:DeployBurve --rpc-url your_rpc_url --broadcast --verify
```

This will:

1. Deploy mock tokens (USDC, USDT, DAI, WETH)
2. Deploy mock vaults for each token
3. Deploy the Burve Diamond contract with all facets
4. Set up edges between all token pairs
5. Create LP tokens for all valid token combinations
6. Save all deployed addresses to `deployed_addresses.json`

### Using the Protocol

After deployment, you can use the following utility scripts to interact with the protocol:

#### Local Testing with Anvil

When testing locally with Anvil, you don't need to set the DEPLOYER_PRIVATE_KEY as it will use Anvil's default account:

```bash
# Example for adding liquidity locally
export CLOSURE_ID=1
export AMOUNT=1000000
forge script script/utils/AddLiquidity.s.sol:AddLiquidity --rpc-url http://localhost:8545 --broadcast

# Example for swapping locally
export IN_TOKEN=<address from deployed_addresses.json>
export OUT_TOKEN=<address from deployed_addresses.json>
export AMOUNT=1000
forge script script/utils/Swap.s.sol:Swap --rpc-url http://localhost:8545 --broadcast
```

#### Adding Liquidity

```bash
# Set environment variables
export CLOSURE_ID=1  # The closure ID you want to add liquidity to
export AMOUNT=1000000  # Amount of each token to add (in token decimals)
export RECIPIENT=0x...  # Optional: Address to receive LP tokens (defaults to sender)

# Run the script
forge script script/utils/AddLiquidity.s.sol:AddLiquidity --rpc-url your_rpc_url --broadcast
```

#### Removing Liquidity

```bash
# Set environment variables
export CLOSURE_ID=1  # The closure ID you want to remove liquidity from
export SHARES=1000  # Number of LP shares to burn
export RECIPIENT=0x...  # Optional: Address to receive tokens (defaults to sender)

# Run the script
forge script script/utils/RemoveLiquidity.s.sol:RemoveLiquidity --rpc-url your_rpc_url --broadcast
```

#### Performing Swaps

```bash
# Set environment variables
export IN_TOKEN=0x...  # Address of input token
export OUT_TOKEN=0x...  # Address of output token
export AMOUNT=1000  # Positive for exact input, negative for exact output
export SQRT_PRICE_LIMIT=0  # Optional: Price limit for the swap
export RECIPIENT=0x...  # Optional: Address to receive output tokens (defaults to sender)

# Run the script
forge script script/utils/Swap.s.sol:Swap --rpc-url your_rpc_url --broadcast
```

### Contract Architecture

The system uses a Diamond proxy pattern with the following facets:

-   `LiqFacet`: Handles liquidity addition and removal
-   `SwapFacet`: Handles token swaps
-   `EdgeFacet`: Manages edge parameters between token pairs
-   `SimplexFacet`: Core simplex functionality and admin operations
-   `ViewFacet`: Read-only view functions

### Post-Deployment

After deployment:

1. The mock tokens will need to be minted to users for testing
2. Users will need to approve the Diamond contract to spend their tokens
3. LP tokens will be automatically created for all valid token combinations

### Contract Verification

The deployment script includes verification flags. Make sure your block explorer API key is set in the environment:

```bash
export ETHERSCAN_API_KEY=your_api_key_here
```

## Development

### Testing

Run the test suite:

```bash
forge test
```

Run with gas reporting:

```bash
forge test --gas-report
```

### Local Testing

For local testing with a fork of mainnet:

```bash
forge script script/Deploy.s.sol:DeployBurve --fork-url your_archive_node_url
```

## License

The primary license for Burve Protocol is the Business Source License 1.1 (BUSL-1.1), see [LICENSE](LICENSE). However, some files have different licenses:

### MIT License

-   `src/FullMath.sol` is licensed under MIT (as indicated in its SPDX header)

### Test Files

All files in the `test/` directory are UNLICENSED (as indicated in their SPDX headers).
