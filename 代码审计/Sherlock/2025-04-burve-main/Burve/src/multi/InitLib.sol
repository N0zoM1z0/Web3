// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ValueFacet} from "./facets/ValueFacet.sol";
import {ValueTokenFacet} from "./facets/ValueTokenFacet.sol";
import {SimplexFacet} from "./facets/SimplexFacet.sol";
import {SwapFacet} from "./facets/SwapFacet.sol";
import {VaultFacet} from "./facets/VaultFacet.sol";
import {DecimalAdjustor} from "../integrations/adjustor/DecimalAdjustor.sol";

struct BurveFacets {
    address valueFacet;
    address valueTokenFacet;
    address simplexFacet;
    address swapFacet;
    address vaultFacet;
    address adjustor;
}

library InitLib {
    /**
     * Deploys each of the facets for the Burve diamond
     */
    function deployFacets() internal returns (BurveFacets memory facets) {
        facets.valueFacet = address(new ValueFacet());
        facets.valueTokenFacet = address(new ValueTokenFacet());
        facets.simplexFacet = address(new SimplexFacet());
        facets.swapFacet = address(new SwapFacet());
        facets.vaultFacet = address(new VaultFacet());
        facets.adjustor = address(new DecimalAdjustor());
    }
}
