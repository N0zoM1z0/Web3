// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Forked from Extra Finance

library DataTypes {
    // Interest Rate Config
    // The utilization rate and borrowing rate are expressed in RAY
    // utilizationB must gt utilizationA
    struct InterestRateConfig {
        // The utilization rate a, the end of the first slope on interest rate curve
        uint256 utilizationA;
        // The borrowing rate at utilization_rate_a
        uint256 borrowingRateA;
        // The utilization rate a, the end of the first slope on interest rate curve
        uint256 utilizationB;
        // The borrowing rate at utilization_rate_b
        uint256 borrowingRateB;
        // the max borrowing rate while the utilization is 100%
        uint256 maxBorrowingRate;
    }

    struct LeverageParams {
        uint256 maxIndividualBorrow;
        uint256 maxLeverage;
    }

    struct ReserveData {
        // variable borrow index.
        uint256 borrowingIndex;
        // the current borrow rate.
        uint256 currentBorrowingRate;
        // the total borrows of the reserve at a variable rate. Expressed in the currency decimals
        uint256 totalBorrows;
        // yToken address
        address yTokenAddress;
        // staking address
        address stakingAddress; // perhaps delete?
        // the capacity of the reserve pool
        uint256 reserveCapacity;
        // borrowing rate config
        InterestRateConfig borrowingRateConfig;
        LeverageParams leverageParams;
        uint256 underlyingBalance;
        uint128 lastUpdateTimestamp;
        Flags flags;
    }

    struct Flags {
        bool isActive; // set to 1 if the reserve is properly configured
        bool frozen; // set to 1 if reserve is frozen, only allows repays and withdraws, but not deposits or new borrowings
        bool borrowingEnabled; // set to 1 if borrowing is enabled, allow borrowing from this pool
    }
}
