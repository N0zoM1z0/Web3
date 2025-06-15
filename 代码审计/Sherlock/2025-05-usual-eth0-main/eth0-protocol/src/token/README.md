# ETH0

## High-Level Overview

This section provides an overview of the ETH0 smart contract. The ETH0 contract is designed to manage a ETH0 ERC20 Token, implementing functionalities for minting, burning, and transfer operations while incorporating blacklist checks to restrict these operations to authorized addresses.

## Contract Summary

ETH0 is an ERC-20 compliant token that integrates additional security and access control features to enhance its governance and usability. It inherits functionalities from ERC20PausableUpgradable and ERC20PermitUpgradeable to support permit-based approvals and pausability.

### Inherited Contracts

- **ERC20PausableUpgradeable**: Extends ERC20 to support pausability
- **ERC20PermitUpgradeable**: Extends ERC20 to support gasless transactions through signed approvals.

### ERC20PausableUpgradeable

Standard OpenZeppelin Implementation.

### ERC20PermitUpgradeable

Standard OpenZeppelin Implementation.

## Functionality Breakdown

### Key Functionalities

- **Minting**: Tokens can be minted to an address, subject to role checks.
- **Burning**: Tokens can be burned from an address, also subject to role checks.
- **Transfers**: Only not blacklisted addresses can send or receive tokens.

## Functions Description

### Public/External Functions

- **pause()**: Pauses all token transfer operations; callable only by the [PAUSING_CONTRACTS_ROLE](#constants).
- **unpause()**: Resumes all token transfer operations; callable only by the [DEFAULT_ADMIN_ROLE](#constants).
- **transfer(address to, uint256 amount)**: Transfers tokens to a non-blacklisted address.
- **transferFrom(address sender, address to, uint256 amount)**: Transfers tokens from one non-blacklisted address to another.
- **mint(address to, uint256 amount)**: Mints tokens to a non-blacklisted address if the caller has the [ETH0_MINT](#constants) role.
- **burn(uint256 amount)** and **burnFrom(address account, uint256 amount)**: Burns tokens from an address, requiring the [ETH0_BURN](#constants) role.
- **burnFrom(address account, uint256 amount)**: Burns tokens from an address, requiring the [ETH0_BURN](#constants) role.
- **blacklist(address account)** and **unBlacklist(address account)**: Those functions allows the admin to blacklist or remove from blacklist malicious users from using this token. Only callable by the [BLACKLIST_ROLE](#constants).
- **setMintCap(uint256 amount)**: Sets the mint cap amount. Only callable by the [MINT_CAP_OPERATOR](#constants).
- **getMintCap()**: Returns the mint cap for an address. 


## Constants

- **CONTRACT_REGISTRY_ACCESS**: This constant is used to define the address of the registry access contract
- **DEFAULT_ADMIN_ROLE**: This constant is used to define the default admin role for the contract.
- **PAUSING_CONTRACTS_ROLE**: Role required to pause the contract.
- **BLACKLIST_ROLE**: Role required to blacklist an address.
- **MINT_CAP_OPERATOR**: Role required to set the mint cap.
- **ETH0_MINT**: Role required to mint new tokens.
- **ETH0_BURN**: Role required to burn tokens.

## Safeguards Implementation

- **Pausability**: Ensures that token transfers can be halted in case of emergency.
- **Role-Based Access Control**: Restricts sensitive actions to addresses with appropriate roles.
- **Blacklist Enforcement**: Ensures that only non-malicious addresses can participate in the token economy.

## Possible Attack Vectors

- **Reentrancy on minting and burning**: Although not directly vulnerable, external calls should be monitored.
- **Denial of Service by blocking blacklist management**: If the admin key is compromised.

## Potential Risks

- **Centralization of Control**: Heavy reliance on admin roles for critical functionality.
- **Smart Contract Bugs**: In complex interactions with inherited contracts and role management.

## Potential Manipulations

- **Blacklist Manipulation**: An admin with the [BLACKLIST_ROLE](#constants) could potentially manipulate the blacklist to exclude legitimate users or include malicious users.

## Conclusion

The ETH0 contract is structured with security features for role management and blacklisting. However, centralization risks and potential administrative overreach should be mitigated through additional safeguards and decentralization of control where possible.

# ETH0PP

## **High-Level Overview**

This smart contract is designed to manage bond-like financial instruments for the UsualDAO ecosystem. It provides functionality for minting, burning transferring, and setting a mint cap. The contract is built to comply with ERC20 standards and includes security features to prevent common vulnerabilities.

## **Contract Summary**

The contract provides a robust bond management system. It inherits from ERC20PermitUpgradeable for token permit functionality .

## **Inherited Contracts**

- **ERC20PausableUpgradeable**: Allows authorized addresses to pause all contract functionalities in case of an emergency.
- **ERC20PermitUpgradeable**: This contract provides token permit functionality, allowing users to permit other addresses to spend their tokens.
- **IEth0**: This is the interface contract that defines the functions and events for the ETH0 token.

## **Functionality Breakdown**

The contract flow begins with the initialization of the related registry and token information. Eth0 can be minted, burned and transferred. The minting process is capped to prevent excessive minting, and the contract can be paused or unpaused by authorized addresses. The cap is set to zero after initialization. The minting is prevented if the backing collateral is not enough. 

## **Functions Description**

### **Public/External Functions (non-view / non-pure)**

- **initialize(address registryContract, string memory name*, string memory symbol*)**: This function initializes the contract with related registry and token information.
- **pause()**: Pauses all token transfer operations; callable only by the [PAUSING_CONTRACTS_ROLE](#constants).
- **unpause()**: Resumes all token transfer operations; also callable only by the [DEFAULT_ADMIN_ROLE](#constants).
- **mint(address to, uint256 amount)**: This function mints new ETH0. It takes two parameters, the address to mint to and the amount to mint. The function checks if the caller has the [ETH0_MINT](#constants) role and if the amount is less than or equal to the mint cap. If there is not enough backing collateral, the function will revert.
- **mintWithPermit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)**: This function mints new ETH0 with a permit signature.
- **transfer(address recipient, uint256 amount)**: This function transfers ETH0 from the sender to the recipient.
- **transferFrom(address sender, address recipient, uint256 amount)**: This function transfers ETH0 from the sender to the recipient on behalf of the sender.
- ** burn(uint256 amount)**: This function burns ETH0 from the sender's address.
- **burnFrom(address account, uint256 amount)**: This function burns ETH0 from the specified address.
- **setMintCap(uint256 amount)**: This function sets the mint cap for the contract. It can only be called by the [MINT_CAP_OPERATOR](#constants).
- **getMintCap()**: This function returns the mint cap for the contract.

## **Constants **

- **DEFAULT_ADMIN_ROLE**: This constant is used to define the default admin role for the contract.
- **PAUSING_CONTRACTS_ROLE**: Role required to pause the contract.
- **CONTRACT_ETH0**: This constant is used to define the address of the ETH0 contract.
- **CONTRACT_REGISTRY_ACCESS**: This constant is used to define the address of the registry access contract.
- ** MINT_CAP_OPERATOR**: Role required to set the mint cap.
- **ETH0_MINT**: Role required to mint new tokens.
- **ETH0_BURN**: Role required to burn tokens.
- **BLACKLIST_ROLE**: Role required to blacklist an address.

## **Safeguards Implementation**
 
- **SafeERC20**: This library is used for safe token transfers, preventing loss of tokens due to incorrect contract behavior.
- **Check-Effects-Interactions Pattern**: This pattern is implemented to prevent reentrancy attacks. State changes are made before external calls, ensuring that the contract's state is updated before any external interaction.

## **Possible Attack Vectors**

- **Reentrancy on mint function**: There is a potential for attackers to re-enter the mint function before it completes, leading to unauthorized ETH0 minting.
- **Denial of Service by blocking minting**: If the admin key is compromised, the contract can be paused, preventing all minting and transfer operations.


## **Potential Risks**

- **Smart Contract Bugs**: The contract is complex and interacts with multiple inherited contracts, which increases the risk of bugs or vulnerabilities.
- **Upgradeability**: The contract is upgradeable, which introduces the risk of unintended behavior if future upgrades are not properly tested and implemented.
- **Blacklisting**: The contract allows for blacklisting of addresses, which could be abused by the admin to prevent legitimate users from accessing their tokens.

