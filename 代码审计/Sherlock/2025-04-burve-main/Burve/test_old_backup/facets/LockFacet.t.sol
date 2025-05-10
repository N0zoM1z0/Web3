// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console2} from "forge-std/console2.sol";
import {LiqFacet} from "../../src/multi/facets/LiqFacet.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {LockFacet} from "../../src/multi/facets/LockFacet.sol";
import {MultiSetupTest} from "./MultiSetup.u.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract LockFacetTest is MultiSetupTest {
    function setUp() public {
        vm.startPrank(owner);
        _newDiamond();
        _newTokens(3);
        _fundAccount(alice);
        vm.stopPrank();
    }

    /// Make sure only those authorized can lock.
    function testLockers() public {
        vm.expectRevert();
        vm.prank(alice);
        lockFacet.lock(address(token0));

        vm.prank(owner);
        lockFacet.lock(address(token0));

        vm.prank(owner);
        lockFacet.addLocker(alice);

        // Now it should work.
        vm.prank(alice);
        lockFacet.lock(address(token0));

        vm.prank(owner);
        lockFacet.removeLocker(alice);

        // And again it doesn't.
        vm.expectRevert();
        vm.prank(alice);
        lockFacet.lock(address(token0));

        // But the owner still can
        vm.prank(owner);
        lockFacet.lock(address(token0));
    }

    /// Make sure only those authorized can lock.
    function testUnlockers() public {
        vm.expectRevert();
        vm.prank(alice);
        lockFacet.unlock(address(token0));

        vm.prank(owner);
        lockFacet.unlock(address(token0));

        vm.prank(owner);
        lockFacet.addUnlocker(alice);

        // Now it should work.
        vm.prank(alice);
        lockFacet.unlock(address(token0));

        vm.prank(owner);
        lockFacet.removeUnlocker(alice);

        // And again it doesn't.
        vm.expectRevert();
        vm.prank(alice);
        lockFacet.unlock(address(token0));

        // But the owner still can
        vm.prank(owner);
        lockFacet.unlock(address(token0));
    }

    /// Test attempts to interact with liquidity when a vertex is locked.
    function testLockedLiq() public {
        uint128[] memory amounts = new uint128[](3);
        uint16 cid2 = 0x0003;
        uint16 cid3 = 0x0007;

        // Alice can originally add liquidity.
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        amounts[2] = 1e18;

        IERC20 lockedToken = IERC20(tokens[2]);
        uint256 originalBalance = lockedToken.balanceOf(alice);
        vm.prank(alice);
        uint256 shares = liqFacet.addLiq(alice, cid3, amounts);
        assertLt(lockedToken.balanceOf(alice), originalBalance);

        vm.prank(owner);
        lockFacet.lock(tokens[2]);
        // But once token2 is locked she can't add more.
        vm.expectRevert(
            abi.encodeWithSelector(
                LiqFacet.VertexLockedInCID.selector,
                uint16(0x4)
            )
        );
        vm.startPrank(alice);
        liqFacet.addLiq(alice, cid3, amounts);

        // She can still add to cid 2 though since it doesn't include the third token.
        liqFacet.addLiq(alice, cid2, amounts);

        // She can remove her previous liquidity though.
        liqFacet.removeLiq(alice, cid3, shares);
        vm.stopPrank();
        // And get back the locked token even if its locked.
        assertApproxEqAbs(lockedToken.balanceOf(alice), originalBalance, 1);

        // And once we unlock...
        vm.prank(owner);
        lockFacet.unlock(tokens[2]);

        // Alice can add again.
        vm.prank(alice);
        liqFacet.addLiq(alice, cid3, amounts);
    }

    /// Test attempts to swap when a vertex is locked.
    function testLockedSwap() public {
        // First add a bunch of liquidity.
        _fundAccount(owner);
        uint128[] memory amounts = new uint128[](3);
        amounts[0] = 100e18;
        amounts[1] = 100e18;
        vm.prank(owner);
        liqFacet.addLiq(owner, 0x3, amounts);

        // Before locking, alice can swap freely
        vm.prank(alice);
        swapFacet.swap(alice, tokens[0], tokens[1], 1e18, 1 << 95);

        // But locked...
        vm.prank(owner);
        lockFacet.lock(tokens[1]);

        // She can't swap in either direction.
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SwapFacet.SwapTokenLocked.selector,
                tokens[1]
            )
        );
        swapFacet.swap(alice, tokens[0], tokens[1], 1e18, 1 << 95);
        vm.expectRevert(
            abi.encodeWithSelector(
                SwapFacet.SwapTokenLocked.selector,
                tokens[1]
            )
        );
        swapFacet.swap(alice, tokens[1], tokens[0], 1e18, 1 << 97);
        vm.stopPrank();

        // And after unlocking she can.
        vm.prank(owner);
        lockFacet.unlock(tokens[1]);

        vm.startPrank(alice);
        swapFacet.swap(alice, tokens[1], tokens[0], 1e18, 1 << 97);
        swapFacet.swap(alice, tokens[0], tokens[1], 1e18, 1 << 95);
        vm.stopPrank();

        // Test again with token0
        vm.prank(owner);
        lockFacet.lock(tokens[0]);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SwapFacet.SwapTokenLocked.selector,
                tokens[0]
            )
        );
        swapFacet.swap(alice, tokens[1], tokens[0], 1e18, 1 << 97);
    }
}
