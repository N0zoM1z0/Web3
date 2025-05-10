// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BurveFacets, InitLib} from "../../src/InitLib.sol";
import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {EdgeFacet} from "../../src/multi/facets/EdgeFacet.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {ViewFacet} from "../../src/multi/facets/ViewFacet.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {VaultType, VaultLib} from "../../src/multi/VaultProxy.sol";
import {TokenRegistryImpl} from "../../src/multi/Token.sol";
import {Store} from "../../src/multi/Store.sol";
import {VertexId, newVertexId} from "../../src/multi/Vertex.sol";
import {TokenRegLib} from "../../src/multi/Token.sol";
import {Edge} from "../../src/multi/Edge.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
// Adjustment test imports
import {MultiSetupTest} from "./MultiSetup.u.sol";
import {NullAdjustor} from "../../src/integrations/adjustor/NullAdjustor.sol";
import {IAdjustor} from "../../src/integrations/adjustor/IAdjustor.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract SimplexFacetTest is Test {
    SimplexDiamond public diamond;
    EdgeFacet public edgeFacet;
    SimplexFacet public simplexFacet;
    ViewFacet public viewFacet;

    MockERC20 public token0;
    MockERC20 public token1;
    MockERC4626 public mockVault0;
    MockERC4626 public mockVault1;

    address public owner = makeAddr("owner");
    address public nonOwner = makeAddr("nonOwner");

    event VertexAdded(
        address indexed token,
        address vault,
        VaultType vaultType
    );
    event EdgeUpdated(
        address indexed token0,
        address indexed token1,
        uint256 amplitude,
        int24 lowTick,
        int24 highTick
    );

    function setUp() public {
        vm.startPrank(owner);

        // Deploy the diamond and facets
        BurveFacets memory facets = InitLib.deployFacets();
        diamond = new SimplexDiamond(facets);

        edgeFacet = EdgeFacet(address(diamond));
        simplexFacet = SimplexFacet(address(diamond));
        viewFacet = ViewFacet(address(diamond));

        // Setup test tokens
        token0 = new MockERC20("Test Token 0", "TEST0", 18);
        token1 = new MockERC20("Test Token 1", "TEST1", 18);

        mockVault0 = new MockERC4626(token0, "Mock Vault 0", "MVLT0");
        mockVault1 = new MockERC4626(token1, "Mock Vault 1", "MVLT1");

        vm.stopPrank();
    }

    function testAddVertex() public {
        vm.startPrank(owner);

        // Add first vertex
        simplexFacet.addVertex(
            address(token0),
            address(mockVault0),
            VaultType.E4626
        );

        // Add second vertex
        simplexFacet.addVertex(
            address(token1),
            address(mockVault1),
            VaultType.E4626
        );

        vm.stopPrank();
    }

    function testAddVertexRevertUnimplemented() public {
        vm.startPrank(owner);

        // Add first vertex
        vm.expectRevert(
            abi.encodeWithSelector(VaultLib.VaultTypeNotRecognized.selector, 0)
        );
        simplexFacet.addVertex(
            address(token0),
            address(0),
            VaultType.UnImplemented
        );

        // Add second vertex
        vm.expectRevert(
            abi.encodeWithSelector(VaultLib.VaultTypeNotRecognized.selector, 0)
        );
        simplexFacet.addVertex(
            address(token1),
            address(0),
            VaultType.UnImplemented
        );

        vm.stopPrank();
    }

    function testAddVertexRevertNonOwner() public {
        vm.startPrank(nonOwner);

        vm.expectRevert();
        simplexFacet.addVertex(
            address(token0),
            address(mockVault0),
            VaultType.E4626
        );

        vm.stopPrank();
    }

    function testAddVertexRevertsForDuplicate() public {
        vm.startPrank(owner);

        // Add vertex first time
        simplexFacet.addVertex(
            address(token0),
            address(mockVault0),
            VaultType.E4626
        );

        // Try to add same vertex again
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenRegistryImpl.TokenAlreadyRegistered.selector,
                address(token0)
            )
        ); // Should revert for duplicate vertex
        simplexFacet.addVertex(
            address(token0),
            address(mockVault0),
            VaultType.E4626
        );

        vm.stopPrank();
    }
}

contract SimplexFacetAdjustorTest is MultiSetupTest {
    function setUp() public {
        _newDiamond();
        _newTokens(2);

        // Add a 6 decimal token.
        tokens.push(address(new MockERC20("Test Token 3", "TEST3", 6)));
        vaults.push(
            IERC4626(
                address(new MockERC4626(ERC20(tokens[2]), "vault 3", "V3"))
            )
        );
        simplexFacet.addVertex(tokens[2], address(vaults[2]), VaultType.E4626);

        _fundAccount(address(this));
    }

    /// Test that switching the adjustor actually works on setAdjustment by testing
    /// the liquidity value of the same deposit.
    function testSetAdjustor() public {
        uint128[] memory amounts = new uint128[](3);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        amounts[2] = 1e6;
        // Init liq, the initial "value" in the pool.
        uint256 initLiq = liqFacet.addLiq(address(this), 0x7, amounts);

        amounts[1] = 0;
        amounts[2] = 0;
        // Adding this still gives close to a third of the "value" in the pool.
        uint256 withAdjLiq = liqFacet.addLiq(address(this), 0x7, amounts);
        assertApproxEqRel(withAdjLiq, initLiq / 3, 1e16); // Off by 1%

        // But if we switch the adjustor. Now it's worth less, although not that much less
        // because even though the balance of token2 is low, its value goes off peg and goes much higher.
        // Therefore it ends up with roughly 1/5th of the pool's value now instead of something closer to 1/4.
        IAdjustor nAdj = new NullAdjustor();
        simplexFacet.setAdjustor(nAdj);
        amounts[0] = 0;
        amounts[1] = 1e18; // Normally this would be close to withAdjLiq.
        uint256 noAdjLiq = liqFacet.addLiq(address(this), 0x7, amounts);
        assertApproxEqRel(noAdjLiq, (initLiq + withAdjLiq) / 5, 1e16); // Off by 1%
    }
}
