# RustFund


### Details

- Starts: March 20, 2025 Noon UTC
- Ends: March 27, 2025 Noon UTC

- nSLOC: 170

[//]: # (contest-details-open)

## About the Project

RustFund is a decentralized crowdfunding platform built on the Solana blockchain It enables creators to launch fundraising campaigns and contributors to support projects they believe in, all in a trustless and transparent manner.

### Features 
+ **Create Fundraising Campaigns:** Creators can launch campaigns with custom names, descriptions, and funding goals
+ **Contribute to Projects:** Users can contribute SOL to any active campaign
+ **Refund Mechanism:** Contributors can get refunds if deadlines are reached and goals aren't met
+ **Secure Withdrawals:** Creators can withdraw funds once their campaign succeeds

## Actors

### Creator
+ Creates new fundraising campaigns
+ Sets campaign deadline
+ Withdraws raised funds after successful campaigns
+ Has exclusive rights to manage their campaign settings
### Contributor
+ Contributes SOL to campaigns
+ Can request refunds under if the campaign fails to meet the goal and the deadline is reached

[//]: # (contest-details-close)

[//]: # (scope-open)

## Scope (contracts)


```js
src/
├── lib.rs

```

## Compatibilities


  ### Blockchains:
+ Solana

###  **Tokens:**
+ SOL


[//]: # (scope-close)

[//]: # (getting-started-open)

## Setup

### Prerequisites
+ [Rust](https://www.rust-lang.org/tools/install)
+ [Anchor CLI](https://www.anchor-lang.com/docs/installation)
+ [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools)
+ [Node.js](https://nodejs.org/en/download/)
+ [Yarn](https://classic.yarnpkg.com/lang/en/docs/install/#debian-stable)


### Build:
```bash
anchor build
```

### Test:
```bash
yarn install 
anchor test
```

[//]: # (getting-started-close)

[//]: # (known-issues-open)

## Known Issues
None!

[//]: # (known-issues-close)
