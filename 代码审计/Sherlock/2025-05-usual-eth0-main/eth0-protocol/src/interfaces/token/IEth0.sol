// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IEth0 is IERC20Metadata {
    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when an address is blacklisted.
    /// @param account The address that was blacklisted.
    event Blacklist(address account);
    /// @notice Event emitted when an address is removed from blacklist.
    /// @param account The address that was removed from blacklist.
    event UnBlacklist(address account);

    /// @notice Event emitted when the mintcap is adjusted
    /// @param newMintCap The new mintCap for ETH0
    event MintCapUpdated(uint256 newMintCap);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by an account with the PAUSING_CONTRACTS_ROLE
    function pause() external;

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by an account with the UNPAUSING_CONTRACTS_ROLE
    function unpause() external;

    /// @notice mint Eth0 token
    /// @dev Can only be called by ETH0_MINT role;
    /// @dev Can only mint if enough ETH backing is available.
    /// @param to address of the account who want to mint their token
    /// @param amount the amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice burnFrom Eth0 token
    /// @dev Can only be called by ETH0_BURN role
    /// @param account address of the account who want to burn
    /// @param amount the amount of tokens to burn
    function burnFrom(address account, uint256 amount) external;

    /// @notice burn Eth0 token
    /// @dev Can only be called by ETH0_BURN role
    /// @param amount the amount of tokens to burn
    function burn(uint256 amount) external;

    /// @notice Set the mint cap for ETH0 tokens
    /// @dev Can only be called by MINT_CAP_OPERATOR role
    /// @param newMintCap The new mint cap value
    function setMintCap(uint256 newMintCap) external;

    /// @notice Get the current mint cap for ETH0 tokens
    /// @return The current mint cap value
    function getMintCap() external view returns (uint256);

    /// @notice blacklist an account
    /// @dev Can only be called by the BLACKLIST_ROLE
    /// @param account address of the account to blacklist
    function blacklist(address account) external;

    /// @notice unblacklist an account
    /// @dev Can only be called by the BLACKLIST_ROLE
    /// @param account address of the account to unblacklist
    function unBlacklist(address account) external;

    /// @notice check if the account is blacklisted
    /// @param account address of the account to check
    /// @return bool
    function isBlacklisted(address account) external view returns (bool);
}
