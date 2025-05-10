// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import {IDiamond} from "Commons/Diamond/interfaces/IDiamond.sol";
import {DiamondCutFacet} from "Commons/Diamond/facets/DiamondCutFacet.sol";

import {InitLib, BurveFacets} from "../../src/multi/InitLib.sol";
import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {LockFacet} from "../../src/multi/facets/LockFacet.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {StoreManipulatorFacet} from "./StoreManipulatorFacet.u.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {ValueFacet} from "../../src/multi/facets/ValueFacet.sol";
import {ValueTokenFacet} from "../../src/multi/facets/ValueTokenFacet.sol";
import {VaultType} from "../../src/multi/vertex/VaultProxy.sol";
import {IBGTExchanger, BGTExchanger} from "../../src/integrations/BGTExchange/BGTExchanger.sol";
import {MultiSetupTest} from "./MultiSetup.u.sol";
import {MAX_TOKENS} from "../../src/multi/Constants.sol";
import {console2} from "forge-std/console2.sol";

contract ExchangerTest is MultiSetupTest {
    function setUp() public {
        vm.startPrank(owner);
        _newDiamond();
        _installBGTExchanger();
        _newTokens(2);
        _initializeClosure(3, INITIAL_VALUE, 1 << 127, 1 << 127);
        _fundAccount(alice);
        _fundAccount(bob);
        vm.stopPrank();
    }

    function testCollectBgtEarnings() public {
        // Add liquidity to closure 3
        uint16 closureId = 3;
        uint128 value = 1e25;
        uint128 bgtValue = 5e24;
        vm.startPrank(alice);
        valueFacet.addValue(alice, closureId, value, bgtValue);
        vm.stopPrank();

        // Perform swap from token0 to token1
        uint256 swapAmount = 1e23;
        vm.startPrank(bob);
        swapFacet.swap(
            bob, // recipient
            address(tokens[0]), // inToken
            address(tokens[1]), // outToken
            int256(swapAmount), // amountSpecified (positive for exact input)
            0, // amountLimit (0 means no limit)
            closureId // closureId
        );
        vm.stopPrank();

        // Check initial BGT balance
        uint256 initialBgtBalance = ibgt.balanceOf(alice);

        // Collect earnings
        vm.startPrank(alice);
        (
            uint256 posValue,
            uint256 posBgtValue,
            uint256[MAX_TOKENS] memory earnings,
            uint256 bgtEarnings
        ) = valueFacet.queryValue(alice, closureId);
        console2.log("bgtEarnings", bgtEarnings);
        valueFacet.removeValue(
            alice,
            closureId,
            uint128(posValue),
            uint128(posBgtValue)
        );
        valueFacet.collectEarnings(alice, closureId);
        vm.stopPrank();

        // Verify BGT earnings were collected
        uint256 finalBgtBalance = ibgt.balanceOf(alice);
        assertTrue(
            finalBgtBalance > initialBgtBalance,
            "BGT earnings should be collected"
        );
    }
}
