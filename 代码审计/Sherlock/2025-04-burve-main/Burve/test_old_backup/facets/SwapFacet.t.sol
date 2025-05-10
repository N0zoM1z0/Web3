// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BurveFacets, InitLib} from "../../src/InitLib.sol";
import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {EdgeFacet} from "../../src/multi/facets/EdgeFacet.sol";
import {ViewFacet} from "../../src/multi/facets/ViewFacet.sol";
import {LiqFacet} from "../../src/multi/facets/LiqFacet.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ClosureId, newClosureId} from "../../src/multi/Closure.sol";
import {VaultType} from "../../src/multi/VaultProxy.sol";
import {Store} from "../../src/multi/Store.sol";
import {Edge} from "../../src/multi/Edge.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";

contract SwapFacetTest is Test {
    SimplexDiamond public diamond;
    EdgeFacet public edgeFacet;
    LiqFacet public liqFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    ViewFacet public viewFacet;

    MockERC20 public token0;
    MockERC20 public token1;

    MockERC4626 public mockVault0;
    MockERC4626 public mockVault1;

    uint256 eveShares0;
    uint256 eveShares1;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public eve = makeAddr("eve");

    uint16 public closureId;
    uint256 constant INITIAL_MINT_AMOUNT = 1000000e18;
    uint256 constant INITIAL_LIQUIDITY_AMOUNT = 100000e18;

    uint160 constant MIN_SQRT_RATIO = 4295128739;
    uint160 constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    uint160 MIN_SQRT_RATIO_LIMIT = MIN_SQRT_RATIO + 1;
    uint160 MAX_SQRT_RATIO_LIMIT = MAX_SQRT_RATIO - 1;

    // Price impact thresholds
    uint256 constant SMALL_SWAP_IMPACT_THRESHOLD = 2e16; // 2%
    uint256 constant LARGE_SWAP_IMPACT_THRESHOLD = 2e17; // 20%

    function setUp() public {
        vm.startPrank(owner);

        // Deploy the diamond and facets
        BurveFacets memory facets = InitLib.deployFacets();
        diamond = new SimplexDiamond(facets);

        edgeFacet = EdgeFacet(address(diamond));
        liqFacet = LiqFacet(address(diamond));
        simplexFacet = SimplexFacet(address(diamond));
        swapFacet = SwapFacet(address(diamond));
        viewFacet = ViewFacet(address(diamond));

        // Setup test tokens
        token0 = new MockERC20("Test Token 0", "TEST0", 18);
        token1 = new MockERC20("Test Token 1", "TEST1", 18);

        // Ensure token0 address is less than token1
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        mockVault0 = new MockERC4626(token0, "Mock Vault 0", "MVLT0");
        mockVault1 = new MockERC4626(token1, "Mock Vault 1", "MVLT1");

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

        // Setup closure
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        closureId = ClosureId.unwrap(viewFacet.getClosureId(tokens));

        // Setup edge
        edgeFacet.setEdge(
            address(token0),
            address(token1),
            100, // what should the ampliude be set to
            -46063,
            46063
        );

        vm.stopPrank();

        // Fund test accounts
        _fundTestAccounts();

        // Setup initial liquidity
        _setupInitialLiquidity();
    }

    function _fundTestAccounts() internal {
        // Fund alice and bob with initial amounts
        token0.mint(alice, INITIAL_MINT_AMOUNT);
        token1.mint(alice, INITIAL_MINT_AMOUNT);
        token0.mint(bob, INITIAL_MINT_AMOUNT);
        token1.mint(bob, INITIAL_MINT_AMOUNT);
        token0.mint(eve, INITIAL_MINT_AMOUNT);
        token1.mint(eve, INITIAL_MINT_AMOUNT);

        // Approve diamond for all test accounts
        vm.startPrank(alice);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(eve);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        vm.stopPrank();
    }

    function _setupInitialLiquidity() internal {
        vm.startPrank(eve);
        uint128[] memory amounts0 = new uint128[](2);
        amounts0[0] = uint128(INITIAL_LIQUIDITY_AMOUNT);
        amounts0[1] = 0;
        eveShares0 = liqFacet.addLiq(alice, closureId, amounts0);

        uint128[] memory amounts1 = new uint128[](2);
        amounts1[0] = 0;
        amounts1[1] = uint128(INITIAL_LIQUIDITY_AMOUNT);
        eveShares1 = liqFacet.addLiq(alice, closureId, amounts1);
        vm.stopPrank();
    }

    function testExactInputSwap() public {
        uint256 swapAmount = 1e18;
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        vm.startPrank(bob);
        swapFacet.swap(
            bob, // recipient
            address(token0), // tokenIn
            address(token1), // tokenOut
            int256(swapAmount), // positive for exact input
            MIN_SQRT_RATIO + 1 // no price limit
        );
        vm.stopPrank();

        // Verify token0 was taken
        assertEq(
            token0.balanceOf(bob),
            bobToken0Before - swapAmount,
            "Incorrect token0 balance after swap"
        );

        // Verify some token1 was received
        assertGt(
            token1.balanceOf(bob),
            bobToken1Before,
            "Should have received token1"
        );
    }

    function testExactOutputSwap() public {
        uint256 outputAmount = 1000e18;
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        vm.startPrank(bob);
        swapFacet.swap(
            bob, // recipient
            address(token0), // tokenIn
            address(token1), // tokenOut
            -int256(outputAmount), // negative for exact output
            MIN_SQRT_RATIO_LIMIT // price limit
        );
        vm.stopPrank();

        // Verify exact token1 was received
        assertEq(
            token1.balanceOf(bob),
            bobToken1Before + outputAmount,
            "Should have received exact token1 amount"
        );

        // Verify some token0 was taken
        assertLt(
            token0.balanceOf(bob),
            bobToken0Before,
            "Should have spent token0"
        );
    }

    function testSwapWithPriceLimit() public {
        uint256 swapAmount = 1000e18;
        uint160 sqrtPriceLimit = 79928162514264337593543950336; // ~1:1 price

        // Get initial price from edge using actual balances
        uint256 balance0 = token0.balanceOf(address(mockVault0));
        uint256 balance1 = token1.balanceOf(address(mockVault1));
        uint256 priceX128Before = viewFacet.getPriceX128(
            address(token0),
            address(token1),
            uint128(balance0),
            uint128(balance1)
        );

        vm.startPrank(bob);
        swapFacet.swap(
            bob,
            address(token1),
            address(token0),
            int256(swapAmount),
            sqrtPriceLimit
        );
        vm.stopPrank();

        // Get final price using updated balances
        balance0 = token0.balanceOf(address(mockVault0));
        balance1 = token1.balanceOf(address(mockVault1));
        uint256 priceX128After = viewFacet.getPriceX128(
            address(token0),
            address(token1),
            uint128(balance0),
            uint128(balance1)
        );

        // Verify price changed but didn't exceed limit
        assertGt(
            priceX128After,
            priceX128Before,
            "Price should increase for token1->token0 swap"
        );
    }

    function testSmallSwapPriceImpact() public {
        uint256 swapAmount = INITIAL_LIQUIDITY_AMOUNT / 100; // 1% of pool liquidity
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        // Get initial price using actual balances
        uint256 balance0 = token0.balanceOf(address(mockVault0));
        uint256 balance1 = token1.balanceOf(address(mockVault1));
        uint256 priceX128Before = viewFacet.getPriceX128(
            address(token0),
            address(token1),
            uint128(balance0),
            uint128(balance1)
        );

        vm.startPrank(bob);
        swapFacet.swap(
            bob,
            address(token0),
            address(token1),
            int256(swapAmount),
            MIN_SQRT_RATIO_LIMIT
        );
        vm.stopPrank();

        // Get final price using updated balances
        balance0 = token0.balanceOf(address(mockVault0));
        balance1 = token1.balanceOf(address(mockVault1));
        uint256 priceX128After = viewFacet.getPriceX128(
            address(token0),
            address(token1),
            uint128(balance0),
            uint128(balance1)
        );

        // Calculate price impact
        uint256 priceImpact = ((
            priceX128After > priceX128Before
                ? priceX128After - priceX128Before
                : priceX128Before - priceX128After
        ) * 1e18) / priceX128Before;

        assertLt(
            priceImpact,
            SMALL_SWAP_IMPACT_THRESHOLD,
            "Small swap should have minimal price impact"
        );

        // Verify output amount is close to input amount (minimal slippage)
        uint256 token1Received = token1.balanceOf(bob) - bobToken1Before;
        assertApproxEqRel(
            token1Received,
            swapAmount,
            SMALL_SWAP_IMPACT_THRESHOLD,
            "Small swap should have minimal slippage"
        );
    }

    function testLargeSwapImpact() public {
        uint256 largeSwapAmount = INITIAL_LIQUIDITY_AMOUNT / 2; // 50% of pool liquidity
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        // Get initial price using actual balances
        uint256 balance0 = token0.balanceOf(address(mockVault0));
        uint256 balance1 = token1.balanceOf(address(mockVault1));
        uint256 priceX128Before = viewFacet.getPriceX128(
            address(token0),
            address(token1),
            uint128(balance0),
            uint128(balance1)
        );

        vm.startPrank(bob);
        swapFacet.swap(
            bob,
            address(token0),
            address(token1),
            int256(largeSwapAmount),
            MIN_SQRT_RATIO_LIMIT
        );
        vm.stopPrank();

        // Get final price using updated balances
        balance0 = token0.balanceOf(address(mockVault0));
        balance1 = token1.balanceOf(address(mockVault1));
        uint256 priceX128After = viewFacet.getPriceX128(
            address(token0),
            address(token1),
            uint128(balance0),
            uint128(balance1)
        );

        // Calculate price impact
        uint256 priceImpact = ((
            priceX128After > priceX128Before
                ? priceX128After - priceX128Before
                : priceX128Before - priceX128After
        ) * 1e18) / priceX128Before;

        assertGt(
            priceImpact,
            SMALL_SWAP_IMPACT_THRESHOLD,
            "Large swap should have significant price impact"
        );

        // Verify output amount shows significant slippage
        uint256 token1Received = token1.balanceOf(bob) - bobToken1Before;
        assertLt(
            token1Received,
            largeSwapAmount,
            "Large swap should have significant slippage"
        );
    }

    function testSequentialSwapsIncreasePriceImpact() public {
        uint256 swapAmount = INITIAL_LIQUIDITY_AMOUNT / 10; // 10% each swap

        // Get initial price using actual balances
        uint256 balance0 = token0.balanceOf(address(mockVault0));
        uint256 balance1 = token1.balanceOf(address(mockVault1));
        uint256 initialPriceX128 = viewFacet.getPriceX128(
            address(token0),
            address(token1),
            uint128(balance0),
            uint128(balance1)
        );
        uint256 lastPriceX128 = initialPriceX128;

        // Perform multiple swaps
        for (uint i = 0; i < 3; i++) {
            vm.startPrank(bob);
            swapFacet.swap(
                bob,
                address(token0),
                address(token1),
                int256(swapAmount),
                MIN_SQRT_RATIO_LIMIT
            );
            vm.stopPrank();

            // Get new price using updated balances
            balance0 = token0.balanceOf(address(mockVault0));
            balance1 = token1.balanceOf(address(mockVault1));
            uint256 newPriceX128 = viewFacet.getPriceX128(
                address(token0),
                address(token1),
                uint128(balance0),
                uint128(balance1)
            );

            // Calculate price impact for this swap
            uint256 swapImpact = ((
                newPriceX128 > lastPriceX128
                    ? newPriceX128 - lastPriceX128
                    : lastPriceX128 - newPriceX128
            ) * 1e18) / lastPriceX128;

            // Each subsequent swap should have larger price impact
            if (i > 0) {
                uint256 lastImpact = ((
                    lastPriceX128 > initialPriceX128
                        ? lastPriceX128 - initialPriceX128
                        : initialPriceX128 - lastPriceX128
                ) * 1e18) / initialPriceX128;
                assertGt(
                    lastImpact,
                    swapImpact,
                    "Sequential swaps should have increasing price impact"
                );
            }

            lastPriceX128 = newPriceX128;
        }
    }

    function testSwapRevertZeroAmount() public {
        vm.startPrank(bob);
        vm.expectRevert(); // Should revert for zero amount
        swapFacet.swap(bob, address(token0), address(token1), 0, 0);
        vm.stopPrank();
    }

    function testSwapRevertInvalidTokenPair() public {
        MockERC20 invalidToken = new MockERC20("Invalid Token", "INVALID", 18);

        vm.startPrank(bob);
        vm.expectRevert(); // Should revert for invalid token pair
        swapFacet.swap(
            bob,
            address(invalidToken),
            address(token1),
            int256(1000e18),
            0
        );
        vm.stopPrank();
    }

    function testSwapToSelf() public {
        uint256 swapAmount = 1000e18;

        vm.startPrank(bob);
        vm.expectRevert(); // Should revert when trying to swap a token for itself
        swapFacet.swap(
            bob,
            address(token0),
            address(token0),
            int256(swapAmount),
            0
        );
        vm.stopPrank();
    }

    function testSwapAndRemoveLiquidity() public {
        uint256 swapAmount = INITIAL_LIQUIDITY_AMOUNT / 10;
        uint256 depositAmount = INITIAL_LIQUIDITY_AMOUNT / 2;
        console2.log("deposit amount", depositAmount);

        // First swap
        vm.startPrank(bob);
        swapFacet.swap(
            bob,
            address(token0),
            address(token1),
            int256(swapAmount),
            MIN_SQRT_RATIO_LIMIT
        );
        vm.stopPrank();

        // Then remove liquidity
        vm.startPrank(alice);
        uint128[] memory amounts0 = new uint128[](2);
        amounts0[0] = uint128(depositAmount);
        amounts0[1] = 0;
        uint256 shares0 = liqFacet.addLiq(alice, closureId, amounts0);

        uint128[] memory amounts1 = new uint128[](2);
        amounts1[0] = 0;
        amounts1[1] = uint128(depositAmount);
        uint256 shares1 = liqFacet.addLiq(alice, closureId, amounts1);

        uint256 token0Before = token0.balanceOf(alice);
        uint256 token1Before = token1.balanceOf(alice);

        liqFacet.removeLiq(alice, closureId, shares0);
        liqFacet.removeLiq(alice, closureId, shares1);

        // Verify tokens returned proportionally
        assertGt(
            token0.balanceOf(alice) - token0Before,
            token1.balanceOf(alice) - token1Before,
            "Should receive more token0 than token1 due to the swap pushing the price"
        );
        vm.stopPrank();
    }

    function testConcurrentUsersOperations() public {
        address charlie = makeAddr("charlie");
        address dave = makeAddr("dave");

        // Fund additional users
        token0.mint(charlie, INITIAL_MINT_AMOUNT);
        token1.mint(charlie, INITIAL_MINT_AMOUNT);
        token0.mint(dave, INITIAL_MINT_AMOUNT);
        token1.mint(dave, INITIAL_MINT_AMOUNT);

        vm.startPrank(charlie);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(dave);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        vm.stopPrank();

        // Multiple users perform operations
        uint256 amount = INITIAL_LIQUIDITY_AMOUNT / 10;

        // Charlie adds liquidity
        vm.startPrank(charlie);
        uint128[] memory amounts0 = new uint128[](2);
        amounts0[0] = uint128(amount);
        amounts0[1] = 0;
        liqFacet.addLiq(charlie, closureId, amounts0);

        uint128[] memory amounts1 = new uint128[](2);
        amounts1[0] = 0;
        amounts1[1] = uint128(amount);
        liqFacet.addLiq(charlie, closureId, amounts1);
        vm.stopPrank();

        // Bob swaps
        vm.startPrank(bob);
        swapFacet.swap(
            bob,
            address(token0),
            address(token1),
            int256(amount),
            MIN_SQRT_RATIO_LIMIT
        );
        vm.stopPrank();

        // Dave adds liquidity
        vm.startPrank(dave);
        uint128[] memory amounts2 = new uint128[](2);
        amounts2[0] = uint128(amount);
        amounts2[1] = 0;
        liqFacet.addLiq(dave, closureId, amounts2);

        uint128[] memory amounts3 = new uint128[](2);
        amounts3[0] = 0;
        amounts3[1] = uint128(amount);
        liqFacet.addLiq(dave, closureId, amounts3);
        vm.stopPrank();

        // Alice removes liquidity
        vm.startPrank(alice);
        uint128[] memory amounts4 = new uint128[](2);
        amounts4[0] = uint128(amount);
        amounts4[1] = 0;
        uint256 shares0 = liqFacet.addLiq(alice, closureId, amounts4);

        uint128[] memory amounts5 = new uint128[](2);
        amounts5[0] = 0;
        amounts5[1] = uint128(amount);
        uint256 shares1 = liqFacet.addLiq(alice, closureId, amounts5);

        liqFacet.removeLiq(alice, closureId, shares0);
        liqFacet.removeLiq(alice, closureId, shares1);
        vm.stopPrank();
    }
}
