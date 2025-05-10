// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {InitLib, BurveFacets} from "../../src/InitLib.sol";
import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {EdgeFacet} from "../../src/multi/facets/EdgeFacet.sol";
import {LiqFacet} from "../../src/multi/facets/LiqFacet.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {LockFacet} from "../../src/multi/facets/LockFacet.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {VaultType} from "../../src/multi/VaultProxy.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

contract MultiSetupTest is Test {
    uint256 constant INITIAL_MINT_AMOUNT = 1e30;
    uint256 constant INITIAL_LIQUIDITY_AMOUNT = 100_000e18;

    /* Diamond */
    address public diamond;
    EdgeFacet public edgeFacet;
    LiqFacet public liqFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    LockFacet public lockFacet;

    uint16 public closureId;

    /* Test Tokens */
    /// Two mock erc20s for convenience. These are guaranteed to be sorted.
    MockERC20 public token0;
    MockERC20 public token1;
    address[] public tokens;
    IERC4626[] public vaults;

    /* Some Test accounts */
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    /// Deploy the diamond and facets
    function _newDiamond() internal {
        BurveFacets memory bFacets = InitLib.deployFacets();
        diamond = address(new SimplexDiamond(bFacets));

        edgeFacet = EdgeFacet(diamond);
        liqFacet = LiqFacet(diamond);
        simplexFacet = SimplexFacet(diamond);
        swapFacet = SwapFacet(diamond);
        lockFacet = LockFacet(diamond);
    }

    /// Deploy two tokens and install them as vertices in the diamond with an edge.
    function _newTokens(uint8 numTokens) public {
        // Setup test tokens
        for (uint8 i = 0; i < numTokens; ++i) {
            string memory idx = Strings.toString(i);
            tokens.push(
                address(
                    new MockERC20(
                        string.concat("Test Token ", idx),
                        string.concat("TEST", idx),
                        18
                    )
                )
            );
        }

        // Ensure token0 address is less than token1
        if (tokens[0] > tokens[1])
            (tokens[0], tokens[1]) = (tokens[1], tokens[0]);

        token0 = MockERC20(tokens[0]);
        token1 = MockERC20(tokens[1]);

        // Add vaults and vertices
        for (uint256 i = 0; i < tokens.length; ++i) {
            string memory idx = Strings.toString(i);
            // Have to setup vaults here in case the token order changed.
            vaults.push(
                IERC4626(
                    address(
                        new MockERC4626(
                            ERC20(tokens[i]),
                            string.concat("Vault ", idx),
                            string.concat("V", idx)
                        )
                    )
                )
            );
            simplexFacet.addVertex(
                tokens[i],
                address(vaults[i]),
                VaultType.E4626
            );
        }

        // Setup edges
        simplexFacet.setDefaultEdge(100, -100, 100, 0, 0);
    }

    function _fundAccount(address account) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            MockERC20(tokens[i]).mint(account, INITIAL_MINT_AMOUNT);
        }

        // Approve diamond for all test accounts
        vm.startPrank(account);
        for (uint256 i = 0; i < tokens.length; ++i) {
            MockERC20(tokens[i]).approve(address(diamond), type(uint256).max);
        }
        vm.stopPrank();
    }
}
