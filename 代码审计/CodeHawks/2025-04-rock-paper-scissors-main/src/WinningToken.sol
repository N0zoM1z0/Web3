// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WinningToken
 * @notice ERC20 token awarded to winners of Rock Paper Scissors games
 * @dev Can be used as entry fee for new games instead of ETH
 */
contract WinningToken is ERC20, ERC20Burnable, Ownable {
    /**
     * @dev Constructor initializes the token with name and symbol
     */
    constructor() ERC20("Rock Paper Scissors Winner Token", "RPSW") Ownable(msg.sender) {
        // No initial supply
    }

    /**
     * @dev Set the number of decimals for the token
     * @return The number of decimals (0 for non-divisible tokens)
     */
    function decimals() public view virtual override returns (uint8) {
        return 0; // Non-divisible tokens
    }

    /**
     * @dev Mint new tokens (only callable by owner)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
