// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, stdError} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Vertex, VertexId, VertexImpl, newVertexId} from "../../src/multi/Vertex.sol";
import {TokenRegistry, TokenRegLib, TokenRegistryImpl} from "../../src/multi/Token.sol";
import {VaultType} from "../../src/multi/VaultProxy.sol";
import {ClosureId, ClosureDist, ClosureDistImpl, newClosureDist, newClosureId} from "../../src/multi/Closure.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {Store} from "../../src/multi/Store.sol";
import {console2} from "forge-std/console2.sol";

contract VertexTest is Test {
    using VertexImpl for Vertex;
    using ClosureDistImpl for ClosureDist;
    using TokenRegistryImpl for TokenRegistry;

    // Test state variables
    Vertex internal vertex;
    MockERC20 internal token0;
    MockERC20 internal token1;
    MockERC20 internal token2;
    MockERC4626 internal vault0;
    MockERC4626 internal vault1;
    MockERC4626 internal vault2;
    ClosureId[] internal testClosures;

    // Test constants
    uint256 constant INITIAL_BALANCE = 1000000 ether;
    uint256 constant TEST_AMOUNT = 100 ether;

    function setUp() public {
        // Deploy mock ERC20 token first
        token0 = new MockERC20("Test Token 0", "TES0", 18);
        token1 = new MockERC20("Test Token 1", "TES1", 18);
        token2 = new MockERC20("Test Token 2", "TES2", 18);

        // Deploy a second mock ERC20

        // Deploy mock ERC4626 vault with the token as underlying
        vault0 = new MockERC4626(token0, "Mock Vault 0", "MVLT0");
        vault1 = new MockERC4626(token1, "Mock Vault 1", "MVLT1");
        vault2 = new MockERC4626(token2, "Mock Vault 2", "MVLT2");

        // Register token in the registry
        TokenRegistry storage tokenReg = Store.tokenRegistry();
        tokenReg.register(address(token0));
        tokenReg.register(address(token1));
        tokenReg.register(address(token2));

        // Mint some initial tokens
        token0.mint(address(this), INITIAL_BALANCE);
        token1.mint(address(this), INITIAL_BALANCE);
        token2.mint(address(this), INITIAL_BALANCE);

        // Approve vault to spend tokens
        token0.approve(address(vault0), type(uint256).max);
        token1.approve(address(vault1), type(uint256).max);
        token2.approve(address(vault1), type(uint256).max);

        // Initialize vertex
        vertex.init(address(token0), address(vault0), VaultType.E4626);
        Store.vertex(newVertexId(address(token1))).init(
            address(token1),
            address(vault1),
            VaultType.E4626
        );
        Store.vertex(newVertexId(address(token2))).init(
            address(token2),
            address(vault2),
            VaultType.E4626
        );
    }

    function testInitialization() public {
        // Test basic initialization
        VertexId vid = vertex.vid;
        assertTrue(vid.isEq(VertexId.wrap(uint16(1))), "Vertex ID should be 1");
    }

    function testEnsureClosure() public {
        // Create a closure that includes our vertex and another
        VertexId otherVid = VertexId.wrap(uint16(2)); // Second vertex
        ClosureId closure = ClosureId.wrap(uint16(3)); // Closure with both vertices

        // Add closure
        vertex.ensureClosure(closure);

        // Verify closure was added correctly
        assertTrue(
            vertex.homSet[otherVid][closure],
            "Closure should be in homSet"
        );
        assertTrue(
            vertex.homs[otherVid][0].isEq(closure),
            "Closure should be in homs array"
        );
    }

    function testHomAddAndSubtract() public {
        // Setup closures
        VertexId otherVid = VertexId.wrap(uint16(2));
        VertexId vid2 = VertexId.wrap(uint16(4));
        ClosureId closure1 = ClosureId.wrap(uint16(3)); // token0, token1
        ClosureId closure2 = ClosureId.wrap(uint16(5)); // token0, token2

        // Add closures to vertex
        vertex.ensureClosure(closure1);
        vertex.ensureClosure(closure2);

        // Create closure distribution
        delete testClosures;
        testClosures.push(closure1);
        testClosures.push(closure2);
        ClosureDist memory dist = newClosureDist(testClosures);

        // Add weights to distribution (60/40 split)
        dist.add(0, 60);
        dist.add(1, 40);
        dist.normalize();

        // Add liquidity
        vertex.homAdd(dist, TEST_AMOUNT);

        // Check balances
        uint256 totalBalance = vertex.balance(otherVid, false);
        assertApproxEqRel(
            totalBalance,
            (TEST_AMOUNT * 60) / 100, // 60%,
            1,
            "Total balance should match added amount (60%)"
        );

        totalBalance = vertex.balance(vid2, false);
        assertApproxEqRel(
            totalBalance,
            (TEST_AMOUNT * 40) / 100, // 40%
            1,
            "Total balance should match added amount (40%)"
        );

        // Withdraw half the amount
        uint256 withdrawAmount = TEST_AMOUNT / 2;
        ClosureDist memory withdrawDist = vertex.homSubtract(
            otherVid,
            withdrawAmount
        );

        // Check remaining balance
        totalBalance = vertex.balance(otherVid, false);
        assertApproxEqRel(
            totalBalance,
            (TEST_AMOUNT * 60) / 100 - withdrawAmount,
            1,
            "Remaining balance incorrect"
        );
        totalBalance = vertex.balance(vid2, false);
        assertApproxEqRel(
            totalBalance,
            (TEST_AMOUNT * 40) / 100, // 40%
            1,
            "Total balance should match added amount (40%)"
        );
    }

    function testHomAddDistributions() public {
        VertexId otherVid = VertexId.wrap(uint16(2));
        VertexId otherVid2 = VertexId.wrap(uint16(4));
        ClosureId closure1 = ClosureId.wrap(uint16(3));
        ClosureId closure2 = ClosureId.wrap(uint16(5));

        // Add closures
        vertex.ensureClosure(closure1);
        vertex.ensureClosure(closure2);

        // Create distribution with uneven split (33/67)
        {
            delete testClosures;
            testClosures.push(closure1);
            testClosures.push(closure2);
            ClosureDist memory dist = newClosureDist(testClosures);
            dist.add(0, 33);
            dist.add(1, 67);
            dist.normalize();
            // Add small amount to test rounding
            uint256 smallAmount = 100; // Small number to force rounding
            vertex.homAdd(dist, smallAmount);
        }

        // Check balance with both rounding options
        uint256 balanceRoundDown = vertex.balance(otherVid, false);
        uint256 balanceRoundUp = vertex.balance(otherVid2, true);

        assertTrue(
            balanceRoundUp >= balanceRoundDown,
            "Round up should be >= round down"
        );
    }
}
