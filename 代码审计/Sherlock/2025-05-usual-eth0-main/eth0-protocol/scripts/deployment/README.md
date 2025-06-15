# Usual Smart Contracts Deployment Guide

This directory contains scripts for upgrading the Usual Smart Contracts on Ethereum Mainnet and on the virtual testnet provided by Tenderly.

## Tenderly Mainnet Fork Upgrade Guide

 
By following these steps, you can deploy the upgrade on the Ethereum mainnet with confidence.

### 1. **Create a Mainnet Fork on Tenderly**

- Log in to your [Tenderly](https://tenderly.co/) account.
- Navigate to the "Forks" section and create a new fork of the Ethereum mainnet.
- Copy the admin fork URL provided by Tenderly.

### 2. **Seed the Deployer Address And Dev. Team**

- start the script with the admin fork url.

```sh
forge clean && forge script scripts/deployment/YOUR_SCRIPT.s.sol -f <YOUR_ADMIN_RPC_URL> --broadcast --slow --unlocked

```
 
 
### Code and Bytecode verification (optional)

- Verify that the source code of the new implementation contract matches the source code on etherscan. If not you can use the forge verify-code command to verify the code.

```sh
forge verify-code --rpc-url <RPC_URL> --etherscan-api-key <KEY>  <CONTRACT_ADDRESS_TO_VERIFY> <path>:<contractname> --watch
```

- Verify that the bytecode of the new implementation contract matches the bytecode on etherscan.

```sh
forge verify-bytecode --rpc-url <RPC_URL> --etherscan-api-key <KEY>  <CONTRACT_ADDRESS_TO_VERIFY> <path>:<contractname>
```

- Verify that the upgraded contracts are functioning as expected.
- Perform any additional tests to ensure the stability and correctness of the deployment.
