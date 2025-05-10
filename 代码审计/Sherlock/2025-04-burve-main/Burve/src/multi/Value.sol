// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {MAX_TOKENS} from "./Constants.sol";
import {FullMath} from "../FullMath.sol";

/// Parameters controlling the newton's method search for t.
struct SearchParams {
    uint8 maxIter;
    // Value at which we regard it close enough to 0 to not exploit us.
    // If it's smaller than fees paid there's no reason to attempt to game this.
    int256 deMinimusX128; // int X128 to match ftX128, but always positive.
    // When the initial search fails, we accept solutions farther than deminimus from 0
    // as long as they overpay in the right direction. However to put a sanity check on it
    // we limit that overpayment by something sensible here.
    int256 targetSlippageX128;
}

using SearchParamsImpl for SearchParams global;

library SearchParamsImpl {
    function init(SearchParams storage self) internal {
        self.maxIter = 5;
        self.deMinimusX128 = 100;
        self.targetSlippageX128 = 1e12;
    }
}

library ValueLib {
    uint256 public constant ONEX128 = 1 << 128;
    uint256 public constant TWOX128 = 2 << 128;

    error XTooSmall(uint256 requestedX, uint256 minimumX);

    error TSolutionNotFound(
        uint256 tX128,
        int256 ftX128,
        uint256[] esX128,
        uint256[] xs
    );

    /* Simplex internal methods */

    /// Given an efficiency factor, calculate the minimum value of x before v goes negative.
    /// @dev Since we're calculating a min, we round up, and uses of this also round up.
    function calcMinXPerTX128(
        uint256 eX128
    ) internal pure returns (uint256 xPerTX128) {
        // The calculation is simply 1 / (e + 2)
        return FullMath.mulDivX256(1, eX128 + TWOX128, true);
    }

    /// Convert our max_token storage arrays to dense in memory arrays to newtons over.
    function stripArrays(
        uint8 n,
        uint256[MAX_TOKENS] storage _esX128,
        uint256[MAX_TOKENS] storage _xs
    ) internal view returns (uint256[] memory esX128, uint256[] memory xs) {
        esX128 = new uint256[](n);
        xs = new uint256[](n);
        uint8 k = 0;
        for (uint8 i = 0; i < MAX_TOKENS; ++i) {
            if (_xs[i] > 0) {
                xs[k] = _xs[i];
                esX128[k] = _esX128[i];
                ++k;
            }
        }
        require(n == k, "Closure size mismatch");
    }

    /* User operations */

    /// Calculate the value of the current token balance (x).
    /// @dev Calling this with too small an x will revert.
    /// @param tX128 The target balance of this token.
    /// @param eX128 The capital efficiency factor of x.
    /// @param _x The token balance. Won't go above 128 bits.
    function v(
        uint256 tX128,
        uint256 eX128,
        uint256 _x,
        bool roundUp
    ) internal pure returns (uint256 valueX128) {
        uint256 etX128 = FullMath.mulX128(eX128, tX128, roundUp);
        valueX128 = etX128 + 2 * tX128;
        uint256 denomX128 = (_x << 128) + etX128;
        uint256 sqrtNumX128 = etX128 + tX128;
        uint256 subtract;
        if (roundUp) {
            subtract = FullMath.mulDivRoundingUp(
                sqrtNumX128,
                sqrtNumX128,
                denomX128
            );
        } else {
            subtract = FullMath.mulDiv(sqrtNumX128, sqrtNumX128, denomX128);
        }
        if (subtract > valueX128)
            revert XTooSmall(_x, (tX128 / (eX128 + TWOX128)) + 1);
        valueX128 -= subtract;
    }

    /// Calculate the difference in value between two token balances.
    /// @dev Will revert if x balances are not in size order.
    function vDiff(
        uint256 tX128,
        uint256 eX128,
        uint256 smallX,
        uint256 largeX,
        bool roundUp
    ) internal pure returns (uint256 valueDiffX128) {
        return
            v(tX128, eX128, largeX, roundUp) -
            v(tX128, eX128, smallX, !roundUp);
    }

    /// Given the desired value (vX128), what is the corresponding balance of the token.
    /// @dev Since v is positive, x will be positive.
    function x(
        uint256 tX128,
        uint256 eX128,
        uint256 vX128,
        bool roundUp
    ) internal pure returns (uint256 _x) {
        uint256 etX128 = FullMath.mulX128(eX128, tX128, roundUp);
        uint256 sqrtNumX128 = etX128 + tX128;
        // V is always less than (e + 2) * t
        uint256 denomX128 = etX128 + 2 * tX128 - vX128;
        uint256 xX128 = roundUp
            ? FullMath.mulDivRoundingUp(sqrtNumX128, sqrtNumX128, denomX128)
            : FullMath.mulDiv(sqrtNumX128, sqrtNumX128, denomX128);
        xX128 -= etX128;
        _x = xX128 >> 128;
        if (roundUp && ((xX128 << 128) != 0)) _x += 1;
    }

    /// Given the token balances for all tokens in a closure and their efficiency factors, determine the
    /// equilibriating target value.
    /// By convention we always round this down. On token adds, it under-dispenses value.
    /// On token removes, rounding down overdispenses value by 1, but we overcharge fees so its okay.
    function t(
        SearchParams memory searchParams,
        uint256[] memory esX128,
        uint256[] memory xs,
        uint256 tX128
    ) internal pure returns (uint256 targetX128) {
        // Run newton's method.
        bool done = false;
        int256 ftX128;
        // We allow deminimus per vertex involved.
        int256 deMinX128 = searchParams.deMinimusX128 * int256(xs.length);
        for (uint8 i = 0; i < searchParams.maxIter; ++i) {
            ftX128 = f(tX128, esX128, xs);
            // If we found a good solution, we're done.
            if (-deMinX128 <= ftX128 && ftX128 <= deMinX128) {
                done = true;
                break;
            }
            tX128 = stepT(tX128, esX128, xs, ftX128);
        }
        if (!done) {
            // We'll look again but this time also accept any positive f
            // that's within a reasonable slippage bound.
            for (uint8 i = 0; i < searchParams.maxIter; ++i) {
                ftX128 = f(tX128, esX128, xs);
                // If we found a good solution, we're done.
                if (
                    -deMinX128 <= ftX128 &&
                    ftX128 <= searchParams.targetSlippageX128
                ) {
                    done = true;
                    break;
                }
                tX128 = stepT(tX128, esX128, xs, ftX128);
            }
        }
        require(done, TSolutionNotFound(tX128, ftX128, esX128, xs));
        return tX128;
    }

    /* Newtons method helpers for t */

    function stepT(
        uint256 tX128,
        uint256[] memory esX128,
        uint256[] memory xs,
        int256 ftX128
    ) internal pure returns (uint256 nextTX128) {
        int256 dftX128 = dfdt(tX128, esX128, xs);
        bool posNum = ftX128 > 0;
        bool posDenom = dftX128 > 0;
        if (posNum && posDenom) {
            nextTX128 =
                tX128 -
                FullMath.mulDiv(uint256(ftX128), 1 << 128, uint256(dftX128));
        } else if (posNum && !posDenom) {
            nextTX128 =
                tX128 +
                FullMath.mulDiv(uint256(ftX128), 1 << 128, uint256(-dftX128));
        } else if (!posNum && posDenom) {
            nextTX128 =
                tX128 +
                FullMath.mulDiv(uint256(-ftX128), 1 << 128, uint256(dftX128));
        } else {
            nextTX128 =
                tX128 -
                FullMath.mulDiv(uint256(-ftX128), 1 << 128, uint256(-dftX128));
        }
    }

    /// Evaluate the total value of all tokens minus N * target where N is the number of tokens.
    /// This can go negative during the process of searching for a valid t.
    function f(
        uint256 tX128,
        uint256[] memory esX128,
        uint256[] memory xs
    ) internal pure returns (int256 ftX128) {
        uint256 n = xs.length;
        for (uint256 i = 0; i < n; ++i) {
            ftX128 += int256(v(tX128, esX128[i], xs[i], false));
        }
        ftX128 -= int256(n * tX128);
    }

    /// Calculate the derivative of the search function f which is the sum of all values minus N * target.
    function dfdt(
        uint256 tX128,
        uint256[] memory esX128,
        uint256[] memory xs
    ) internal pure returns (int256 dftX128) {
        uint256 n = xs.length;
        for (uint256 i = 0; i < n; ++i) {
            dftX128 += dvdt(tX128, esX128[i], xs[i]);
        }
        dftX128 -= int256(n * ONEX128);
    }

    /// Calculate the derivative of v with respect to t.
    /// Rounding is more of an art here which is okay since we're iterating for a deMinimus solution.
    function dvdt(
        uint256 tX128,
        uint256 eX128,
        uint256 _x
    ) internal pure returns (int256 dvX128) {
        uint256 etX128 = FullMath.mulX128(eX128, tX128, false);
        dvX128 = int256(eX128 + TWOX128);
        uint256 xX128 = _x << 128;
        uint256 numAX128 = 2 * xX128 + etX128;
        // We round down here to balance the rounding in the denom.
        uint256 numBX128 = tX128 +
            2 *
            etX128 +
            FullMath.mulX128(eX128, etX128, false);
        uint256 sqrtDenomX128 = xX128 + etX128;
        uint256 halfX128 = FullMath.mulDiv(numAX128, 1 << 128, sqrtDenomX128);
        dvX128 -= int256(FullMath.mulDiv(halfX128, numBX128, sqrtDenomX128));
    }
}
