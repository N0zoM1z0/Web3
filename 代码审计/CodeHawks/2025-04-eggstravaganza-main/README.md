# EggHuntGame: Eggstravaganza NFT Hunt

<br/>
<p align="center">
<img src="./logo.png" width="500" alt="EggHuntGame">
</p>
<br/>

# Contest Details

### Prize Pool

- High - 100xp
- Medium - 20xp
- Low - 2xp

- Starts: TBD
- Ends: TBD

### Stats

- nSLOC: 129
- Complexity Score: Moderate

[//]: # (contest-details-open)

## About the Project

```
About

EggHuntGame is a gamified NFT experience where participants search for hidden eggs to mint unique Eggstravaganza Egg NFTs.
Players engage in an interactive hunt during a designated game period, and successful egg finds can be deposited into a secure Egg Vault.
```

[Documentation](#) • [Website](#) • [Twitter](#) • [GitHub](#)

## Actors

```
Actors:
    Game Owner: The deployer/administrator who starts and ends the game, adjusts game parameters, and manages ownership.
    Player: Participants who call the egg search function, mint Egg NFTs upon successful searches, and may deposit them into the vault.
    Vault Owner: The owner of the EggVault contract responsible for managing deposited eggs.
```

[//]: # (contest-details-close)

[//]: # (scope-open)

## Scope (contracts)

```
All contracts in the `src` directory are in scope.
```

```js
src/
├── EggHuntGame.sol       // Main game contract managing the egg hunt lifecycle and minting process.
├── EggVault.sol          // Vault contract for securely storing deposited Egg NFTs.
└── EggstravaganzaNFT.sol // ERC721-style NFT contract for minting unique Egg NFTs.
```

## Compatibilities

```
Compatibilities:
  Blockchains:
      - Ethereum / Any EVM-compatible chain
  Tokens:
      - Custom ERC721 EggstravaganzaEggNFT tokens
```

[//]: # (scope-close)

[//]: # (getting-started-open)

## Setup

### Build

```bash
forge build
```

### Deployment

1. **Deploy EggstravaganzaEggNFT Contract:**  
   This contract handles the minting of unique Egg NFTs.
2. **Deploy EggVault Contract:**  
   Acts as the secure vault for storing Egg NFTs.
3. **Deploy EggHuntGame Contract:**  
   Initialize by passing in the deployed addresses of the Egg NFT and Egg Vault contracts.
4. **Set Ownership:**  
   Ensure the deployer (or designated admin) holds ownership to manage game functions.

### Running Tests

```bash
forge test
```

[//]: # (getting-started-close)

[//]: # (known-issues-open)

None Reported!

[//]: # (known-issues-close)
