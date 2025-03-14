// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

import "../interfaces/IyToken.sol";

import "./InterestRateUtils.sol";
import "../types/DataTypes.sol";

library ReserveLogic {
    using SafeERC20 for IERC20;

    uint256 constant PRECISION = 1e27;
    /**
     * @dev Get the total liquidity and borrowed out portion,
     * where the total liquidity is the sum of available liquidity and borrowed out portion.
     * @param reserve The Reserve Object
     */

    function totalLiquidityAndBorrows(DataTypes.ReserveData storage reserve)
        internal
        view
        returns (uint256 total, uint256 borrows)
    {
        borrows = borrowedLiquidity(reserve);
        total = availableLiquidity(reserve) + (borrows);
    }

    /**
     * @dev Get the available liquidity not borrowed out.
     * @param reserve The Reserve Object
     * @return liquidity
     */
    function availableLiquidity(DataTypes.ReserveData storage reserve) internal view returns (uint256 liquidity) {
        return reserve.underlyingBalance;
    }

    /**
     * @dev Get the liquidity borrowed out.
     * @param reserve The Reserve Object
     * @return liquidity
     */
    function borrowedLiquidity(DataTypes.ReserveData storage reserve) internal view returns (uint256 liquidity) {
        liquidity = latestBorrowingIndex(reserve) * (reserve.totalBorrows) / (reserve.borrowingIndex);
    }

    /**
     * @dev Get the utilization of the reserve.
     * @param reserve The Reserve Object
     * @return rate
     */
    function utilizationRate(DataTypes.ReserveData storage reserve) internal view returns (uint256 rate) {
        (uint256 total, uint256 borrows) = totalLiquidityAndBorrows(reserve);

        if (total > 0) {
            rate = borrows * (PRECISION) / (total);
        }

        return rate;
    }

    /**
     * @dev Get the borrowing interest rate of the reserve.
     * @param reserve The Reserve Object
     * @return rate
     */
    function borrowingRate(DataTypes.ReserveData storage reserve) internal view returns (uint256 rate) {
        rate = InterestRateUtils.calculateBorrowingRate(reserve.borrowingRateConfig, utilizationRate(reserve));
    }

    /**
     * @dev Exchange Rate from reserve liquidity to yToken
     * @param reserve The Reserve Object
     * @return The Exchange Rate
     */
    function reserveToYTokenExchangeRate(DataTypes.ReserveData storage reserve) internal view returns (uint256) {
        (uint256 totalLiquidity,) = totalLiquidityAndBorrows(reserve);
        uint256 totalYTokens = IERC20(reserve.yTokenAddress).totalSupply();

        if (totalYTokens == 0 || totalLiquidity == 0) {
            return PRECISION;
        }
        return totalYTokens * PRECISION / totalLiquidity;
    }

    /**
     * @dev Exchange Rate from yToken to reserve liquidity
     * @param reserve The Reserve Object
     * @return The Exchange Rate
     */
    function yTokenToReserveExchangeRate(DataTypes.ReserveData storage reserve) external view returns (uint256) {
        (uint256 totalLiquidity,) = totalLiquidityAndBorrows(reserve);
        uint256 totalYTokens = IERC20(reserve.yTokenAddress).totalSupply();

        if (totalYTokens == 0 || totalLiquidity == 0) {
            return PRECISION;
        }
        return totalLiquidity * (PRECISION) / (totalYTokens);
    }

    /**
     * @dev Returns the borrowing index for the reserve
     * @param reserve The reserve object
     * @return The borrowing index.
     *
     */
    function latestBorrowingIndex(DataTypes.ReserveData storage reserve) internal view returns (uint256) {
        if (reserve.lastUpdateTimestamp == uint128(block.timestamp)) {
            //if the index was updated in the same block, no need to perform any calculation
            return reserve.borrowingIndex;
        }

        return reserve.borrowingIndex
            * (InterestRateUtils.calculateCompoundedInterest(reserve.currentBorrowingRate, reserve.lastUpdateTimestamp))
            / (PRECISION);
    }

    function checkCapacity(DataTypes.ReserveData storage reserve, uint256 depositAmount) internal view {
        (uint256 totalLiquidity,) = totalLiquidityAndBorrows(reserve);

        require(totalLiquidity + (depositAmount) <= reserve.reserveCapacity);
    }

    /**
     * @dev Updates the the variable borrow index.
     * @param reserve the reserve object
     *
     */
    function updateState(DataTypes.ReserveData storage reserve) internal {
        _updateIndexes(reserve);
    }

    /**
     * @dev Updates the interest rate of the reserve pool.
     * @param reserve the reserve object
     *
     */
    function updateInterestRates(DataTypes.ReserveData storage reserve) internal {
        reserve.currentBorrowingRate =
            InterestRateUtils.calculateBorrowingRate(reserve.borrowingRateConfig, utilizationRate(reserve));
    }

    /**
     * @dev Updates the reserve indexes and the timestamp of the update
     * @param reserve The reserve object
     *
     */
    function _updateIndexes(DataTypes.ReserveData storage reserve) internal {
        uint256 newBorrowingIndex = reserve.borrowingIndex;
        uint256 newTotalBorrows = reserve.totalBorrows;

        if (reserve.totalBorrows > 0) {
            newBorrowingIndex = latestBorrowingIndex(reserve);
            newTotalBorrows = newBorrowingIndex * (reserve.totalBorrows) / (reserve.borrowingIndex);

            require(newBorrowingIndex <= type(uint128).max);

            reserve.borrowingIndex = newBorrowingIndex;
            reserve.totalBorrows = newTotalBorrows;
        }
        reserve.lastUpdateTimestamp = uint128(block.timestamp);
    }

    /**
     * @dev Sets the active state of the reserve
     * @param reserve The reserve
     * @param state The true or false state
     *
     */
    function setActive(DataTypes.ReserveData storage reserve, bool state) internal {
        reserve.flags.isActive = state;
    }

    /**
     * @dev Gets the active state of the reserve
     * @param reserve The reserve
     * @return The true or false state
     *
     */
    function getActive(DataTypes.ReserveData storage reserve) internal view returns (bool) {
        return reserve.flags.isActive;
    }

    /**
     * @dev Sets the frozen state of the reserve
     * @param reserve The reserve
     * @param state The true or false state
     *
     */
    function setFrozen(DataTypes.ReserveData storage reserve, bool state) internal {
        reserve.flags.frozen = state;
    }

    /**
     * @dev Gets the frozen state of the reserve
     * @param reserve The reserve
     * @return The true or false state
     *
     */
    function getFrozen(DataTypes.ReserveData storage reserve) internal view returns (bool) {
        return reserve.flags.frozen;
    }

    /**
     * @dev Sets the borrowing enable state of the reserve
     * @param reserve The reserve
     * @param state The true or false state
     *
     */
    function setBorrowingEnabled(DataTypes.ReserveData storage reserve, bool state) internal {
        reserve.flags.borrowingEnabled = state;
    }

    /**
     * @dev Gets the borrowing enable state of the reserve
     * @param reserve The reserve
     * @return The true or false state
     *
     */
    function getBorrowingEnabled(DataTypes.ReserveData storage reserve) internal view returns (bool) {
        return reserve.flags.borrowingEnabled;
    }
}
