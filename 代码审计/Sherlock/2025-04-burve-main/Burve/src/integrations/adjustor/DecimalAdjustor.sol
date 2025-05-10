// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAdjustor} from "./IAdjustor.sol";
import {FullMath} from "../../FullMath.sol";

type DecimalNormalizer is int256;

/// An Adjustor specific to decimals. You can inheret to add other forms of adjustment.
contract DecimalAdjustor is IAdjustor {
    uint8 constant MAX_DECIMAL = 36; // We could handle up to 76, but why would we?
    // The fractional portion of square root of 10 in X256.
    // This plus 3 is the sqrt of 10.
    uint256 constant SQRT_TEN_FRACTIONAL_X256 =
        18790469307439851509975379947523512009840923767542359455526648238412222895360;
    error TooManyDecimals(uint8);

    /* Often people reuse tokens so we save a bit of gas by storing old adjustments since they don't change. */
    // Positive when the real decimals is too small and we multiply,
    // negative when it's too large and we divide. It'll only be zero when uninitialized.
    mapping(address => int256) public adjustments;
    // For price ratios
    mapping(address num => mapping(address denom => uint256)) public ratiosX128; // num / denom
    mapping(address num => mapping(address denom => bool)) public ratioRounding; // Round up if true.

    function cacheAdjustment(address token) external {
        adjustments[token] = calculateAdjustment(token);
    }

    function cacheRatio(address numToken, address denomToken) external {
        (uint256 ratioX128, bool willRound) = calculateSqrtRatioX128(
            numToken,
            denomToken
        );
        ratiosX128[numToken][denomToken] = ratioX128;
        ratioRounding[numToken][denomToken] = willRound;
    }

    /// Adjust real token values to a normalized value.
    /// @dev errors on overflow.
    function toNominal(
        address token,
        uint256 value,
        bool roundUp
    ) external view returns (uint256 normalized) {
        int256 multiplier = getAdjustment(token); // this has prevented zero divisions.
        if (multiplier > 0) {
            return value * uint256(multiplier);
        } else {
            uint256 divisor = uint256(-multiplier);
            normalized = value / divisor; // 
            if (roundUp && ((value % divisor) > 0)) normalized += 1;
        }
    }

    /// Normalize a real int.
    function toNominal(
        address token,
        int256 value,
        bool roundUp
    ) external view returns (int256 normalized) {
        int256 multiplier = getAdjustment(token);
        if (multiplier > 0) {
            return value * multiplier;
        } else {
            int256 divisor = -multiplier;
            // Division rounds towards zero.
            normalized = value / divisor;
            if (value > 0) {
                if (roundUp && ((value % divisor) > 0)) normalized += 1;
            } else {
                if (!roundUp && ((value % divisor) < 0)) normalized -= 1;
            }
        }
    }

    /// Adjust a normalized token amount back to the real amount.
    function toReal(
        address token,
        uint256 value,
        bool roundUp
    ) external view returns (uint256 denormalized) {
        int256 divisor = getAdjustment(token);
        if (divisor > 0) {
            uint256 div = uint256(divisor);
            denormalized = value / div;
            if (roundUp && ((value % div) > 0)) denormalized += 1;
        } else {
            uint256 multiplier = uint256(-divisor);
            return value * multiplier;
        }
    }

    /// Convert a nominal int to a real int.
    function toReal(
        address token,
        int256 value,
        bool roundUp
    ) external view returns (int256 denormalized) {
        int256 divisor = getAdjustment(token);
        if (divisor > 0) {
            denormalized = value / divisor;
            if (value > 0) {
                if (roundUp && ((value % divisor) > 0)) denormalized += 1;
            } else {
                if (!roundUp && ((value % divisor) < 0)) denormalized -= 1;
            }
        } else {
            return value * (-divisor);
        }
    }

    /// Get the ratio to convert a real price to a nominal price given a ratio of two tokens.
    function nominalSqrtRatioX128(
        address numToken,
        address denomToken,
        bool roundUp
    ) public view returns (uint256 ratioX128) {
        ratioX128 = ratiosX128[numToken][denomToken];
        if (ratioX128 == 0) {
            bool willRound;
            (ratioX128, willRound) = calculateSqrtRatioX128(
                numToken,
                denomToken
            );
            if (roundUp && willRound) ratioX128 += 1;
        } else if (roundUp && ratioRounding[numToken][denomToken])
            ratioX128 += 1;
    }

    /// Get the ratio to convert a nominal price to a real price.
    function realSqrtRatioX128(
        address numToken,
        address denomToken,
        bool roundUp
    ) external view returns (uint256 ratioX128) {
        /// This is just the multiplicative inverse of the normalizing ratio.
        ratioX128 = nominalSqrtRatioX128(denomToken, numToken, roundUp);
    }

    /* Core workhorse helpers */

    /// Calculate an adjustment. Positive for multiplication and negative for division.
    function calculateAdjustment(
        address token
    ) internal view virtual returns (int256) {
        uint8 dec = getDecimals(token);
        if (dec > MAX_DECIMAL) revert TooManyDecimals(dec);
        if (dec > 18) {
            return -int256(fastPow(dec - 18));
        } else {
            return int256(fastPow(18 - dec));
        }
    }

    /// @dev There is more numerical inaccuracy than most in calculating this ratio when
    /// the denominator's decimals is larger than the numerator's. Beware when using.
    function calculateSqrtRatioX128(
        address num,
        address denom
    ) internal view virtual returns (uint256 ratioX128, bool willRound) {
        uint8 numDec = getDecimals(num);
        uint8 denomDec = getDecimals(denom);
        if (numDec > denomDec) {
            uint8 decDiff = numDec - denomDec;
            // 1e18 fits in 60 bits.
            ratioX128 = fastPow(decDiff / 2) << 128;
            if (decDiff % 2 != 0) {
                ratioX128 = mulSqrtTen(ratioX128, false);
                willRound = true;
            }
        } else if (denomDec > numDec) {
            uint8 decDiff = denomDec - numDec;
            // We want to divide. The result of fast pow will fit in 60 bits so we use the rest.
            uint256 divisorX128 = fastPow(decDiff / 2) << 128;
            // We round up here to round the final result down.
            if (decDiff % 2 != 0) {
                divisorX128 = mulSqrtTen(divisorX128, true);
                // The sqrt ten will always have rounding.
                willRound = true;
            }
            // Get an exact final result at least.
            ratioX128 = type(uint256).max / divisorX128;
            if ((type(uint256).max % divisorX128) == (divisorX128 - 1))
                ratioX128 += 1;
            else willRound = true;
        } else {
            ratioX128 = 1 << 128;
            // No rounding needed
        }
    }

    /* Helpers */

    /// Fetch the adjustment from cache or compute it.
    /// We don't cache the result so the main methods can remain as view.
    function getAdjustment(address token) internal view returns (int256 adj) {
        adj = adjustments[token];
        if (adj == 0) {
            adj = calculateAdjustment(token);
        }
    }

    /// Compute 10 to the exp cheaply.
    function fastPow(uint8 exp) private pure returns (uint256 powed) {
        powed = 1;
        uint256 mult = 10;
        while (exp > 0) {
            if (exp & 0x1 != 0) {
                powed *= mult;
            }
            exp >>= 1;
            mult = mult * mult;
        }
    }

    /// Query the decimals for a given token and sanity check it.
    /// We can't operate on an ERC20 token without the decimal selector.
    function getDecimals(address token) internal view returns (uint8 dec) {
        dec = IERC20Metadata(token).decimals();
        if (dec > MAX_DECIMAL) revert TooManyDecimals(dec);
    }

    /// Multiply a number by the sqrt of 10.
    function mulSqrtTen(
        uint256 value,
        bool roundUp
    ) internal pure returns (uint256 res) {
        res = value * 3;
        res += FullMath.mulX256(value, SQRT_TEN_FRACTIONAL_X256, roundUp);
    }
}
