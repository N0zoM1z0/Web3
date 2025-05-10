// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Burve} from "../../src/single/Burve.sol";
import {TickRange} from "../../src/single/TickRange.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract BurveExposedInternal is Burve {
    constructor(
        address _pool,
        address _island,
        address _stationProxy,
        TickRange[] memory _ranges,
        uint128[] memory _weights
    ) Burve(_pool, _island, _stationProxy, _ranges, _weights) {}

    function compoundV3RangesExposed() public {
        compoundV3Ranges();
    }

    function collectAndCalcCompoundExposed() public returns (uint128) {
        return collectAndCalcCompound();
    }

    function getCompoundAmountsPerUnitNominalLiqX64Exposed()
        public
        view
        returns (uint256, uint256)
    {
        return getCompoundAmountsPerUnitNominalLiqX64();
    }

    function collectV3FeesExposed() public {
        collectV3Fees();
    }

    /// There are mint requirements for the first mint to be dead shares.
    /// The minimum balance requirement still holds however.
    /// We ignore that by using this for testing purposes.
    function testMint(
        address recipient,
        uint128 mintNominalLiq,
        uint160 lowerSqrtPriceLimitX96,
        uint160 upperSqrtPriceLimitX96
    ) public {
        uint256 shares = mint(
            address(this),
            mintNominalLiq,
            lowerSqrtPriceLimitX96,
            upperSqrtPriceLimitX96
        );
        IERC20(address(this)).transfer(recipient, shares);
    }
}
