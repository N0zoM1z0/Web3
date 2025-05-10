// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IBGTExchanger} from "../integrations/BGTExchange/IBGTExchanger.sol";
import {MAX_TOKENS} from "./Constants.sol";
import {Store} from "./Store.sol";
import {TokenRegLib} from "./Token.sol";
import {ValueLib, SearchParams} from "./Value.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

// Stores information unchanged between all closures.
struct Simplex {
    string name;
    string symbol;
    address adjustor;
    address bgtEx;
    /// New closures are made with at least this much target value.
    uint256 initTarget;
    /// The efficiency factor for each token.
    uint256[MAX_TOKENS] esX128;
    /// A scaling factor for calculating the min acceptable x balance based on e.
    uint256[MAX_TOKENS] minXPerTX128;
    /// Amounts earned by the protocol for withdrawal.
    uint256[MAX_TOKENS] protocolEarnings;
    /// Parameters used by ValueLib.t to search
    SearchParams searchParams;
}

/// Convenient methods frequently requested by other parts of the pool.
library SimplexLib {
    /// There no logical reason for e to be larger than 2^12. This also
    /// limits the bits to under ten which affords 118 bits for t in ValueLib calculations
    /// which is more than sufficient.
    uint256 public constant MAX_E_X128 = 1 << (12 + 128);
    uint128 public constant DEFAULT_INIT_TARGET = 1e12;

    /// Thrown when attempting to assign an e that is too large.
    error OversizedEfficiencyAssignment(uint256);

    function init(
        string memory name,
        string memory symbol,
        address adjustor
    ) internal {
        Simplex storage s = Store.simplex();
        s.name = name;
        s.symbol = symbol;
        s.adjustor = adjustor;
        s.initTarget = DEFAULT_INIT_TARGET;
        // Default to 10x efficient: price range is [0.84, 1.21].
        for (uint256 i = 0; i < MAX_TOKENS; ++i) {
            s.esX128[i] = 10 << 128;
            s.minXPerTX128[i] = ValueLib.calcMinXPerTX128(10 << 128);
        }
        s.searchParams.init();
    }

    /// @notice Gets earned protocol fees that have yet to be collected.
    function protocolEarnings()
        internal
        view
        returns (uint256[MAX_TOKENS] memory)
    {
        Simplex storage simplex = Store.simplex();
        return simplex.protocolEarnings;
    }

    /// @notice Adds amount to earned protocol fees for given token.
    /// @param idx The index of the token.
    /// @param amount The amount earned.
    function protocolTake(uint8 idx, uint256 amount) internal {
        Simplex storage simplex = Store.simplex();
        simplex.protocolEarnings[idx] += amount;
    }

    /// @notice Removes the earned protocol fees for given token.
    /// @param idx The index of the token.
    /// @return amount The amount earned.
    function protocolGive(uint8 idx) internal returns (uint256 amount) {
        Simplex storage simplex = Store.simplex();
        amount = simplex.protocolEarnings[idx];
        simplex.protocolEarnings[idx] = 0;
    }

    // Within this bound, valueStaked and target are effectively zero.
    function deMinimusValue() internal view returns (uint256 dM) {
        dM = uint256(Store.simplex().searchParams.deMinimusX128);
        if (uint128(dM) > 0) {
            dM = (dM >> 128) + 1;
        } else {
            dM = dM >> 128;
        }
    }

    /// @notice Gets the efficiency factors for all tokens.
    function getEsX128() internal view returns (uint256[MAX_TOKENS] storage) {
        return Store.simplex().esX128;
    }

    /// @notice Gets the efficiency factor for a given token by their index.
    /// @param idx The index of the token.
    function getEX128(uint8 idx) internal view returns (uint256) {
        return Store.simplex().esX128[idx];
    }

    /// @notice Sets the efficiency factor for a given token by their index.
    /// @param idx The index of the token.
    /// @param eX128 The efficiency factor to set.
    function setEX128(uint8 idx, uint256 eX128) internal {
        Simplex storage s = Store.simplex();
        s.esX128[idx] = eX128;
        s.minXPerTX128[idx] = ValueLib.calcMinXPerTX128(eX128);
    }

    function bgtExchange(
        uint8 idx,
        uint256 amount
    ) internal returns (uint256 bgtEarned, uint256 unspent) {
        Simplex storage s = Store.simplex();
        if (s.bgtEx == address(0)) return (0, amount);
        address token = TokenRegLib.getToken(idx);
        uint256 spentAmount;
        SafeERC20.forceApprove(IERC20(token), s.bgtEx, amount);
        (bgtEarned, spentAmount) = IBGTExchanger(s.bgtEx).exchange(
            token,
            uint128(amount) // safe cast since amount cant possibly be more than 1e30
        );
        unspent = amount - spentAmount;
    }

    function viewBgtExchange(
        uint8 idx,
        uint256 amount
    ) internal view returns (uint256 bgtEarned, uint256 unspent) {
        Simplex storage s = Store.simplex();
        if (s.bgtEx == address(0)) return (0, amount);
        address token = TokenRegLib.getToken(idx);
        uint256 spentAmount;
        (bgtEarned, spentAmount) = IBGTExchanger(s.bgtEx).viewExchange(
            token,
            uint128(amount) // safe cast since amount cant possibly be more than 1e30
        );
        unspent = amount - spentAmount;
    }

    /// @notice Gets the current adjustor.
    function getAdjustor() internal view returns (address) {
        return Store.simplex().adjustor;
    }

    /// @notice Sets the adjustor.
    function setAdjustor(address adjustor) internal {
        Store.simplex().adjustor = adjustor;
    }

    /// @notice Gets the current BGT exchanger.
    function getBGTExchanger() internal view returns (address) {
        return Store.simplex().bgtEx;
    }

    /// @notice Sets the BGT exchanger.
    function setBGTExchanger(address bgtExchanger) internal {
        Store.simplex().bgtEx = bgtExchanger;
    }

    /// @notice Gets the current init target.
    function getInitTarget() internal view returns (uint256) {
        return Store.simplex().initTarget;
    }

    /// @notice Sets the init target.
    function setInitTarget(uint256 initTarget) internal {
        Store.simplex().initTarget = initTarget;
    }

    /// @notice Gets the current search params.
    function getSearchParams() internal view returns (SearchParams memory) {
        return Store.simplex().searchParams;
    }

    /// @notice Sets the search params.
    function setSearchParams(SearchParams calldata params) internal {
        Store.simplex().searchParams = params;
    }
}
