// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BurveFacets, InitLib} from "../../src/InitLib.sol";
import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {EdgeFacet} from "../../src/multi/facets/EdgeFacet.sol";
import {LiqFacet} from "../../src/multi/facets/LiqFacet.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {ViewFacet} from "../../src/multi/facets/ViewFacet.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ClosureId, newClosureId} from "../../src/multi/Closure.sol";
import {VaultType} from "../../src/multi/VaultProxy.sol";
import {FullMath} from "../../src/FullMath.sol";
import {Store} from "../../src/multi/Store.sol";
import {Edge} from "../../src/multi/Edge.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";

contract LiqFacetTest is Test {
    SimplexDiamond public diamond;
    EdgeFacet public edgeFacet;
    LiqFacet public liqFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    ViewFacet public viewFacet;

    MockERC20 public token0;
    MockERC20 public token1;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // shares that the pool is seeded with in the
    uint256 seed;

    // Swap constants
    uint128 constant MIN_SQRT_PRICE_X96 = uint128(1 << 96) / 1000;
    uint128 constant MAX_SQRT_PRICE_X96 = uint128(1000 << 96);

    uint16 public closureId;
    uint256 constant INITIAL_MINT_AMOUNT = 1000000e18;
    uint256 constant INITIAL_LIQUIDITY_AMOUNT = 100_000e18;
    uint256 constant SMALL_DEPOSIT_AMOUNT = 10e18;

    MockERC4626 public mockVault0;
    MockERC4626 public mockVault1;

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
        vm.label(address(token0), "token0");
        vm.label(address(token1), "token1");

        // Ensure token0 address is less than token1
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Setup mock ERC4626 vaults
        mockVault0 = new MockERC4626(token0, "Mock Vault 0", "MVLT0");
        mockVault1 = new MockERC4626(token1, "Mock Vault 1", "MVLT1");

        // Add vertices with mock vaults
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

        // fetch closure
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        closureId = ClosureId.unwrap(viewFacet.getClosureId(tokens));

        // Setup edge
        edgeFacet.setEdge(address(token0), address(token1), 100, -100, 100);

        vm.stopPrank();

        // Fund test accounts
        _fundTestAccounts();

        vm.startPrank(owner);
        // Add initial liquidity with multi-amount deposit
        uint128[] memory initAmounts = new uint128[](2);
        initAmounts[0] = uint128(INITIAL_LIQUIDITY_AMOUNT);
        initAmounts[1] = uint128(INITIAL_LIQUIDITY_AMOUNT);
        seed = liqFacet.addLiq(owner, closureId, initAmounts);
        vm.stopPrank();
    }

    function _fundTestAccounts() internal {
        // Fund alice and bob with initial amounts
        token0.mint(alice, INITIAL_MINT_AMOUNT);
        token1.mint(alice, INITIAL_MINT_AMOUNT);
        token0.mint(bob, INITIAL_MINT_AMOUNT);
        token1.mint(bob, INITIAL_MINT_AMOUNT);
        token0.mint(owner, INITIAL_MINT_AMOUNT);
        token1.mint(owner, INITIAL_MINT_AMOUNT);

        // Approve diamond for all test accounts
        vm.startPrank(alice);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(owner);
        token0.approve(address(diamond), type(uint256).max);
        token1.approve(address(diamond), type(uint256).max);
        vm.stopPrank();
    }

    /// removes the seeded liquidity in the setUp function
    function testRemoveSeedLiquidity() public {
        vm.startPrank(owner);
        liqFacet.removeLiq(owner, closureId, seed);
        vm.stopPrank();
    }

    // TODO (terence) examine
    function testSwapThenRemoveSeedLiquidity() public {
        vm.startPrank(bob);
        swapFacet.swap(
            bob,
            address(token0),
            address(token1),
            int256(10e18),
            MIN_SQRT_PRICE_X96 + 1
        );
        vm.stopPrank();
        vm.startPrank(owner);
        liqFacet.removeLiq(owner, closureId, seed);
        vm.stopPrank();
    }

    function testImpreciseCID() public {
        vm.startPrank(alice);

        uint128[] memory amounts = new uint128[](2);
        amounts[0] = uint128(INITIAL_LIQUIDITY_AMOUNT);
        amounts[1] = uint128(INITIAL_LIQUIDITY_AMOUNT);
        // With only two vertices there's no problem adding liquidity but there will be unused bits.
        vm.expectRevert(
            abi.encodeWithSelector(LiqFacet.ImpreciseCID.selector, 0x8)
        );
        uint256 shares = liqFacet.addLiq(alice, 0xb, amounts);
    }

    function testSingleBitCID() public {
        vm.startPrank(alice);

        uint128[] memory amounts = new uint128[](2);
        amounts[1] = uint128(INITIAL_LIQUIDITY_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(LiqFacet.SingleBitCID.selector, 0x2)
        );
        uint256 shares = liqFacet.addLiq(alice, 0x2, amounts);
    }

    function testInitialLiquidityProvision() public {
        uint256 amount0 = INITIAL_LIQUIDITY_AMOUNT;
        uint256 amount1 = INITIAL_LIQUIDITY_AMOUNT;

        vm.startPrank(alice);

        uint128[] memory amounts = new uint128[](2);
        amounts[0] = uint128(amount0);
        amounts[1] = uint128(amount1);
        uint256 shares = liqFacet.addLiq(alice, closureId, amounts);

        // Record balances before removal
        uint256 token0Before = token0.balanceOf(alice);
        uint256 token1Before = token1.balanceOf(alice);

        // Remove all liquidity for token0
        liqFacet.removeLiq(alice, closureId, shares);

        vm.stopPrank();

        // Verify tokens were returned
        assertEq(
            token0.balanceOf(alice),
            token0Before + amount0,
            "Should have received all token0 back"
        );
        assertEq(
            token1.balanceOf(alice),
            token1Before + amount1,
            "Should have received all token1 back"
        );
    }

    /// Single sided, multi-user provision
    function testMultipleProvidersLiquidity() public {
        uint256 amount = SMALL_DEPOSIT_AMOUNT;

        // Alice adds liquidity
        vm.startPrank(alice);
        uint128[] memory amounts0 = new uint128[](2);
        amounts0[0] = uint128(amount);
        amounts0[1] = 0;
        uint256 aliceShares0 = liqFacet.addLiq(alice, closureId, amounts0);
        vm.stopPrank();

        // Bob adds same amount of liquidity
        vm.startPrank(bob);
        uint128[] memory amounts1 = new uint128[](2);
        amounts1[0] = uint128(amount);
        amounts1[1] = 0;
        uint256 bobShares0 = liqFacet.addLiq(bob, closureId, amounts1);
        vm.stopPrank();

        vm.startPrank(alice);

        // Record balances before removal
        uint256 aliceToken0Before = token0.balanceOf(alice);

        // Remove all liquidity
        liqFacet.removeLiq(alice, closureId, aliceShares0);

        vm.stopPrank();

        vm.startPrank(bob);

        // Record balances before removal
        uint256 bobToken0Before = token0.balanceOf(bob);

        // Remove all liquidity
        liqFacet.removeLiq(bob, closureId, bobShares0);

        vm.stopPrank();

        // Verify tokens were returned (alice)
        assertApproxEqAbs(
            token0.balanceOf(alice),
            aliceToken0Before + amount,
            ((aliceToken0Before + amount) * 2) / 1000,
            "Alice should have received all token0 back (some rounding allowed to 0.2%)"
        );

        // Verify tokens were returned (bob)
        assertApproxEqAbs(
            token0.balanceOf(bob),
            bobToken0Before + amount,
            ((bobToken0Before + amount) * 2) / 1000,
            "Bob should have received all token0 back (some rounding allowed to 0.2%)"
        );
    }

    /// multi-sided, multi-user provision
    function testMultiSidedMultiUserProvision() public {
        uint256 amount = SMALL_DEPOSIT_AMOUNT;

        // Alice adds liquidity
        vm.startPrank(alice);
        uint128[] memory amounts0 = new uint128[](2);
        amounts0[0] = uint128(amount);
        amounts0[1] = 0;
        uint256 aliceShares0 = liqFacet.addLiq(alice, closureId, amounts0);

        uint128[] memory amounts1 = new uint128[](2);
        amounts1[0] = 0;
        amounts1[1] = uint128(amount);
        uint256 aliceShares1 = liqFacet.addLiq(alice, closureId, amounts1);
        vm.stopPrank();

        // Bob adds same amount of liquidity
        vm.startPrank(bob);
        uint128[] memory amounts2 = new uint128[](2);
        amounts2[0] = uint128(amount);
        amounts2[1] = 0;
        uint256 bobShares0 = liqFacet.addLiq(bob, closureId, amounts2);

        uint128[] memory amounts3 = new uint128[](2);
        amounts3[0] = 0;
        amounts3[1] = uint128(amount);
        uint256 bobShares1 = liqFacet.addLiq(bob, closureId, amounts3);
        vm.stopPrank();

        vm.startPrank(alice);

        // Record balances before removal
        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);

        // Remove all liquidity
        liqFacet.removeLiq(alice, closureId, aliceShares0 + aliceShares1);

        vm.stopPrank();

        vm.startPrank(bob);

        // Record balances before removal
        uint256 bobToken0Before = token0.balanceOf(bob);
        uint256 bobToken1Before = token1.balanceOf(bob);

        // Remove all liquidity
        liqFacet.removeLiq(bob, closureId, bobShares0 + bobShares1);

        vm.stopPrank();

        // Verify tokens were returned (alice)
        assertApproxEqAbs(
            token0.balanceOf(alice),
            aliceToken0Before + amount,
            1e23,
            "Alice should have received all token0 back"
        );
        assertApproxEqAbs(
            token1.balanceOf(alice),
            aliceToken1Before + amount,
            1e23,
            "Alice should have received all token1 back"
        );

        // Verify tokens were returned (bob)
        assertApproxEqAbs(
            token0.balanceOf(bob),
            bobToken0Before + amount,
            (bobToken0Before + amount * 2) / 1000,
            "Bob should have received all token0 back"
        );
        assertApproxEqAbs(
            token1.balanceOf(bob),
            bobToken1Before + amount,
            (bobToken1Before + amount * 2) / 1000,
            "Bob should have received all token1 back"
        );
    }

    function testLiquidityRemoval() public {
        vm.startPrank(alice);

        // Add liquidity with token0 only
        uint128[] memory amounts = new uint128[](2);
        amounts[0] = uint128(INITIAL_MINT_AMOUNT / 10);
        amounts[1] = 0;
        uint256 shares = liqFacet.addLiq(alice, closureId, amounts);

        // Add liquidity with token1 only
        amounts[0] = 0;
        amounts[1] = uint128(INITIAL_MINT_AMOUNT / 10);
        uint256 shares2 = liqFacet.addLiq(alice, closureId, amounts);

        // Remove all liquidity
        liqFacet.removeLiq(alice, closureId, shares);
        liqFacet.removeLiq(alice, closureId, shares2);

        vm.stopPrank();

        // Verify tokens were returned with a small tolerance for rounding
        assertApproxEqAbs(
            token1.balanceOf(alice),
            INITIAL_MINT_AMOUNT,
            (INITIAL_MINT_AMOUNT * 2) / 1000,
            "Should have received all token1 back (some rounding allowed to 0.2%)"
        );
        assertApproxEqAbs(
            token0.balanceOf(alice),
            INITIAL_MINT_AMOUNT,
            (INITIAL_MINT_AMOUNT * 2) / 1000,
            "Should have received all token0 back (some rounding allowed to 0.2%)"
        );
    }

    function testPartialLiquidityRemoval() public {
        uint256 amount = INITIAL_LIQUIDITY_AMOUNT;
        uint256 removalPercentage = 50; // 50%

        // Provide liquidity
        vm.startPrank(alice);
        uint128[] memory amounts0 = new uint128[](2);
        amounts0[0] = uint128(amount);
        amounts0[1] = 0;
        uint256 shares0 = liqFacet.addLiq(alice, closureId, amounts0);

        uint128[] memory amounts1 = new uint128[](2);
        amounts1[0] = 0;
        amounts1[1] = uint128(amount);
        uint256 shares1 = liqFacet.addLiq(alice, closureId, amounts1);

        // Calculate partial shares to remove
        uint256 sharesToRemove0 = (shares0 * removalPercentage) / 100;
        uint256 sharesToRemove1 = (shares1 * removalPercentage) / 100;

        // Record balances before removal
        uint256 token0Before = token0.balanceOf(alice);
        uint256 token1Before = token1.balanceOf(alice);

        // Remove partial liquidity
        liqFacet.removeLiq(alice, closureId, sharesToRemove0);
        liqFacet.removeLiq(alice, closureId, sharesToRemove1);

        vm.stopPrank();

        // Verify tokens were returned proportionally
        assertApproxEqRel(
            token0.balanceOf(alice) - token0Before,
            amount / 2,
            1e16,
            "Should have received half of token0 back"
        );
        assertApproxEqRel(
            token1.balanceOf(alice) - token1Before,
            amount / 2,
            1e16,
            "Should have received half of token1 back"
        );
    }

    function testMultiAmountLiquidityProvision() public {
        uint256 amount0 = SMALL_DEPOSIT_AMOUNT;
        uint256 amount1 = SMALL_DEPOSIT_AMOUNT * 2; // Different amount for token1

        vm.startPrank(alice);

        // Create amounts array for multi-amount addLiq
        uint128[] memory amounts = new uint128[](2);
        amounts[0] = uint128(amount0);
        amounts[1] = uint128(amount1);

        // Add liquidity using multi-amount function
        uint256 shares = liqFacet.addLiq(alice, closureId, amounts);

        // Record balances before removal
        uint256 token0Before = token0.balanceOf(alice);
        uint256 token1Before = token1.balanceOf(alice);

        // Remove all liquidity
        liqFacet.removeLiq(alice, closureId, shares);

        vm.stopPrank();

        // Verify tokens were returned
        assertApproxEqAbs(
            (token0.balanceOf(alice) - token0Before) +
                (token1.balanceOf(alice) - token1Before),
            amount0 + amount1,
            ((amount0 + amount1) * 2) / 1000,
            "Should have received a similar amount of tokens back"
        );
    }

    function testFuzz_MultiAmountLiquidityProvision(
        uint128 amount0,
        uint128 amount1
    ) public {
        // Bound the inputs to reasonable ranges
        amount0 = uint128(
            bound(uint256(amount0), 1e6, SMALL_DEPOSIT_AMOUNT / 2)
        );
        amount1 = uint128(
            bound(uint256(amount1), 1e6, SMALL_DEPOSIT_AMOUNT / 2)
        );

        vm.startPrank(alice);

        // Create amounts array for multi-amount addLiq
        uint128[] memory amounts = new uint128[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        // Add liquidity using multi-amount function
        uint256 shares = liqFacet.addLiq(alice, closureId, amounts);

        // Record balances before removal
        uint256 token0Before = token0.balanceOf(alice);
        uint256 token1Before = token1.balanceOf(alice);

        // Remove all liquidity
        liqFacet.removeLiq(alice, closureId, shares);

        vm.stopPrank();

        // Verify tokens were returned
        assertApproxEqAbs(
            (token0.balanceOf(alice) - token0Before) +
                (token1.balanceOf(alice) - token1Before),
            amount0 + amount1,
            ((amount0 + amount1) * 2) / 1000,
            "Should have received all token back"
        );
    }

    function testFuzz_PartialLiquidityRemoval(
        uint128 depositAmount,
        uint8 removalPercentage
    ) public {
        // Bound the inputs to reasonable ranges
        depositAmount = uint128(
            bound(uint256(depositAmount), 1e6, SMALL_DEPOSIT_AMOUNT)
        );
        removalPercentage = uint8(bound(uint256(removalPercentage), 1, 99)); // 1-99%

        vm.startPrank(alice);

        // Provide initial liquidity
        uint128[] memory amounts0 = new uint128[](2);
        amounts0[0] = uint128(depositAmount);
        amounts0[1] = 0;
        uint256 shares0 = liqFacet.addLiq(alice, closureId, amounts0);

        uint128[] memory amounts1 = new uint128[](2);
        amounts1[0] = 0;
        amounts1[1] = uint128(depositAmount);
        uint256 shares1 = liqFacet.addLiq(alice, closureId, amounts1);

        // Calculate partial shares to remove
        uint256 sharesToRemove0 = (shares0 * removalPercentage) / 100;
        uint256 sharesToRemove1 = (shares1 * removalPercentage) / 100;

        // Record balances before removal
        uint256 token0Before = token0.balanceOf(alice);
        uint256 token1Before = token1.balanceOf(alice);

        // Remove partial liquidity
        liqFacet.removeLiq(alice, closureId, sharesToRemove0);
        liqFacet.removeLiq(alice, closureId, sharesToRemove1);

        // Calculate expected returns
        uint256 expectedReturn0 = (uint256(depositAmount) * removalPercentage) /
            100;
        uint256 expectedReturn1 = (uint256(depositAmount) * removalPercentage) /
            100;

        // Verify returned amounts
        assertApproxEqAbs(
            (token0.balanceOf(alice) - token0Before) +
                (token1.balanceOf(alice) - token1Before),
            expectedReturn0 + expectedReturn1,
            ((expectedReturn0 + expectedReturn1) * 2) / 1000,
            "Incorrect token return amount"
        );

        vm.stopPrank();
    }

    function testFuzz_RepeatedAddRemoveLiquidity(
        uint128[5] memory addAmounts,
        uint8[5] memory removePercentages
    ) public {
        vm.startPrank(alice);
        uint256 remainingShares0;
        uint256 remainingShares1;

        for (uint i = 0; i < 5; i++) {
            // Bound inputs
            addAmounts[i] = uint128(
                bound(uint256(addAmounts[i]), 1e6, SMALL_DEPOSIT_AMOUNT / 10)
            );
            removePercentages[i] = uint8(
                bound(uint256(removePercentages[i]), 1, 90)
            ); // 1-90%

            // Add liquidity
            uint128[] memory amounts0 = new uint128[](2);
            amounts0[0] = uint128(addAmounts[i]);
            amounts0[1] = 0;
            uint256 newShares0 = liqFacet.addLiq(alice, closureId, amounts0);

            uint128[] memory amounts1 = new uint128[](2);
            amounts1[0] = 0;
            amounts1[1] = uint128(addAmounts[i]);
            uint256 newShares1 = liqFacet.addLiq(alice, closureId, amounts1);

            remainingShares0 += newShares0;
            remainingShares1 += newShares1;

            // Remove some percentage of total shares
            uint256 sharesToRemove0 = (remainingShares0 *
                removePercentages[i]) / 100;
            uint256 sharesToRemove1 = (remainingShares1 *
                removePercentages[i]) / 100;

            if (sharesToRemove0 > 0 && sharesToRemove1 > 0) {
                liqFacet.removeLiq(alice, closureId, sharesToRemove0);
                liqFacet.removeLiq(alice, closureId, sharesToRemove1);

                remainingShares0 -= sharesToRemove0;
                remainingShares1 -= sharesToRemove1;
            }
        }

        vm.stopPrank();
    }

    function testShareCalculationInvariant() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = INITIAL_LIQUIDITY_AMOUNT;
        amounts[1] = INITIAL_LIQUIDITY_AMOUNT * 2;
        amounts[2] = INITIAL_LIQUIDITY_AMOUNT / 2;

        uint256[] memory shares = new uint256[](3);

        vm.startPrank(alice);

        // Add liquidity in multiple rounds
        for (uint i = 0; i < amounts.length; i++) {
            uint128[] memory deposits = new uint128[](2);
            deposits[0] = uint128(amounts[i]);
            deposits[1] = uint128(amounts[i]);
            shares[i] = liqFacet.addLiq(alice, closureId, deposits);
        }

        for (uint i = 0; i < shares.length; i++) {
            uint256 token0Before = token0.balanceOf(alice);
            uint256 token1Before = token1.balanceOf(alice);

            liqFacet.removeLiq(alice, closureId, shares[i]);

            uint256 token0Received = token0.balanceOf(alice) - token0Before;
            uint256 token1Received = token1.balanceOf(alice) - token1Before;

            // Verify received amounts are proportional to shares
            assertApproxEqRel(
                token0Received,
                amounts[i],
                1e16,
                "Token0 received should be proportional to shares"
            );
            assertApproxEqRel(
                token1Received,
                amounts[i],
                1e16,
                "Token1 received should be proportional to shares"
            );
        }

        vm.stopPrank();
    }

    function testTotalSupplyInvariant() public {
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = makeAddr("charlie");

        uint256 totalSupply0;
        uint256 totalSupply1;

        // Fund users and approve diamond
        for (uint i = 1; i < users.length; i++) {
            token0.mint(users[i], INITIAL_MINT_AMOUNT);
            token1.mint(users[i], INITIAL_MINT_AMOUNT);

            vm.startPrank(users[i]);
            token0.approve(address(diamond), type(uint256).max);
            token1.approve(address(diamond), type(uint256).max);
            vm.stopPrank();
        }

        // Each user adds different amounts of liquidity
        for (uint i = 0; i < users.length; i++) {
            uint256 amount = INITIAL_LIQUIDITY_AMOUNT * (i + 1);

            vm.startPrank(users[i]);
            uint128[] memory amounts0 = new uint128[](2);
            amounts0[0] = uint128(amount);
            amounts0[1] = 0;
            uint256 shares0 = liqFacet.addLiq(users[i], closureId, amounts0);

            uint128[] memory amounts1 = new uint128[](2);
            amounts1[0] = 0;
            amounts1[1] = uint128(amount);
            uint256 shares1 = liqFacet.addLiq(users[i], closureId, amounts1);
            vm.stopPrank();

            totalSupply0 += shares0;
            totalSupply1 += shares1;
        }

        // Remove random amounts of liquidity and verify total supply changes
        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);

            // Remove half of user's liquidity
            uint128[] memory amounts0 = new uint128[](2);
            amounts0[0] = uint128(INITIAL_LIQUIDITY_AMOUNT * (i + 1));
            amounts0[1] = 0;
            uint256 shares0 = liqFacet.addLiq(users[i], closureId, amounts0) /
                2;

            uint128[] memory amounts1 = new uint128[](2);
            amounts1[0] = 0;
            amounts1[1] = uint128(INITIAL_LIQUIDITY_AMOUNT * (i + 1));
            uint256 shares1 = liqFacet.addLiq(users[i], closureId, amounts1) /
                2;

            liqFacet.removeLiq(users[i], closureId, shares0);
            liqFacet.removeLiq(users[i], closureId, shares1);

            totalSupply0 -= shares0;
            totalSupply1 -= shares1;

            vm.stopPrank();
        }
    }

    function testShareRatioInvariant() public {
        // Test that share ratios remain proportional to deposit ratios
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = INITIAL_LIQUIDITY_AMOUNT;
        amounts[1] = INITIAL_LIQUIDITY_AMOUNT * 2;
        amounts[2] = INITIAL_LIQUIDITY_AMOUNT / 2;

        uint256[] memory shares0 = new uint256[](3);
        uint256[] memory shares1 = new uint256[](3);

        vm.startPrank(alice);

        // Add liquidity in multiple rounds
        for (uint i = 0; i < amounts.length; i++) {
            uint128[] memory amounts0 = new uint128[](2);
            amounts0[0] = uint128(amounts[i]);
            amounts0[1] = 0;
            shares0[i] = liqFacet.addLiq(alice, closureId, amounts0);

            uint128[] memory amounts1 = new uint128[](2);
            amounts1[0] = 0;
            amounts1[1] = uint128(amounts[i]);
            shares1[i] = liqFacet.addLiq(alice, closureId, amounts1);

            // Verify share proportion matches deposit proportion
            if (i > 0) {
                uint256 shareRatio = (shares0[i] * 1e18) / shares0[0];
                uint256 amountRatio = (amounts[i] * 1e18) / amounts[0];
                assertApproxEqRel(
                    shareRatio,
                    amountRatio,
                    1e16, // 1% tolerance
                    "Share ratio should match deposit ratio"
                );
            }
        }

        vm.stopPrank();
    }

    function testValuePreservationInvariant() public {
        uint256 initialAmount = INITIAL_LIQUIDITY_AMOUNT;

        vm.startPrank(alice);

        uint256 aliceToken0Before = token0.balanceOf(alice);
        uint256 aliceToken1Before = token1.balanceOf(alice);

        // Add liquidity
        uint128[] memory deposits = new uint128[](2);
        deposits[0] = uint128(initialAmount);
        deposits[1] = uint128(initialAmount);
        uint256 shares = liqFacet.addLiq(alice, closureId, deposits);

        vm.stopPrank();

        // Perform some swaps to change the price
        vm.startPrank(bob);
        swapFacet.swap(
            bob,
            address(token0),
            address(token1),
            int256(initialAmount / 10),
            MIN_SQRT_PRICE_X96 + 1
        );
        swapFacet.swap(
            bob,
            address(token1),
            address(token0),
            int256(initialAmount / 5),
            MAX_SQRT_PRICE_X96 - 1
        );
        vm.stopPrank();

        // Remove all liquidity
        vm.startPrank(alice);
        liqFacet.removeLiq(alice, closureId, shares);
        vm.stopPrank();

        // Calculate final value
        uint256 aliceToken0After = token0.balanceOf(alice);
        uint256 aliceToken1After = token1.balanceOf(alice);

        // Initial value should be INITIAL_LIQUIDITY_AMOUNT * 2 since we added liquidity twice
        uint256 expectedValue = INITIAL_LIQUIDITY_AMOUNT * 2;

        // Check that final value is approximately equal to initial value (within 0.1% tolerance)
        assertApproxEqAbs(
            aliceToken0After + aliceToken1After,
            aliceToken0Before + aliceToken1Before,
            expectedValue / 1000
        );
        assertGt(aliceToken1After, aliceToken0After);
    }
}
