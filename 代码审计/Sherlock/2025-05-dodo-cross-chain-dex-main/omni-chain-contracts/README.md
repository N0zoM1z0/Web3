# ZetaChain Cross-Chain DEX

This project is a cross-chain DEX, supporting both same-chain and cross-chain swaps. It integrates DODO Router for efficient on-chain liquidity routing and leverages ZetaChain’s cross-chain infrastructure to enable secure and seamless asset swaps across multiple blockchains.

## Documentation

https://www.zetachain.com/docs/

## Usage

### Build

```shell
$ forge build
```

### Test
**The test contains contracts deployed on ZetaChain mainnet, please run tests with <ZETACHAIN_RPC_URL>**

```shell
$ forge test --fork-url https://zetachain-evm.blockpi.network/v1/rpc/public
```
