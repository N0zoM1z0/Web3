// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../types/DataTypes.sol";

library InterestRateUtils {
    // scaling everything by 1e27
    uint256 constant PRECISION = 1e27;
    /// @dev Ignoring leap years
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /**
     * @dev Calculate the borrowing rate at specific utilization
     * @param config The interest rate config
     * @param utilizationRate The current utilization of the reserve
     * @return borrowingRate The borrowing interest rate of the reserve
     *
     */
    function calculateBorrowingRate(DataTypes.InterestRateConfig storage config, uint256 utilizationRate)
        internal
        view
        returns (uint256 borrowingRate)
    {
        if (utilizationRate <= config.utilizationA) {
            if (config.utilizationA == 0) {
                return config.borrowingRateA;
            }
            borrowingRate = utilizationRate * config.borrowingRateA / config.utilizationA;
        } else if (utilizationRate <= config.utilizationB) {
            if (config.utilizationB == config.utilizationA) {
                return config.borrowingRateB;
            }
            borrowingRate = (uint256(config.borrowingRateB) - config.borrowingRateA)
                * (utilizationRate - config.utilizationA) // (rateB - rateA) * (uR - uA) / (uB - uA) + bA
                / (config.utilizationB - config.utilizationA) + config.borrowingRateA;
        } else {
            if (config.utilizationB >= PRECISION) {
                return config.maxBorrowingRate;
            }
            borrowingRate = (uint256(config.maxBorrowingRate) - config.borrowingRateB)
                * (utilizationRate - config.utilizationB) / (PRECISION - config.utilizationB) + config.borrowingRateB;
        }
        return borrowingRate;
    }

    /**
     * @dev Function to calculate the interest accumulated using a linear interest rate formula
     * @param rate The interest rate
     * @param lastUpdateTimestamp The timestamp of the last update of the interest
     * @return The interest rate linearly accumulated during the timeDelta
     *
     */
    function calculateLinearInterest(uint256 rate, uint40 lastUpdateTimestamp) internal view returns (uint256) {
        //solium-disable-next-line
        uint256 timeDifference = block.timestamp - (uint256(lastUpdateTimestamp));

        return rate * (timeDifference) / (SECONDS_PER_YEAR) + PRECISION;
    }

    /**
     * @dev Function to calculate the interest using a compounded interest rate formula
     * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
     *
     *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
     *
     * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great gas cost reductions
     *
     * @param rate The interest rate
     * @param lastUpdateTimestamp The timestamp of the last update of the interest
     * @return The interest rate compounded during the timeDelta
     *
     */
    function calculateCompoundedInterest(uint256 rate, uint128 lastUpdateTimestamp, uint256 currentTimestamp)
        internal
        pure
        returns (uint256)
    {
        //solium-disable-next-line
        uint256 exp = currentTimestamp - (uint256(lastUpdateTimestamp));

        if (exp == 0) {
            return PRECISION;
        }

        uint256 expMinusOne = exp - 1;

        uint256 expMinusTwo = exp > 2 ? exp - 2 : 0;

        uint256 ratePerSecond = rate / SECONDS_PER_YEAR;

        uint256 basePowerTwo = ratePerSecond * ratePerSecond / PRECISION;

        uint256 basePowerThree = basePowerTwo * ratePerSecond / PRECISION;

        uint256 secondTerm = exp * expMinusOne * basePowerTwo / 2;
        uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree / 6;

        return (PRECISION) + (ratePerSecond * exp) + (secondTerm) + (thirdTerm);
    }

    /**
     * @dev Calculates the compounded interest between the timestamp of the last update and the current block timestamp
     * @param rate The interest rate
     * @param lastUpdateTimestamp The timestamp from which the interest accumulation needs to be calculated
     *
     */
    function calculateCompoundedInterest(uint256 rate, uint128 lastUpdateTimestamp) internal view returns (uint256) {
        return calculateCompoundedInterest(rate, lastUpdateTimestamp, block.timestamp);
    }
}
