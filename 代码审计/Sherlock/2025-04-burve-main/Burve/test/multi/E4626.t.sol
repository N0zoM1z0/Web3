// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {Store} from "../../src/multi/Store.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {VaultTemp} from "../../src/multi/vertex/VaultPointer.sol";
import {VaultE4626, VaultE4626Impl} from "../../src/multi/vertex/E4626.sol";
import {ClosureId} from "../../src/multi/closure/Id.sol";

contract E4626Test is Test {
    IERC20 public token;
    IERC4626 public e4626;
    VaultE4626 public vault;
    ClosureId[] public cids;

    function setUp() public {
        token = IERC20(address(new MockERC20("test", "TEST", 18)));
        MockERC20(address(token)).mint(address(this), 1 << 128);
        e4626 = IERC4626(
            address(new MockERC4626(ERC20(address(token)), "vault", "V"))
        );
        token.approve(address(e4626), 1 << 128);
        vault.init(address(token), address(e4626));
    }

    // Test an empty fetch and commit
    function testEmpty() public {
        ClosureId cid = ClosureId.wrap(1);
        VaultTemp memory temp;
        vault.fetch(temp);
        assertEq(vault.balance(temp, cid, false), 0);
        // Empty commit.
        vault.commit(temp);
    }

    function testDeposit() public {
        ClosureId cid = ClosureId.wrap(1);
        VaultTemp memory temp;
        vault.fetch(temp);
        vault.deposit(temp, cid, 1e10);
        vault.commit(temp);
        assertEq(vault.balance(temp, cid, false), 1e10);
        assertEq(token.balanceOf(address(this)), (1 << 128) - 1e10);
        assertGt(vault.totalVaultShares, 0);
        uint256 shares = vault.shares[cid];
        assertGt(shares, 0);
        assertEq(vault.totalShares, shares);
    }

    // TODO: bring test back
    // We fail if we try to deposit and withdraw in the same operation.
    // function testOverlap() public {
    //     ClosureId cid = ClosureId.wrap(1);
    //     VaultTemp memory temp;
    //     vault.fetch(temp);
    //     vault.deposit(temp, cid, 1e10);
    //     // errors when trying to withdraw too much.
    //     vm.expectRevert();
    //     vault.withdraw(temp, cid, 1e15);
    //     // This works though.
    //     vault.withdraw(temp, cid, 1e5);
    //     // This faults with overlap.
    //     vm.expectRevert(
    //         VaultE4626Impl.OverlappingOperations.selector,
    //         address(e4626)
    //     );
    //     vault.commit(temp);
    // }

    function testWithdraw() public {
        ClosureId cid = ClosureId.wrap(1);
        {
            VaultTemp memory temp;
            vault.fetch(temp);
            vault.deposit(temp, cid, 1e10);
            vault.commit(temp);
            assertEq(vault.balance(temp, cid, false), 1e10);
        }
        assertEq(token.balanceOf(address(this)), (1 << 128) - 1e10);
        // Now withdraw
        {
            VaultTemp memory temp;
            vault.fetch(temp);
            vault.withdraw(temp, cid, 1e10);
            vault.commit(temp);
            assertEq(vault.balance(temp, cid, false), 0);
        }
        assertEq(token.balanceOf(address(this)), 1 << 128);
        assertEq(vault.shares[cid], 0);
        assertEq(vault.totalShares, 0);
        assertEq(vault.totalVaultShares, 0);
    }

    function testMultipleDeposits() public {
        ClosureId cid1 = ClosureId.wrap(1);
        ClosureId cid2 = ClosureId.wrap(2);
        cids.push(cid1);
        cids.push(cid2);
        {
            VaultTemp memory temp;
            vault.fetch(temp);
            vault.deposit(temp, cid1, 1e10);
            assertEq(vault.balance(temp, cid1, false), 1e10);
            assertEq(vault.balance(temp, cid2, false), 0);
            assertEq(vault.totalBalance(temp, cids, false), 1e10);
            vault.deposit(temp, cid2, 2e10);
            assertEq(vault.balance(temp, cid1, false), 1e10);
            assertEq(vault.balance(temp, cid2, false), 2e10);
            assertEq(vault.totalBalance(temp, cids, false), 3e10);
            vault.deposit(temp, cid1, 5e10);
            assertEq(vault.balance(temp, cid1, false), 6e10);
            assertEq(vault.balance(temp, cid2, false), 2e10);
            assertEq(vault.totalBalance(temp, cids, false), 8e10);
            vault.commit(temp);
        }
        // Check again after committed.
        {
            VaultTemp memory temp;
            vault.fetch(temp);
            assertEq(vault.balance(temp, cid1, false), 6e10);
            assertEq(vault.balance(temp, cid2, false), 2e10);
            assertEq(vault.totalBalance(temp, cids, false), 8e10);
            vault.commit(temp);
        }
        // Now let's withdraw from one of them.
        {
            VaultTemp memory temp;
            vault.fetch(temp);
            vault.withdraw(temp, cid1, 15e9);
            vault.withdraw(temp, cid1, 5e9);
            assertEq(vault.balance(temp, cid1, false), 4e10);
            assertEq(vault.balance(temp, cid2, false), 2e10);
            assertEq(vault.totalBalance(temp, cids, false), 6e10);
            vault.commit(temp);
        }
        // And let's deposit into the cids one more time.
        {
            VaultTemp memory temp;
            vault.fetch(temp);
            vault.deposit(temp, cid1, 3e10);
            vault.deposit(temp, cid2, 10e10);
            assertEq(vault.balance(temp, cid1, true), 7e10);
            assertEq(vault.balance(temp, cid2, true), 12e10);
            assertEq(vault.totalBalance(temp, cids, true), 19e10);
            vault.commit(temp);
        }
    }
}
