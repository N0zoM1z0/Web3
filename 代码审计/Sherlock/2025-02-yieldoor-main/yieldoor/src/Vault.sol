// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IVault} from "./interfaces/IVault.sol";

contract Vault is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice The address of the first token in the Vault
    address public token0;

    /// @notice The address of the second token in the Vault
    address public token1;

    /// @notice The strategy used by this Vault
    address public strategy;

    /// @notice The burn address. 1000 wei are minted to it upon first deposit.
    address constant BURN = address(1337);

    /// @notice The deposit fee that is charged. This will most likely always be set to 0.
    /// @notice Will only be set to 0.01% if griefers spam deposit/ withdraws to remove liquidity from the positions
    uint256 public depositFee;

    /// @notice Sets the tokens used within the vault.
    /// @param _token0 The address of the first token in the Vault
    /// @param _token1 The address of the second token in the Vault
    constructor(address _token0, address _token1) ERC20("", "") Ownable(msg.sender) {
        if (_token0 > _token1) (_token0, _token1) = (_token1, _token0);

        token0 = _token0;
        token1 = _token1;
    }

    /// @notice Deposits user's funds within the strategy and mints them shares in return
    /// @param amount0 The desired amount of token0 user wants to deposit
    /// @param amount1 The desired amount of token1 user wants to deposit
    /// @param amount0Min The minimum amount of token0 user wants to deposit
    /// @param amount1Min The minimum amount of token1 user wants to deposit
    /// @return shares The amount of shares minted to the user
    /// @return depositAmount0 The actual amount of token0 the user deposited
    /// @return depositAmount1 The actual amount of token1 the user deposited
    function deposit(uint256 amount0, uint256 amount1, uint256 amount0Min, uint256 amount1Min)
        external
        returns (uint256 shares, uint256 depositAmount0, uint256 depositAmount1)
    {
        IStrategy(strategy).collectFees();

        (uint256 totalBalance0, uint256 totalBalance1) = IStrategy(strategy).balances();

        (shares, depositAmount0, depositAmount1) = _calcDeposit(totalBalance0, totalBalance1, amount0, amount1);

        IERC20(token0).safeTransferFrom(msg.sender, strategy, depositAmount0);
        IERC20(token1).safeTransferFrom(msg.sender, strategy, depositAmount1); // after deposit, funds remain idle, until compound is called

        if (depositFee > 0) shares -= (shares * depositFee) / 10_000;

        require(shares > 0, "shares cant be 0");
        require(depositAmount0 >= amount0Min, "slippage0");
        require(depositAmount1 >= amount1Min, "slippage1");

        if (totalSupply() == 0) _mint(BURN, 1000);
        _mint(msg.sender, shares);

        return (shares, depositAmount0, depositAmount1);
        // TODO - emit event
    }

    /// @notice Redeems user's shares for underlying tokens
    /// @param shares The amount of shares the user wants to redeem
    /// @param minAmount0 The minimum amount of token0 the user wants to withdraw
    /// @param minAmount1 The minimum amount of token1 the user wants to withdraw
    /// @return withdrawAmount0 The actual amount of token0 withdrawn
    /// @return withdrawAmount1 The actual amount of token1 withdrawn
    function withdraw(uint256 shares, uint256 minAmount0, uint256 minAmount1)
        public
        returns (uint256 withdrawAmount0, uint256 withdrawAmount1)
    {
        IStrategy(strategy).collectFees();

        (uint256 totalBalance0, uint256 totalBalance1) = IStrategy(strategy).balances();

        uint256 totalSupply = totalSupply();
        _burn(msg.sender, shares);

        withdrawAmount0 = totalBalance0 * shares / totalSupply;
        withdrawAmount1 = totalBalance1 * shares / totalSupply;

        (uint256 idle0, uint256 idle1) = IStrategy(strategy).idleBalances();

        if (idle0 < withdrawAmount0 || idle1 < withdrawAmount1) {
            // When withdrawing partial, there might be a few wei difference.
            (withdrawAmount0, withdrawAmount1) = IStrategy(strategy).withdrawPartial(shares, totalSupply);
        }

        require(withdrawAmount0 >= minAmount0 && withdrawAmount1 >= minAmount1, "slippage protection");

        IERC20(token0).safeTransferFrom(strategy, msg.sender, withdrawAmount0);
        IERC20(token1).safeTransferFrom(strategy, msg.sender, withdrawAmount1);

        return (withdrawAmount0, withdrawAmount1);

        // TODO emit event
    }

    /// @notice Calculates the deposit amounts
    /// @param bal0 The current token0 balance of the strategy
    /// @param bal1 The current token1 balance of the strategy
    /// @param depositAmount0 The amount of token0 user wishes to deposit
    /// @param depositAmount1 The amount of token1 user wishes to deposit
    /// @return shares The amount of shares to be minted to the user
    /// @return amount0 The actual amount of token0 which the user will deposit
    /// @return amount1 The actual amount of token1 which the user will deposit
    function _calcDeposit(uint256 bal0, uint256 bal1, uint256 depositAmount0, uint256 depositAmount1)
        internal
        view
        returns (uint256 shares, uint256 amount0, uint256 amount1)
    {
        uint256 totalSupply = totalSupply();

        // If total supply > 0, vault can't be empty
        assert(totalSupply == 0 || bal0 > 0 || bal1 > 0);

        if (totalSupply == 0) {
            // For first deposit, just use the amounts desired
            amount0 = depositAmount0;
            amount1 = depositAmount1;
            shares = (amount0 > amount1 ? amount0 : amount1) - (1000);
        } else if (bal0 == 0) {
            amount1 = depositAmount1;
            shares = amount1 * totalSupply / bal1;
        } else if (bal1 == 0) {
            amount0 = depositAmount0;
            shares = amount0 * totalSupply / bal0;
        } else {
            uint256 cross0 = depositAmount0 * bal1;
            uint256 cross1 = depositAmount1 * bal0;
            uint256 cross = cross0 > cross1 ? cross1 : cross0;
            require(cross > 0, "cross");

            // Round up amounts
            amount0 = (cross - 1) / bal1 + 1;
            amount1 = (cross - 1) / bal0 + 1;
            shares = cross * totalSupply / bal0 / bal1;
        }
    }

    /// @notice Adds a vesting position to the strategy
    /// @param amount0 The amount of token0 to be added as liquidity to the vesting position
    /// @param amount1 The amount of token1 to be added as liquidity to the vesitng positon
    /// @param _duration The duration over which the position should be vested
    function addVestingPosition(uint256 amount0, uint256 amount1, uint256 _duration) external onlyOwner {
        IERC20(token0).safeTransferFrom(msg.sender, strategy, amount0);
        IERC20(token1).safeTransferFrom(msg.sender, strategy, amount1);

        IStrategy(strategy).addVestingPosition(amount0, amount1, _duration); // all necessary checks are performed here.
    }

    /// @notice Returns the balances of the strategy
    /// @return bal0 The amount of token0 held by the Strategy
    /// @return bal1 The amount of token1 held by the Strategy
    function balances() external view returns (uint256 bal0, uint256 bal1) {
        return IStrategy(strategy).balances();
    }

    /// @notice Returns the spot price of the Strategy's underlying pool
    function price() public view returns (uint256) {
        return IStrategy(strategy).price();
    }

    /// @notice Returns the TWAP price of the Strategy's underlying pool
    function twapPrice() public view returns (uint256) {
        return IStrategy(strategy).twapPrice();
    }

    /// @notice Returns whether the pool's activity is normal or not
    /// Returns false in case the price between consecutive observations exceeds the pre-set threshold
    /// Checks observations up to TWAP interval ago.
    function checkPoolActivity() public returns (bool) {
        return IStrategy(strategy).checkPoolActivity();
    }

    /// @notice Sets the strategy that the vault will use
    /// @dev Can only be set once
    /// @param _newstrategy The strategy which the vault will use
    function setStrategy(address _newstrategy) external onlyOwner {
        require(strategy == address(0), "strat cant be set twice");
        require(_newstrategy != address(0), "strat cant be address(0)");
        strategy = _newstrategy;
    }

    /// @notice Sets the deposit fee. Capped at 0.1%.
    /// @param _fee The new deposit fee.
    function setDepositFee(uint256 _fee) external onlyOwner {
        require(_fee <= 10, "fee is capped at 0.1%");
        depositFee = _fee;
    }
}
