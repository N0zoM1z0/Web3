// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console2} from "forge-std/console2.sol";
import {ValueFacet} from "../../src/multi/facets/ValueFacet.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {VaultFacet} from "../../src/multi/facets/VaultFacet.sol";
import {VaultType} from "../../src/multi/vertex/VaultPointer.sol";
import {VaultLib} from "../../src/multi/vertex/VaultProxy.sol";
import {VertexLib} from "../../src/multi/vertex/Id.sol";
import {MultiSetupTest} from "./MultiSetup.u.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract VaultFacetTest is MultiSetupTest {
    address[] public altVaults;
    VaultFacet public v;

    function setUp() public {
        _newDiamond();
        _newTokens(2);
        _fundAccount(address(this));
        _initializeClosure(0x3, 1e18);

        altVaults.push(
            address(new MockERC4626(ERC20(tokens[0]), "altvault 0", "AV0"))
        );
        altVaults.push(
            address(new MockERC4626(ERC20(tokens[1]), "altvault 1", "AV1"))
        );

        v = VaultFacet(diamond);
    }

    // Test the basic ability to add, approve, and remove.
    function testBasics() public {
        (address active, address backup) = v.viewVaults(tokens[0]);
        assertNotEq(active, address(0));
        assertEq(backup, address(0));
        v.addVault(tokens[0], altVaults[0], VaultType.E4626);
        // No vaults have changed yet.
        (address newActive, address newBackup) = v.viewVaults(tokens[0]);
        assertEq(active, newActive);
        assertEq(backup, newBackup);
        // Errors if we try to accept it before the time.
        skip(4 days);
        vm.expectRevert();
        v.acceptVault(tokens[0]);
        // But past 5 days is okay.
        skip(1 days + 1);
        v.acceptVault(tokens[0]);
        (newActive, newBackup) = v.viewVaults(tokens[0]);
        assertEq(active, newActive); // No transfer
        assertEq(newBackup, altVaults[0]); // Just a backup
        // We can remove immediately since no one is using it.
        v.removeVault(altVaults[0]);
        (newActive, newBackup) = v.viewVaults(tokens[0]);
        assertEq(active, newActive);
        assertEq(newBackup, address(0));
    }

    // Test the ability to veto
    function testVeto() public {
        v.addVault(tokens[0], altVaults[0], VaultType.E4626);
        // We can veto before the time has passed.
        v.vetoVault(tokens[0]);
        // Now trying to accept errors
        vm.expectRevert();
        v.acceptVault(tokens[0]);
        // We can re-add and accept after.
        v.addVault(tokens[0], altVaults[0], VaultType.E4626);
        skip(5 days + 1);
        v.acceptVault(tokens[0]);
    }

    // Test tranfering balances from one to another.
    function testTransfer() public {
        valueFacet.addValue(address(this), 0x3, 100e18, 0);

        // Similar to the basic test, but now we can't remove once we transfer tokens in.
        v.addVault(tokens[0], altVaults[0], VaultType.E4626);
        skip(5 days + 1);
        v.acceptVault(tokens[0]);

        // Do the transfer
        (address active, address backup) = v.viewVaults(tokens[0]);
        v.transferBalance(active, backup, 0x3, 1e18);
        assertEq(ERC20(tokens[0]).balanceOf(backup), 1e18);

        // We can't remove it anymore.
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultLib.RemainingVaultBalance.selector,
                1e18
            )
        );
        v.removeVault(backup);
        // We also can't remove the active vault.
        uint256 activeAmount = ERC20(tokens[0]).balanceOf(active);
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultLib.RemainingVaultBalance.selector,
                activeAmount
            )
        );
        v.removeVault(active);
        // Let's transfer everything.
        v.transferBalance(active, backup, 0x3, activeAmount - 2);
        // But even with the vault mostly empty, we can't move it yet because it is active.
        assertEq(ERC20(tokens[0]).balanceOf(active), 2); // We leave a de minimus amount
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultLib.VaultInUse.selector,
                active,
                VertexLib.newId(0)
            )
        );
        v.removeVault(active);

        // So let's move it to the backup.
        v.hotSwap(tokens[0]);
        (address a1, address b1) = v.viewVaults(tokens[0]);
        assertEq(a1, backup);
        assertEq(b1, active);
        // And we can finally remove it successfully.
        v.removeVault(active);

        // If we try to transfer into the removed vault it faults.
        vm.expectRevert(
            abi.encodeWithSelector(VaultLib.VaultNotFound.selector, active)
        );
        v.transferBalance(backup, active, 0x3, 1);

        // If we try to hot swap now it fails because there is no backup.
        vm.expectRevert(
            abi.encodeWithSelector(
                VaultLib.NoBackup.selector,
                VertexLib.newId(0)
            )
        );
        v.hotSwap(tokens[0]);
    }

    // Test the swap facet withdraws and removes from the appropriate vaults and prices are still calculated correctly.
    function testSwap() public {
        // Basic liq. 50e18 in each token.
        valueFacet.addValue(address(this), 0x3, 100e18, 0);

        // Check that the sim swap is the same if balances are all in 0, in a mix, and in 1.
        (, uint256 outAmount0, ) = swapFacet.simSwap(
            tokens[0],
            tokens[1],
            42e18,
            0x3
        ); // Sell
        (, uint256 outAmount1, ) = swapFacet.simSwap(
            tokens[1],
            tokens[0],
            42e18,
            0x3
        ); // buy
        // Adding a vault doesn't change anything.
        v.addVault(tokens[0], altVaults[0], VaultType.E4626);
        skip(5 days + 1);
        v.acceptVault(tokens[0]);
        (address active, address backup) = v.viewVaults(tokens[0]);
        (, uint256 o0, ) = swapFacet.simSwap(tokens[0], tokens[1], 42e18, 0x3);
        (, uint256 o1, ) = swapFacet.simSwap(tokens[1], tokens[0], 42e18, 0x3);
        assertEq(o0, outAmount0);
        assertEq(o1, outAmount1);
        // Even with a mix, the out amount doesn't change.
        v.transferBalance(active, backup, 0x3, 33e18);
        (, o0, ) = swapFacet.simSwap(tokens[0], tokens[1], 42e18, 0x3);
        (, o1, ) = swapFacet.simSwap(tokens[1], tokens[0], 42e18, 0x3);
        assertEq(o0, outAmount0);
        assertEq(o1, outAmount1);
        // Change a mix a bit more, more than the swap can handle with the active vault.
        vm.expectRevert(); // We only have 18e18 left
        v.transferBalance(active, backup, 0x3, 50e18);
        v.transferBalance(active, backup, 0x3, 16.365e18);
        (, o0, ) = swapFacet.simSwap(tokens[0], tokens[1], 42e18, 0x3);
        (, o1, ) = swapFacet.simSwap(tokens[1], tokens[0], 42e18, 0x3);
        assertEq(o0, outAmount0);
        assertEq(o1, outAmount1);
        // Now all of it in the backup vault.
        uint256 balance = ERC20(tokens[0]).balanceOf(active);
        v.transferBalance(active, backup, 0x3, balance);
        (, o0, ) = swapFacet.simSwap(tokens[0], tokens[1], 42e18, 0x3);
        (, o1, ) = swapFacet.simSwap(tokens[1], tokens[0], 42e18, 0x3);
        assertEq(o0, outAmount0);
        assertEq(o1, outAmount1);

        // Now check that a swap can still succeed if we need to withdraw from both vaults.
        // First only withdraw from the backup because there is nothing in active.
        (, uint256 outAmount) = swapFacet.swap(
            address(this),
            tokens[1],
            tokens[0],
            1e17,
            0,
            0x3
        );
        assertApproxEqRel(outAmount, 1e17, 1e15, "1"); // The peg stays strong with 0.1% slippage
        // Now transfer some back.
        v.transferBalance(backup, active, 0x3, 2e17);
        (, outAmount) = swapFacet.swap(
            address(this),
            tokens[1],
            tokens[0],
            3e17,
            0,
            0x3
        );
        assertApproxEqRel(outAmount, 3e17, 2e15, "2"); // Still pegged.

        // Any swap after a remove does not affect the removed vault.
        // We've entirely removed from the active vault because that gets removed first, so we can swap and remove.
        v.hotSwap(tokens[0]);
        v.removeVault(active);
        // Now we deposit token0 and it goes into the backup now the former active.
        swapFacet.swap(address(this), tokens[0], tokens[1], 5e18, 0, 0x3);
        assertEq(ERC20(tokens[0]).balanceOf(active), 0);
    }

    // Test the liq deposits and withdraws appropriately and the prices stay in line.
    function testLiq() public {
        // Add vault
        v.addVault(tokens[0], altVaults[0], VaultType.E4626);
        skip(5 days + 1);
        v.acceptVault(tokens[0]);
        (address active, address backup) = v.viewVaults(tokens[0]);
        // Both vaults are empty.

        // Check that a deposit will add to the active vault.
        valueFacet.addValue(address(this), 0x3, 2 * 100e18, 0);
        // Adding liq adds tokens to the active vault.
        assertEq(ERC20(tokens[0]).balanceOf(active), 101e18, "1");
        assertEq(ERC20(tokens[0]).balanceOf(backup), 0, "2");

        // Transfer tokens so we hold a mix in both vaults.
        v.transferBalance(active, backup, 0x3, 51e18);
        assertEq(ERC20(tokens[0]).balanceOf(active), 50e18, "3");
        assertEq(ERC20(tokens[0]).balanceOf(backup), 51e18, "4");

        // Removing liquidity removes successfully from both vaults.
        // Might leave some dust behind (in the backup vault only!)
        valueFacet.removeValue(address(this), 0x3, 2 * 100e18, 0);
        assertEq(ERC20(tokens[0]).balanceOf(active), 0, "5");
        assertApproxEqAbs(ERC20(tokens[0]).balanceOf(backup), 1e18, 2, "6");
    }
}
