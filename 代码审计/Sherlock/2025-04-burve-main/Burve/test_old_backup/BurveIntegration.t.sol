// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BurveFacets, InitLib} from "../src/InitLib.sol";
import {SimplexDiamond} from "../src/multi/Diamond.sol";
import {LiqFacet} from "../src/multi/facets/LiqFacet.sol";
import {SimplexFacet} from "../src/multi/facets/SimplexFacet.sol";
import {EdgeFacet} from "../src/multi/facets/EdgeFacet.sol";
import {SwapFacet} from "../src/multi/facets/SwapFacet.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ClosureId, newClosureId} from "../src/multi/Closure.sol";
import {VaultType} from "../src/multi/VaultProxy.sol";
import {MockERC4626} from "./mocks/MockERC4626.sol";
import {ViewFacet} from "../src/multi/facets/ViewFacet.sol";
import {BurveMultiLPToken} from "../src/multi/LPToken.sol";

contract BurveIntegrationTest is Test {
    SimplexDiamond public diamond;
    LiqFacet public liqFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    EdgeFacet public edgeFacet;
    ViewFacet public viewFacet;
    BurveMultiLPToken public lpToken;

    // Test tokens
    MockERC20 public token0;
    MockERC20 public token1;

    // Test vaults
    MockERC4626 public mockVault0;
    MockERC4626 public mockVault1;

    // Test accounts
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // Common test amounts
    uint256 constant INITIAL_MINT_AMOUNT = 1000000e18;
    uint256 constant INITIAL_LIQUIDITY_AMOUNT = 100000e18;
    uint256 constant INITIAL_DEPOSIT_AMOUNT = 100e18;

    // Swap constants
    uint128 constant MIN_SQRT_PRICE_X96 = uint128(1 << 96) / 1000;
    uint128 constant MAX_SQRT_PRICE_X96 = uint128(1000 << 96);

    // Test closure ID for token pair
    uint16 public closureId;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy the diamond and facets
        BurveFacets memory burveFacets = InitLib.deployFacets();

        diamond = new SimplexDiamond(burveFacets);

        // Cast the diamond address to the facet interfaces
        liqFacet = LiqFacet(address(diamond));
        simplexFacet = SimplexFacet(address(diamond));
        swapFacet = SwapFacet(address(diamond));
        edgeFacet = EdgeFacet(address(diamond));
        viewFacet = ViewFacet(address(diamond));

        // Setup test tokens
        _setupTestTokens();

        mockVault0 = new MockERC4626(token0, "Mock Vault 0", "MVLT0");
        mockVault1 = new MockERC4626(token1, "Mock Vault 1", "MVLT1");

        // Add vertices to the simplex with empty vaults
        simplexFacet.addVertex(
            address(token0),
            address(mockVault0),
            VaultType.E4626
        );
        simplexFacet.addVertex(
            address(token1),
            address(mockVault1),
            VaultType.E4626
        );

        // Setup edge between tokens
        edgeFacet.setEdge(
            address(token0),
            address(token1),
            101, // amplitude
            -46063, // lowTick
            46063 // highTick
        );

        // fetch closure
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        closureId = ClosureId.unwrap(viewFacet.getClosureId(tokens));

        // Create LP token for this closure
        lpToken = new BurveMultiLPToken(
            ClosureId.wrap(closureId),
            address(diamond)
        );

        vm.stopPrank();

        // Fund test accounts
        _fundTestAccounts();

        _provideLiquidity(
            owner,
            INITIAL_LIQUIDITY_AMOUNT,
            INITIAL_LIQUIDITY_AMOUNT
        );
    }

    function _setupTestTokens() internal {
        // Deploy tokens with 18 decimals
        token0 = new MockERC20("Test Token 0", "TEST0", 18);
        token1 = new MockERC20("Test Token 1", "TEST1", 18);

        // Ensure token0 address is less than token1 for consistent ordering
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
    }

    function _fundTestAccounts() internal {
        // Fund alice and bob with initial amounts
        token0.mint(alice, INITIAL_MINT_AMOUNT);
        token1.mint(alice, INITIAL_MINT_AMOUNT);
        token0.mint(bob, INITIAL_MINT_AMOUNT);
        token1.mint(bob, INITIAL_MINT_AMOUNT);
        token0.mint(owner, INITIAL_MINT_AMOUNT);
        token1.mint(owner, INITIAL_MINT_AMOUNT);

        // Approve diamond and LP token for all test accounts
        vm.startPrank(alice);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        token0.approve(address(lpToken), type(uint256).max);
        token1.approve(address(lpToken), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        token0.approve(address(lpToken), type(uint256).max);
        token1.approve(address(lpToken), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(owner);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        token0.approve(address(lpToken), type(uint256).max);
        token1.approve(address(lpToken), type(uint256).max);
        vm.stopPrank();
    }

    // Helper function to provide liquidity using multi-token minting
    function _provideLiquidity(
        address provider,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 shares) {
        vm.startPrank(provider);
        // Get total number of vertices for array size
        uint8 numVertices = simplexFacet.numVertices();
        uint128[] memory amounts = new uint128[](numVertices);
        // token0 and token1 are added in order to the simplex
        amounts[0] = uint128(amount0); // token0
        amounts[1] = uint128(amount1); // token1
        // All other positions are 0 by default
        shares = lpToken.mint(provider, amounts);
        vm.stopPrank();
    }

    function testBurveMint() public {
        uint256 amount0 = INITIAL_DEPOSIT_AMOUNT;
        uint256 amount1 = INITIAL_DEPOSIT_AMOUNT;

        // Check initial balances
        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);
        uint256 aliceLPBefore = lpToken.balanceOf(alice);

        // Provide initial liquidity with both tokens
        uint256 shares = _provideLiquidity(alice, amount0, amount1);

        // Verify shares were minted
        assertGt(shares, 0, "Should have received LP tokens");
        assertGt(
            lpToken.balanceOf(alice) - aliceLPBefore,
            0,
            "Should have received LP tokens"
        );

        // Verify tokens were transferred
        assertApproxEqAbs(
            token0.balanceOf(alice),
            aliceToken0Before - amount0,
            1,
            "Incorrect token0 balance after mint"
        );
        assertApproxEqAbs(
            token1.balanceOf(alice),
            aliceToken1Before - amount1,
            1,
            "Incorrect token1 balance after mint"
        );
    }

    function testBurveBurn() public {
        // First provide liquidity
        uint256 amount0 = INITIAL_DEPOSIT_AMOUNT;
        uint256 amount1 = INITIAL_DEPOSIT_AMOUNT;
        uint256 shares = _provideLiquidity(alice, amount0, amount1);

        // Check balances before burn
        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);

        // Remove all liquidity using LP token
        vm.startPrank(alice);
        lpToken.burn(alice, shares);
        vm.stopPrank();

        // Verify tokens were returned
        assertGt(
            token0.balanceOf(alice),
            aliceToken0Before,
            "Should have received token0 back"
        );
        assertGt(
            token1.balanceOf(alice),
            aliceToken1Before,
            "Should have received token1 back"
        );
        assertEq(
            lpToken.balanceOf(alice),
            0,
            "Should have burned all LP tokens"
        );
    }

    function testBurvePartialBurn() public {
        // First provide liquidity
        uint256 amount0 = INITIAL_DEPOSIT_AMOUNT;
        uint256 amount1 = INITIAL_DEPOSIT_AMOUNT;
        uint256 totalShares = _provideLiquidity(alice, amount0, amount1);
        uint256 burnAmount = totalShares / 2;

        // Check balances before burn
        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);
        uint256 aliceLPBefore = lpToken.balanceOf(alice);

        // Remove half of liquidity using LP token
        vm.startPrank(alice);
        lpToken.burn(alice, burnAmount);
        vm.stopPrank();

        // Verify tokens were returned
        assertGt(
            token0.balanceOf(alice),
            aliceToken0Before,
            "Should have received token0 back"
        );
        assertGt(
            token1.balanceOf(alice),
            aliceToken1Before,
            "Should have received token1 back"
        );
        assertEq(
            lpToken.balanceOf(alice),
            aliceLPBefore - burnAmount,
            "Should have burned half of LP tokens"
        );
    }

    function testBurveSwap() public {
        // First provide liquidity
        uint256 amount0 = INITIAL_LIQUIDITY_AMOUNT;
        uint256 amount1 = INITIAL_LIQUIDITY_AMOUNT;
        _provideLiquidity(alice, amount0, amount1);

        // Prepare for swap
        uint256 swapAmount = 10e18;
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        // Perform swap token0 -> token1
        vm.startPrank(bob);
        (uint256 inAmount, uint256 outAmount) = swapFacet.swap(
            bob, // recipient
            address(token0), // tokenIn
            address(token1), // tokenOut
            int256(swapAmount), // positive for exact input
            MIN_SQRT_PRICE_X96 + 1 // no price limit for this test
        );
        vm.stopPrank();

        // Verify balances after swap
        assertEq(
            token0.balanceOf(bob),
            bobToken0Before - swapAmount,
            "Incorrect token0 balance after swap"
        );
        assertGt(
            token1.balanceOf(bob),
            bobToken1Before,
            "Should have received token1"
        );

        // Perform reverse swap token1 -> token0
        uint256 token1Received = token1.balanceOf(bob) - bobToken1Before;
        bobToken0Before = token0.balanceOf(bob);
        bobToken1Before = token1.balanceOf(bob);

        vm.startPrank(bob);
        (inAmount, outAmount) = swapFacet.swap(
            bob, // recipient
            address(token1), // tokenIn
            address(token0), // tokenOut
            int256(token1Received), // positive for exact input
            MAX_SQRT_PRICE_X96 - 1 // no price limit for this test
        );
        vm.stopPrank();

        // Verify balances after reverse swap
        assertEq(
            token1.balanceOf(bob),
            bobToken1Before - token1Received,
            "Incorrect token1 balance after reverse swap"
        );
        assertGt(
            token0.balanceOf(bob),
            bobToken0Before,
            "Should have received token0"
        );

        // TODO: Add more assertions for pool state and price impact
    }
}
