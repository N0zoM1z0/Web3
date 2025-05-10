// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BurveFacets, InitLib} from "../../src/InitLib.sol";
import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {EdgeFacet} from "../../src/multi/facets/EdgeFacet.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {ViewFacet} from "../../src/multi/facets/ViewFacet.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {VaultType} from "../../src/multi/VaultProxy.sol";
import {Store} from "../../src/multi/Store.sol";
import {Edge} from "../../src/multi/Edge.sol";
import {IDiamond} from "Commons/Diamond/interfaces/IDiamond.sol";
import {DiamondCutFacet} from "Commons/Diamond/facets/DiamondCutFacet.sol";
import {BaseAdminFacet} from "Commons/Util/Admin.sol";
import {AdminFlags} from "Commons/Util/Admin.sol";
import {LibDiamond} from "Commons/Diamond/libraries/LibDiamond.sol";

contract EdgeFacetTest is Test {
    SimplexDiamond public diamond;
    EdgeFacet public edgeFacet;
    SimplexFacet public simplexFacet;
    ViewFacet public viewFacet;
    DiamondCutFacet public cutFacet;
    BaseAdminFacet public adminFacet;

    MockERC20 public token0;
    MockERC20 public token1;

    address public owner = makeAddr("owner");
    address public vault1 = makeAddr("vault1");
    address public vault2 = makeAddr("vault2");

    function setUp() public {
        vm.startPrank(owner);

        // Deploy the diamond and facets
        BurveFacets memory facets = InitLib.deployFacets();

        // Create the diamond with initial facets
        diamond = new SimplexDiamond(facets);

        edgeFacet = EdgeFacet(address(diamond));
        simplexFacet = SimplexFacet(address(diamond));
        viewFacet = ViewFacet(address(diamond));

        // Setup test tokens
        token0 = new MockERC20("Test Token 0", "TEST0", 18);
        token1 = new MockERC20("Test Token 1", "TEST1", 18);

        // Ensure token0 address is less than token1
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Add vertices
        simplexFacet.addVertex(address(token0), vault1, VaultType.E4626);
        simplexFacet.addVertex(address(token1), vault2, VaultType.E4626);

        vm.stopPrank();
    }

    function testSetEdge() public {
        vm.startPrank(owner);

        // Test basic edge setup
        edgeFacet.setEdge(
            address(token0),
            address(token1),
            100, // amplitude
            -46063, // lowTick
            46063 // highTick
        );

        // Use viewFacet to verify edge parameters
        Edge memory edge = viewFacet.getEdge(address(token0), address(token1));
        assertEq(edge.amplitude, 100, "Incorrect amplitude");
        assertEq(edge.lowTick, -46063, "Incorrect lowTick");
        assertEq(edge.highTick, 46063, "Incorrect highTick");

        vm.stopPrank();
    }

    function testSetEdgeRevertsForNonOwner() public {
        vm.startPrank(makeAddr("nonOwner"));

        vm.expectRevert(); // Should revert for non-owner
        edgeFacet.setEdge(
            address(token0),
            address(token1),
            1e18,
            -46063,
            46063
        );

        vm.stopPrank();
    }

    function testSetEdgeRevertsForInvalidTicks() public {
        vm.startPrank(owner);

        // Test with high tick less than low tick
        vm.expectRevert();
        edgeFacet.setEdge(
            address(token0),
            address(token1),
            1e18,
            46063, // lowTick greater than highTick
            -46063
        );

        vm.stopPrank();
    }

    // TODO: restrict the amplitude?
    // function testSetEdgeRevertsForInvalidAmplitude() public {
    //     vm.startPrank(owner);

    //     // Test with zero amplitude
    //     vm.expectRevert();
    //     edgeFacet.setEdge(
    //         address(token0),
    //         address(token1),
    //         0, // zero amplitude
    //         -46063,
    //         46063
    //     );

    //     vm.stopPrank();
    // }

    function testSetEdgeFee() public {
        vm.startPrank(owner);

        // First create the edge
        edgeFacet.setEdge(
            address(token0),
            address(token1),
            100, // amplitude
            -46063, // lowTick
            46063 // highTick
        );

        uint24 fee = 3000; // 0.3%
        uint8 feeProtocol = 50; // 50% of fee goes to protocol

        edgeFacet.setEdgeFee(
            address(token0),
            address(token1),
            fee,
            feeProtocol
        );

        // Use viewFacet to verify fee parameters
        Edge memory edge = viewFacet.getEdge(address(token0), address(token1));
        assertEq(edge.fee, fee, "Incorrect fee");
        assertEq(edge.feeProtocol, feeProtocol, "Incorrect fee protocol");

        vm.stopPrank();
    }

    function testSetEdgeFeeRevertsForNonOwner() public {
        vm.startPrank(makeAddr("nonOwner"));

        vm.expectRevert(); // Should revert for non-owner
        edgeFacet.setEdgeFee(address(token0), address(token1), 3000, 50);

        vm.stopPrank();
    }
}
