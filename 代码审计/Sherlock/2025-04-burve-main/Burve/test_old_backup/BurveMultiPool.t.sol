// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BurveFacets, InitLib} from "../src/InitLib.sol";
import {SimplexDiamond} from "../src/multi/Diamond.sol";
import {EdgeFacet} from "../src/multi/facets/EdgeFacet.sol";
import {LiqFacet} from "../src/multi/facets/LiqFacet.sol";
import {SimplexFacet} from "../src/multi/facets/SimplexFacet.sol";
import {SwapFacet} from "../src/multi/facets/SwapFacet.sol";
import {ViewFacet} from "../src/multi/facets/ViewFacet.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ClosureId, newClosureId} from "../src/multi/Closure.sol";
import {VaultType} from "../src/multi/VaultProxy.sol";
import {MockERC4626} from "./mocks/MockERC4626.sol";
import {BurveMultiLPToken} from "../src/multi/LPToken.sol";

contract BurveMultiPoolTest is Test {
    SimplexDiamond public diamond;
    LiqFacet public liqFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    ViewFacet public viewFacet;

    // LP tokens for each pair
    BurveMultiLPToken public lpToken01;
    BurveMultiLPToken public lpToken12;
    BurveMultiLPToken public lpToken02;

    // Test tokens
    MockERC20 public token0;
    MockERC20 public token1;
    MockERC20 public token2;

    // Test vaults
    MockERC4626 public mockVault0;
    MockERC4626 public mockVault1;
    MockERC4626 public mockVault2;

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

    // Test closure IDs for each token pair
    uint16 public closure01Id; // token0-token1 pair
    uint16 public closure12Id; // token1-token2 pair
    uint16 public closure02Id; // token0-token2 pair

    function setUp() public {
        vm.startPrank(owner);

        // Deploy the diamond and facets
        BurveFacets memory burveFacets = InitLib.deployFacets();

        diamond = new SimplexDiamond(burveFacets);

        // Cast the diamond address to the facet interfaces
        liqFacet = LiqFacet(address(diamond));
        simplexFacet = SimplexFacet(address(diamond));
        swapFacet = SwapFacet(address(diamond));
        viewFacet = ViewFacet(address(diamond));

        // Setup test tokens and vaults
        _setupTestTokens();

        mockVault0 = new MockERC4626(token0, "Mock Vault 0", "MVLT0");
        mockVault1 = new MockERC4626(token1, "Mock Vault 1", "MVLT1");
        mockVault2 = new MockERC4626(token2, "Mock Vault 2", "MVLT2");

        // Add vertices
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
        simplexFacet.addVertex(
            address(token2),
            address(mockVault2),
            VaultType.E4626
        );

        // Setup edges between all pairs
        _setupEdge(token0, token1);
        _setupEdge(token1, token2);
        _setupEdge(token0, token2);

        // Setup closures and LP tokens
        _setupClosuresAndLPTokens();

        vm.stopPrank();

        // Fund test accounts
        _fundTestAccounts();

        // Add initial liquidity
        _provideLiquidity(
            owner,
            owner,
            lpToken01,
            INITIAL_LIQUIDITY_AMOUNT,
            INITIAL_LIQUIDITY_AMOUNT,
            INITIAL_DEPOSIT_AMOUNT
        );
        _provideLiquidity(
            owner,
            owner,
            lpToken12,
            INITIAL_LIQUIDITY_AMOUNT,
            INITIAL_LIQUIDITY_AMOUNT,
            INITIAL_DEPOSIT_AMOUNT
        );
        _provideLiquidity(
            owner,
            owner,
            lpToken02,
            INITIAL_LIQUIDITY_AMOUNT,
            INITIAL_LIQUIDITY_AMOUNT,
            INITIAL_DEPOSIT_AMOUNT
        );
    }

    function _setupTestTokens() internal {
        // Deploy tokens with 18 decimals
        token0 = new MockERC20("Test Token 0", "TEST0", 18);
        token1 = new MockERC20("Test Token 1", "TEST1", 18);
        token2 = new MockERC20("Test Token 2", "TEST2", 18);

        // Sort tokens by address
        _sortTokens();
    }

    function _sortTokens() internal {
        // Bubble sort the tokens by address
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
        if (address(token1) > address(token2)) {
            (token1, token2) = (token2, token1);
            if (address(token0) > address(token1)) {
                (token0, token1) = (token1, token0);
            }
        }
    }

    function _setupClosuresAndLPTokens() internal {
        // Setup closure for token0-token1 pair
        address[] memory tokens01 = new address[](2);
        tokens01[0] = address(token0);
        tokens01[1] = address(token1);
        closure01Id = ClosureId.unwrap(viewFacet.getClosureId(tokens01));
        lpToken01 = new BurveMultiLPToken(
            ClosureId.wrap(closure01Id),
            address(diamond)
        );

        // Setup closure for token1-token2 pair
        address[] memory tokens12 = new address[](2);
        tokens12[0] = address(token1);
        tokens12[1] = address(token2);
        closure12Id = ClosureId.unwrap(viewFacet.getClosureId(tokens12));
        lpToken12 = new BurveMultiLPToken(
            ClosureId.wrap(closure12Id),
            address(diamond)
        );

        // Setup closure for token0-token2 pair
        address[] memory tokens02 = new address[](2);
        tokens02[0] = address(token0);
        tokens02[1] = address(token2);
        closure02Id = ClosureId.unwrap(viewFacet.getClosureId(tokens02));
        lpToken02 = new BurveMultiLPToken(
            ClosureId.wrap(closure02Id),
            address(diamond)
        );
    }

    function _fundTestAccounts() internal {
        // Fund accounts
        token0.mint(alice, INITIAL_MINT_AMOUNT);
        token1.mint(alice, INITIAL_MINT_AMOUNT);
        token2.mint(alice, INITIAL_MINT_AMOUNT);
        token0.mint(bob, INITIAL_MINT_AMOUNT);
        token1.mint(bob, INITIAL_MINT_AMOUNT);
        token2.mint(bob, INITIAL_MINT_AMOUNT);
        token0.mint(owner, INITIAL_MINT_AMOUNT);
        token1.mint(owner, INITIAL_MINT_AMOUNT);
        token2.mint(owner, INITIAL_MINT_AMOUNT);

        // Approve tokens for all accounts
        vm.startPrank(alice);
        _approveTokens(alice);
        vm.stopPrank();

        vm.startPrank(bob);
        _approveTokens(bob);
        vm.stopPrank();

        vm.startPrank(owner);
        _approveTokens(owner);
        vm.stopPrank();
    }

    function _approveTokens(address account) internal {
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        token2.approve(address(diamond), type(uint256).max);
        token0.approve(address(lpToken01), type(uint256).max);
        token0.approve(address(lpToken02), type(uint256).max);
        token1.approve(address(lpToken01), type(uint256).max);
        token1.approve(address(lpToken12), type(uint256).max);
        token2.approve(address(lpToken12), type(uint256).max);
        token2.approve(address(lpToken02), type(uint256).max);
    }

    function _setupEdge(MockERC20 tokenA, MockERC20 tokenB) internal {
        EdgeFacet(address(diamond)).setEdge(
            address(tokenA),
            address(tokenB),
            101, // amplitude
            -46063, // lowTick
            46063 // highTick
        );
    }

    // Helper function to provide liquidity using LP token
    function _provideLiquidity(
        address provider,
        address payer,
        BurveMultiLPToken lpToken,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    ) internal returns (uint256 shares) {
        vm.startPrank(payer);
        // Get total number of vertices for array size
        uint8 numVertices = simplexFacet.numVertices();
        uint128[] memory amounts = new uint128[](numVertices);

        // For lpToken01 (token0-token1 pair)
        if (address(lpToken) == address(lpToken01)) {
            amounts[0] = uint128(amount0); // token0
            amounts[1] = uint128(amount1); // token1
            // amounts[2] is 0 by default
            shares = lpToken.mint(provider, amounts);
        }
        // For lpToken12 (token1-token2 pair)
        else if (address(lpToken) == address(lpToken12)) {
            // amounts[0] is 0 by default
            amounts[1] = uint128(amount1); // token1
            amounts[2] = uint128(amount2); // token2
            shares = lpToken.mint(provider, amounts);
        }
        // For lpToken02 (token0-token2 pair)
        else if (address(lpToken) == address(lpToken02)) {
            amounts[0] = uint128(amount0); // token0
            // amounts[1] is 0 by default
            amounts[2] = uint128(amount2); // token2
            shares = lpToken.mint(provider, amounts);
        } else {
            revert("Invalid LP token");
        }

        vm.stopPrank();
    }

    function testTriangleSetup() public {
        // Provide liquidity to all pairs
        uint256 shares01 = _provideLiquidity(
            alice,
            alice,
            lpToken01,
            INITIAL_DEPOSIT_AMOUNT,
            INITIAL_DEPOSIT_AMOUNT,
            0 // token2 not used in this pair
        );

        uint256 shares12 = _provideLiquidity(
            alice,
            alice,
            lpToken12,
            0, // token0 not used in this pair
            INITIAL_DEPOSIT_AMOUNT,
            INITIAL_DEPOSIT_AMOUNT
        );

        uint256 shares02 = _provideLiquidity(
            alice,
            alice,
            lpToken02,
            INITIAL_DEPOSIT_AMOUNT,
            0, // token1 not used in this pair
            INITIAL_DEPOSIT_AMOUNT
        );

        // Verify all shares were minted
        assertGt(
            shares01 * shares12 * shares02,
            0,
            "All shares should be non-zero"
        );

        // Verify LP token balances
        assertGt(lpToken01.balanceOf(alice), 0, "Should have LP01 tokens");
        assertGt(lpToken12.balanceOf(alice), 0, "Should have LP12 tokens");
        assertGt(lpToken02.balanceOf(alice), 0, "Should have LP02 tokens");
    }

    function testTriangleBurn() public {
        // First provide liquidity to all pairs
        uint256 shares01 = _provideLiquidity(
            alice,
            alice,
            lpToken01,
            INITIAL_DEPOSIT_AMOUNT,
            INITIAL_DEPOSIT_AMOUNT,
            0 // token2 not used in this pair
        );

        uint256 shares12 = _provideLiquidity(
            alice,
            alice,
            lpToken12,
            0, // token0 not used in this pair
            INITIAL_DEPOSIT_AMOUNT,
            INITIAL_DEPOSIT_AMOUNT
        );

        uint256 shares02 = _provideLiquidity(
            alice,
            alice,
            lpToken02,
            INITIAL_DEPOSIT_AMOUNT,
            0, // token1 not used in this pair
            INITIAL_DEPOSIT_AMOUNT
        );

        // Record balances before burning
        uint256 token0Before = token0.balanceOf(alice);
        uint256 token1Before = token1.balanceOf(alice);
        uint256 token2Before = token2.balanceOf(alice);

        // Burn all LP tokens
        vm.startPrank(alice);
        lpToken01.burn(alice, shares01);
        lpToken12.burn(alice, shares12);
        lpToken02.burn(alice, shares02);
        vm.stopPrank();

        // Verify tokens were returned
        assertGt(
            token0.balanceOf(alice),
            token0Before,
            "Should have received token0 back"
        );
        assertGt(
            token1.balanceOf(alice),
            token1Before,
            "Should have received token1 back"
        );
        assertGt(
            token2.balanceOf(alice),
            token2Before,
            "Should have received token2 back"
        );

        // Verify LP tokens were burned
        assertEq(
            lpToken01.balanceOf(alice),
            0,
            "Should have burned all LP01 tokens"
        );
        assertEq(
            lpToken12.balanceOf(alice),
            0,
            "Should have burned all LP12 tokens"
        );
        assertEq(
            lpToken02.balanceOf(alice),
            0,
            "Should have burned all LP02 tokens"
        );
    }

    function testTriangleSwap() public {
        uint256 swapAmount = 10e18;
        uint256 bobToken0Before = token0.balanceOf(bob);

        // Perform swap token0 -> token1 -> token2
        vm.startPrank(bob);
        (uint256 inAmount0, uint256 outAmount1) = swapFacet.swap(
            bob,
            address(token0),
            address(token1),
            int256(swapAmount),
            MIN_SQRT_PRICE_X96 + 1
        );

        (uint256 inAmount1, uint256 outAmount2) = swapFacet.swap(
            bob,
            address(token1),
            address(token2),
            int256(outAmount1),
            MIN_SQRT_PRICE_X96 + 1
        );
        vm.stopPrank();

        // Verify the full path swap worked
        assertEq(
            token0.balanceOf(bob),
            bobToken0Before - swapAmount,
            "Should have spent correct amount of token0"
        );
        assertGt(outAmount2, 0, "Should have received token2");
    }
}
