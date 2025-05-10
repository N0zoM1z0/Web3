// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// Adjustors are contracts that convert token balances in various ways.
/// For example, it re-normalizes non-18 decimal tokens to 18 decimals.
/// Or converts appreciating LSTs to the underlier's balance.
interface IAdjustor {
    /// Convert a uint to the nominal value by normalizing the decimals around 18.
    function toNominal(
        address token,
        uint256 real,
        bool roundUp
    ) external view returns (uint256 nominal);

    /// Convert an int to the nominal value by normalizing the decimals around 18.
    function toNominal(
        address token,
        int256 real,
        bool roundUp
    ) external view returns (int256 nominal);

    /// Convert a uint to the real value by denormalizing the decimals back to their original value.
    function toReal(
        address token,
        uint256 nominal,
        bool roundUp
    ) external view returns (uint256 real);

    /// Convert an int to the real value by denormalizing the decimals back to their original value.
    function toReal(
        address token,
        int256 nominal,
        bool roundUp
    ) external view returns (int256 real);

    /// If an adjustment will be queried often, someone can call this to cache the result for cheaper views.
    function cacheAdjustment(address token) external;

    /*
    NOT PART OF THE INTERFACE BUT COULD BE USEFUL IN THE FUTURE IF MORE ACCURACY IS NEEDED.
    FOR NOW, IT IS REDUNDANT GIVEN WE CAN DIVIDE ADJUSTMENTS AND TAKE THE SQRT WITHOUT SIGNIFICANT IMPRECISION.


    /// Query the multiplicative factor for converting the real-valued square root ratio of two token values to
    /// a nominal value.
    function nominalSqrtRatioX128(
        address numToken,
        address denomToken,
        bool roundUp
    ) external view returns (uint256 ratioX128);

    /// Query the multiplicative factor for converting the nominal-valued square root ratio of two token values to
    /// their real value. Dividing by nominalSqrtRatioX128 can be used instead.
    function realSqrtRatioX128(
        address numToken,
        address denomToken,
        bool roundUp
    ) external view returns (uint256 ratioX128);

    /// If a ratio will be queried often, someone can call this to cache the result for cheaper views.
    function cacheRatio(address numToken, address denomToken) external;
    */
}
