# Scripts Usage

This repository contains various scripts located in the `script` folder that facilitate interaction with the smart contracts deployed on the blockchain. Below is a brief overview of the available scripts and their usage.

## Anvil Usage

The scripts are designed to work seamlessly with Anvil, a local Ethereum development environment. To run the scripts, ensure that Anvil is running and your environment is properly configured.

```bash
anvil
```

## Deploying the Contracts

```bash
forge script script/utils/Deploy.s.sol: --rpc-url http://localhost:8545 --broadcast
```

## Environment Variables

The scripts utilize a `.env` file for configuration. Make sure to set the following environment variables in your `.env` file:

-   `DEPLOYER_PUBLIC_KEY`: The public key of the deployer account.
-   `DEPLOYER_PRIVATE_KEY`: The private key of the deployer account.
