// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";

import "./interfaces/ILendingPool.sol";

/// @title yToken
/// Forked from ExtraFinance

contract yToken is ReentrancyGuard, ERC20 {
    using SafeERC20 for IERC20;

    address public immutable lendingPool;
    address public immutable underlyingAsset;

    uint8 private _decimals;

    modifier onlyLendingPool() {
        require(msg.sender == lendingPool, "unauthorized");
        _;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address underlyingAsset_)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;

        require(underlyingAsset_ != address(0), "underlyingAsset can't be address(0)");
        underlyingAsset = underlyingAsset_;
        lendingPool = msg.sender;
    }

    /// @notice Mints an amount of yToken to `user`
    /// @param user The address receiving the minted tokens
    /// @param amount The amount of tokens getting minted
    function mint(address user, uint256 amount) external onlyLendingPool nonReentrant {
        _mint(user, amount);
    }

    /// @param receiverOfUnderlying The address that will receive the underlying tokens
    /// @param yTokenAmount The amount of eTokens being burned
    /// @param underlyingTokenAmount The amount of underlying tokens being transferred to user
    function burn(address receiverOfUnderlying, uint256 yTokenAmount, uint256 underlyingTokenAmount)
        external
        onlyLendingPool
        nonReentrant
    {
        _burn(msg.sender, yTokenAmount);

        IERC20(underlyingAsset).safeTransfer(receiverOfUnderlying, underlyingTokenAmount);
    }

    /// @notice Transfers underlying tokens to `target`
    /// @param target The recipient of the eTokens
    /// @param amount The amount getting transferred
    function transferUnderlyingTo(address target, uint256 amount)
        external
        onlyLendingPool
        nonReentrant
        returns (uint256)
    {
        IERC20(underlyingAsset).safeTransfer(target, amount);
        return amount;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
