// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20, ERC20} from "src/openzeppelin-contracts/token/ERC20/ERC20.sol";
import {WrappedToken} from "./WrappedToken.sol";
import {IERC20Metadata} from "src/openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract UnstablePool is ERC20 {
    uint256 internal constant ONE = 1e18;
    uint256 public constant NUM_TOKENS = 3;
    uint256 public constant INITIAL_LP_SUPPLY = 2 ** (112) - 1;
    uint256 public constant MAX_UPPER_TARGET = 2 ** (96) - 1;
    uint256 private immutable _scalingFactorMainToken;
    uint256 private immutable _scalingFactorWrappedToken;
    address public immutable deployer;
    IERC20 public immutable MAIN_TOKEN; // index 1
    IERC20 public immutable WRAPPED_TOKEN; // index 2
    uint256[NUM_TOKENS] public poolBalances;

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct BatchSwapStep {
        uint256 assetInIndex;
        uint256 assetOutIndex;
        uint256 amount;
    }

    event Swap(uint256 indexed tokenIn, uint256 indexed tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address main, address wrapped)
        ERC20("Pool", "LP")
    {
        deployer = msg.sender;
        require(main != address(0), "invalid main");
        require(wrapped != address(0), "invalid wrapped");
        require(wrapped != main, "main and wrapped should not be the same");
        MAIN_TOKEN = IERC20(main);
        WRAPPED_TOKEN = IERC20(wrapped);
        _scalingFactorMainToken = _computeScalingFactor(MAIN_TOKEN);
        _scalingFactorWrappedToken = _computeScalingFactor(WRAPPED_TOKEN);

        _mint(address(this), INITIAL_LP_SUPPLY);
        poolBalances[0] = INITIAL_LP_SUPPLY;
    }

    function swap(
        SwapKind kind,
        uint256 assetInIndex,
        uint256 assetOutIndex,
        uint256 amount,
        address recipient,
        uint256 limit
    ) external returns (uint256 amountCalculated) {
        require(amount > 0, "zero amount");
        uint256 amountIn;
        uint256 amountOut;
        (amountCalculated, amountIn, amountOut) =
            _swapWithPool(kind, assetInIndex, assetOutIndex, amount, msg.sender, recipient);
        require(kind == SwapKind.GIVEN_IN ? amountOut >= limit : amountIn <= limit, "swap limit");
        _receiveAsset(assetInIndex, amountIn, msg.sender);
        _sendAsset(assetOutIndex, amountOut, recipient);
    }

    function batchSwap(SwapKind kind, BatchSwapStep[] memory swaps, address recipient, int256[] memory limits)
        external
        returns (int256[] memory assetDeltas)
    {
        require(limits.length == NUM_TOKENS);
        assetDeltas = _swapWithPools(kind, swaps, msg.sender, recipient);
        for (uint256 i = 0; i < NUM_TOKENS; ++i) {
            int256 delta = assetDeltas[i];
            require(delta <= limits[i], "swap limit");
            if (delta > 0) {
                uint256 toReceive = uint256(delta);
                _receiveAsset(i, toReceive, msg.sender);
            } else if (delta < 0) {
                uint256 toSend = uint256(-delta);
                _sendAsset(i, toSend, recipient);
            }
        }
    }

    function _getWrappedTokenRate() internal view returns (uint256) {
        return WrappedToken(address(WRAPPED_TOKEN)).getRate();
    }

    function _scalingFactors() internal view returns (uint256[] memory) {
        uint256[] memory scalingFactors = new uint256[](NUM_TOKENS);
        // The wrapped token's scaling factor is not constant, but increases over time as the wrapped token increases in
        // value.
        scalingFactors[1] = _scalingFactorMainToken;
        scalingFactors[2] = fixedPointMulDown(_scalingFactorWrappedToken, _getWrappedTokenRate());
        scalingFactors[0] = ONE;
        return scalingFactors;
    }

    function _computeScalingFactor(IERC20 token) internal view returns (uint256) {
        if (address(token) == address(this)) {
            return ONE;
        }
        // Tokens that don't implement the `decimals` method are not supported.
        uint256 tokenDecimals = IERC20Metadata(address(token)).decimals();
        // Tokens with more than 18 decimals are not supported.
        uint256 decimalsDifference = 18 - tokenDecimals;
        return ONE * 10 ** decimalsDifference;
    }

    function _receiveAsset(uint256 assetIndex, uint256 amount, address from) internal {
        if (amount == 0) {
            return;
        }
        safeTransferFrom(getAssetAddress(assetIndex), from, address(this), amount);
    }

    function _sendAsset(uint256 assetIndex, uint256 amount, address to) internal {
        if (amount == 0) {
            return;
        }
        safeTransfer(getAssetAddress(assetIndex), to, amount);
    }

    function _swapWithPool(
        SwapKind kind,
        uint256 assetInIndex,
        uint256 assetOutIndex,
        uint256 amount,
        address sender,
        address recipient
    ) private returns (uint256 amountCalculated, uint256 amountIn, uint256 amountOut) {
        require(assetInIndex < NUM_TOKENS);
        require(assetOutIndex < NUM_TOKENS);
        require(assetInIndex != assetOutIndex, "cannot swap same token");
        // amountCalculated
        amountCalculated = onSwap(kind, assetInIndex, assetOutIndex, amount);
        (amountIn, amountOut) = _getAmounts(kind, amount, amountCalculated);
        // update pool balances
        poolBalances[assetInIndex] += amountIn;
        poolBalances[assetOutIndex] -= amountOut;
        emit Swap(assetInIndex, assetOutIndex, amountIn, amountOut);
    }

    function _swapWithPools(SwapKind kind, BatchSwapStep[] memory swaps, address sender, address recipient)
        private
        returns (int256[] memory assetDeltas)
    {
        assetDeltas = new int256[](NUM_TOKENS);
        BatchSwapStep memory batchSwapStep;

        for (uint256 i = 0; i < swaps.length; ++i) {
            batchSwapStep = swaps[i];
            require(batchSwapStep.assetInIndex < NUM_TOKENS && batchSwapStep.assetOutIndex < NUM_TOKENS, "out of bound");
            require(batchSwapStep.assetInIndex != batchSwapStep.assetOutIndex, "cannot swap same token");

            uint256 amountCalculated;
            uint256 amountIn;
            uint256 amountOut;
            (amountCalculated, amountIn, amountOut) = _swapWithPool(
                kind, batchSwapStep.assetInIndex, batchSwapStep.assetOutIndex, batchSwapStep.amount, sender, recipient
            );
            assetDeltas[batchSwapStep.assetInIndex] += toInt256(amountIn);
            assetDeltas[batchSwapStep.assetOutIndex] -= toInt256(amountOut);
        }
    }

    function onSwap(SwapKind kind, uint256 tokenInIndex, uint256 tokenOutIndex, uint256 amount)
        internal
        view
        returns (uint256 amountCalculated)
    {
        require(tokenInIndex < NUM_TOKENS && tokenOutIndex < NUM_TOKENS, "out of bound");
        uint256[] memory scalingFactors = _scalingFactors();
        uint256[] memory balances = new uint256[](NUM_TOKENS);
        balances[0] = poolBalances[0];
        balances[1] = poolBalances[1];
        balances[2] = poolBalances[2];
        _upscaleArray(balances, scalingFactors);

        if (kind == SwapKind.GIVEN_IN) {
            amount = _upscale(amount, scalingFactors[tokenInIndex]);
            uint256 amountOut = _onSwapGivenIn(tokenInIndex, tokenOutIndex, amount, balances);
            return fixedPointDivDown(amountOut, scalingFactors[tokenOutIndex]);
        } else {
            // GIVEN_OUT
            amount = _upscale(amount, scalingFactors[tokenOutIndex]);
            uint256 amountIn = _onSwapGivenOut(tokenInIndex, tokenOutIndex, amount, balances);
            return fixedPointDivUp(amountIn, scalingFactors[tokenInIndex]);
        }
    }

    function _onSwapGivenOut(
        uint256 tokenInIndex,
        uint256 tokenOutIndex,
        uint256 amount,
        uint256[] memory balances
    ) internal view returns (uint256 amountIn) {
        if (tokenOutIndex == 0) {
            return _swapGivenLpOut(tokenInIndex, amount, balances);
        } else if (tokenOutIndex == 1) {
            return _swapGivenMainOut(tokenInIndex, amount, balances);
        } else if (tokenOutIndex == 2) {
            return _swapGivenWrappedOut(tokenInIndex, amount, balances);
        } else {
            revert("invalid token");
        }
    }

    function _onSwapGivenIn(
        uint256 tokenInIndex,
        uint256 tokenOutIndex,
        uint256 amount,
        uint256[] memory balances
    ) internal view returns (uint256 amountOut) {
        if (tokenInIndex == 0) {
            return _swapGivenLpIn(tokenOutIndex, amount, balances);
        } else if (tokenInIndex == 1) {
            return _swapGivenMainIn(tokenOutIndex, amount, balances);
        } else if (tokenInIndex == 2) {
            return _swapGivenWrappedIn(tokenOutIndex, amount, balances);
        } else {
            revert("invalid token index");
        }
    }

    // ////// SwapGivenOut

    function _swapGivenLpOut(uint256 tokenInIndex, uint256 amount, uint256[] memory balances)
        internal
        view
        returns (uint256)
    {
        // 1 -> 0 or 2 -> 0
        require(tokenInIndex == 1 || tokenInIndex == 2, "invalid token");
        return (tokenInIndex == 1 ? _calcMainInPerLpOut : _calcWrappedInPerLpOut)(
            amount, // LpOut amount
            balances[1], // mainBalance
            balances[2], // wrappedBalance
            _getApproximateVirtualSupply(balances[0]) // LpSupply
        );
    }

    function _swapGivenMainOut(uint256 tokenInIndex, uint256 amount, uint256[] memory balances)
        internal
        view
        returns (uint256)
    {
        require(tokenInIndex == 2 || tokenInIndex == 0, "invalid token");
        return tokenInIndex == 0
            ? _calcLpInPerMainOut(
                amount, // mainOut amount
                balances[1],
                balances[2],
                _getApproximateVirtualSupply(balances[0])
            )
            : _calcWrappedInPerMainOut(amount, balances[1]);
    }

    function _swapGivenWrappedOut(
        uint256 tokenInIndex,
        uint256 amount,
        uint256[] memory balances
    ) internal view returns (uint256) {
        require(tokenInIndex == 1 || tokenInIndex == 0, "invalid token");
        return tokenInIndex == 0
            ? _calcLpInPerWrappedOut(
                amount, // wrapped out amount
                balances[1],
                balances[2],
                _getApproximateVirtualSupply(balances[0])
            )
            : amount;
    }

    // //////

    ////// SwapGivenIn

    function _swapGivenWrappedIn(
        uint256 tokenOutIndex,
        uint256 amount,
        uint256[] memory balances
    ) internal view returns (uint256) {
        require(tokenOutIndex == 1 || tokenOutIndex == 0, "invalid token");
        return tokenOutIndex == 0
            ? _calcLpOutPerWrappedIn(
                amount, // wrappedIn amount
                balances[1], // main Balance
                balances[2], // wrapped Balance
                _getApproximateVirtualSupply(balances[0]) // LpSupply
            )
            : _calcMainOutPerWrappedIn(amount, balances[1]);
    }

    function _swapGivenMainIn(uint256 tokenOutIndex, uint256 amount, uint256[] memory balances)
        internal
        view
        returns (uint256)
    {
        require(tokenOutIndex == 2 || tokenOutIndex == 0, "invalid token");
        return tokenOutIndex == 0
            ? _calcLpOutPerMainIn(
                amount, // MainIn amount
                balances[1], // mainBalance
                balances[2], // wrappedBalance
                _getApproximateVirtualSupply(balances[0]) // LpSupply
            )
            : _calcWrappedOutPerMainIn(amount, balances[1]);
    }

    function _swapGivenLpIn(uint256 tokenOutIndex, uint256 amount, uint256[] memory balances)
        internal
        view
        returns (uint256)
    {
        // out is main or wrapped
        require(tokenOutIndex == 1 || tokenOutIndex == 2, "invalid token");
        // 0 -> 1 or 0 -> 2 for given 0
        return (tokenOutIndex == 1 ? _calcMainOutPerLpIn : _calcWrappedOutPerLpIn)(
            amount, // LpIn amount
            balances[1], // mainBalance
            balances[2], // wrappedBalance
            _getApproximateVirtualSupply(balances[0]) // LpSupply
        );
    }

    //////

    ////// _calc
    //// givenOut

    function _calcLpInPerWrappedOut(
        uint256 wrappedOut,
        uint256 mainBalance,
        uint256 wrappedBalance,
        uint256 LpSupply
    ) internal pure returns (uint256) {
        uint256 previousInvariant = _calcInvariant(mainBalance, wrappedBalance);
        uint256 newWrappedBalance = wrappedBalance - wrappedOut;
        uint256 newInvariant = _calcInvariant(mainBalance, newWrappedBalance);
        uint256 newLpBalance = mathDivDown(LpSupply * newInvariant, previousInvariant);
        return LpSupply - newLpBalance;
    }

    function _calcWrappedInPerMainOut(uint256 mainOut, uint256 mainBalance)
        internal
        pure
        returns (uint256)
    {
        uint256 afterBal = mainBalance - mainOut;
        return mainBalance - afterBal;
    }

    function _calcLpInPerMainOut(
        uint256 mainOut,
        uint256 mainBalance,
        uint256 wrappedBalance,
        uint256 LpSupply
    ) internal pure returns (uint256) {
        uint256 beforeBal = mainBalance;
        uint256 afterBal = mainBalance - mainOut;
        uint256 deltaMain = beforeBal - afterBal;
        uint256 invariant = _calcInvariant(beforeBal, wrappedBalance);
        return mathDivUp((LpSupply * deltaMain), invariant);
    }

    function _calcMainInPerLpOut(
        uint256 LpOut,
        uint256 mainBalance,
        uint256 wrappedBalance,
        uint256 LpSupply
    ) internal pure returns (uint256) {
        if (LpSupply == 0) {
            return LpOut;
        }
        uint256 beforeBal = mainBalance;
        uint256 invariant = _calcInvariant(beforeBal, wrappedBalance);
        uint256 deltaMain = mathDivUp((invariant * LpOut), LpSupply);
        uint256 afterBal = beforeBal + deltaMain;
        return afterBal - mainBalance;
    }

    function _calcWrappedInPerLpOut(
        uint256 LpOut,
        uint256 mainBalance,
        uint256 wrappedBalance,
        uint256 LpSupply
    ) internal pure returns (uint256) {
        if (LpSupply == 0) {
            return LpOut;
        }
        uint256 previousInvariant = _calcInvariant(mainBalance, wrappedBalance);
        uint256 newBptBalance = LpSupply + LpOut;
        uint256 newWrappedBalance = mathDivUp((newBptBalance * previousInvariant), LpSupply) - mainBalance;
        return newWrappedBalance - wrappedBalance;
    }

    //// givenIn

    function _calcLpOutPerWrappedIn(
        uint256 wrappedIn,
        uint256 mainBalance,
        uint256 wrappedBalance,
        uint256 LpSupply
    ) internal pure returns (uint256) {
        if (LpSupply == 0) {
            return wrappedIn;
        }
        uint256 previousInvariant = _calcInvariant(mainBalance, wrappedBalance);

        uint256 newWrappedBalance = wrappedBalance + wrappedIn;
        uint256 newInvariant = _calcInvariant(mainBalance, newWrappedBalance);

        uint256 newBptBalance = mathDivDown(LpSupply * newInvariant, previousInvariant);

        return newBptBalance - LpSupply;
    }

    function _calcMainOutPerWrappedIn(uint256 wrappedIn, uint256 mainBalance)
        internal
        pure
        returns (uint256)
    {
        uint256 afterBal = mainBalance - wrappedIn;
        return mainBalance - afterBal;
    }

    function _calcWrappedOutPerMainIn(uint256 mainIn, uint256 mainBalance)
        internal
        pure
        returns (uint256)
    {
        uint256 beforeBal = mainBalance;
        uint256 afterBal = mainBalance + mainIn;
        return afterBal - beforeBal;
    }

    function _calcLpOutPerMainIn(
        uint256 mainIn,
        uint256 mainBalance,
        uint256 wrappedBalance,
        uint256 LpSupply
    ) internal view returns (uint256) {
        // 1 -> 0
        if (LpSupply == 0) {
            return mainIn;
        }
        uint256 beforeBal = mainBalance;
        uint256 afterBal = mainBalance + mainIn;
        uint256 deltaBalance = afterBal - beforeBal;
        uint256 invariant = _calcInvariant(beforeBal, wrappedBalance);
        return mathDivDown(LpSupply * deltaBalance, invariant);
    }

    function _calcMainOutPerLpIn(
        uint256 LpIn,
        uint256 mainBalance,
        uint256 wrappedBalance,
        uint256 LpSupply
    ) internal view returns (uint256) {
        // 0 -> 1
        uint256 beforeBal = mainBalance;
        uint256 invariant = _calcInvariant(beforeBal, wrappedBalance);
        uint256 delta = mathDivDown(invariant * LpIn, LpSupply);
        uint256 afterBal = beforeBal - delta;
        return mainBalance - afterBal;
    }

    function _calcWrappedOutPerLpIn(
        uint256 LpIn,
        uint256 mainBalance,
        uint256 wrappedBalance,
        uint256 LpSupply
    ) internal view returns (uint256) {
        // 0 -> 2
        uint256 previousInvariant = _calcInvariant(mainBalance, wrappedBalance);

        uint256 newBptBalance = LpSupply - LpIn;
        uint256 newWrappedBalance = mathDivUp(newBptBalance * previousInvariant, LpSupply) - mainBalance;

        return wrappedBalance - newWrappedBalance;
    }

    function _calcInvariant(uint256 mainBalance, uint256 wrappedBalance) internal pure returns (uint256) {
        return mainBalance + wrappedBalance;
    }

    function _getApproximateVirtualSupply(uint256 LpBalance) internal pure returns (uint256) {
        return INITIAL_LP_SUPPLY - LpBalance;
    }

    function _getAmounts(SwapKind kind, uint256 amountGiven, uint256 amountCalculated)
        private
        pure
        returns (uint256 amountIn, uint256 amountOut)
    {
        if (kind == SwapKind.GIVEN_IN) {
            (amountIn, amountOut) = (amountGiven, amountCalculated);
        } else {
            // SwapKind.GIVEN_OUT
            (amountIn, amountOut) = (amountCalculated, amountGiven);
        }
    }

    function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal view {
        for (uint256 i = 0; i < NUM_TOKENS; ++i) {
            amounts[i] = fixedPointMulDown(amounts[i], scalingFactors[i]);
        }
    }

    function _upscale(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return fixedPointMulDown(amount, scalingFactor);
    }

    // FixedPoint.sol
    function fixedPointMulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        require(a == 0 || product / a == b, "Errors.MUL_OVERFLOW");
        return product / ONE;
    }

    function fixedPointDivUp(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "Errors.ZERO_DIVISION");
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;
            require(aInflated / a == ONE, "Errors.DIV_INTERNAL"); // mul overflow
            return ((aInflated - 1) / b) + 1;
        }
    }

    function fixedPointDivDown(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "Errors.ZERO_DIVISION");
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;
            require(aInflated / a == ONE, "Errors.DIV_INTERNAL"); // mul overflow
            return aInflated / b;
        }
    }

    // Math.sol
    function mathDivUp(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "zero division");
        if (a == 0) {
            return 0;
        } else {
            return 1 + (a - 1) / b;
        }
    }

    function mathDivDown(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "zero division");
        return a / b;
    }

    // SafeCast
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value < 2 ** 255, "Errors.SAFE_CAST_VALUE_CANT_FIT_INT256");
        return int256(value);
    }

    /// SafeERC20
    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(IERC20.transferFrom, (from, to, value)));
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(IERC20.transfer, (to, value)));
    }

    function _callOptionalReturn(address token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? token.code.length == 0 : returnValue != 1) {
            revert("SafeERC20FailedOperation");
        }
    }

    //// VIEW
    function getPoolBalance(uint256 index) public view returns (uint256) {
        return poolBalances[index];
    }

    function getVirtualSupply() public view returns (uint256) {
        return _getApproximateVirtualSupply(poolBalances[0]);
    }

    function getAssetAddress(uint256 index) public view returns (address) {
        if (index == 0) {
            return address(this);
        }
        if (index == 1) {
            return address(MAIN_TOKEN);
        }
        if (index == 2) {
            return address(WRAPPED_TOKEN);
        }
        revert("index exceeds NUM_TOKENS");
    }

    function getRate() external view returns (uint256) {
        uint256[] memory balances = new uint256[](NUM_TOKENS);
        balances[0] = poolBalances[0];
        balances[1] = poolBalances[1];
        balances[2] = poolBalances[2];
        _upscaleArray(balances, _scalingFactors());
        uint256 totalBalance = _calcInvariant(balances[1], balances[2]);
        return fixedPointDivUp(totalBalance, _getApproximateVirtualSupply(balances[0]));
    }

    function getInvariant() external view returns (uint256) {
        uint256[] memory balances = new uint256[](NUM_TOKENS);
        balances[0] = poolBalances[0];
        balances[1] = poolBalances[1];
        balances[2] = poolBalances[2];
        _upscaleArray(balances, _scalingFactors());
        return _calcInvariant(balances[1], balances[2]);
    }
}
