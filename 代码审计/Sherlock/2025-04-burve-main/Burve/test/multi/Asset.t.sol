// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {Asset, AssetBook, AssetBookImpl} from "../../src/multi/Asset.sol";
import {ClosureId} from "../../src/multi/closure/Id.sol";
import {Closure} from "../../src/multi/closure/Closure.sol";
import {MAX_TOKENS} from "../../src/multi/Constants.sol";
import {Store} from "../../src/multi/Store.sol";

contract AssetTest is Test {
    AssetBook private assetBook;
    ClosureId public cid;
    address recipient;

    function setUp() public {
        recipient = makeAddr("recipient");

        cid = ClosureId.wrap(1);

        // Enough to bypass store init check
        Closure storage c = Store.load().closures[cid];
        c.cid = cid;
    }

    // -- add tests ----

    function testAdd() public {
        assetBook.add(recipient, cid, 10e18, 5e18);

        Asset storage a = assetBook.assets[recipient][cid];
        assertEq(a.value, 10e18);
        assertEq(a.bgtValue, 5e18);
    }

    function testAddCollects() public {
        // verify collect is called by checking a checkpoint is updated
        Closure storage c = Store.load().closures[cid];
        c.bgtPerBgtValueX128 = 2 << 128;

        assetBook.add(recipient, cid, 20, 10);

        Asset storage a = assetBook.assets[recipient][cid];
        assertEq(a.bgtPerValueX128Check, 2 << 128);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertAddInsufficientValue() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetBookImpl.InsufficientValue.selector,
                1,
                2
            )
        );
        assetBook.add(recipient, cid, 1, 2);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertAddUninitializedClosure() public {
        vm.expectRevert(
            abi.encodeWithSelector(Store.UninitializedClosure.selector, 2)
        );
        assetBook.add(recipient, ClosureId.wrap(2), 0, 0);
    }

    // -- query tests ----

    function testQuery() public {
        assetBook.add(recipient, cid, 10e18, 2e18);
        (
            uint256 value,
            uint256 bgtValue,
            uint256[MAX_TOKENS] memory feeBalances,
            uint256 bgtBalance
        ) = assetBook.query(recipient, cid);
        assertEq(value, 10e18);
        assertEq(bgtValue, 2e18);
        assertEq(feeBalances[0], 0);
        assertEq(bgtBalance, 0);
    }

    function testQueryBalancesViaEarning() public {
        assetBook.add(recipient, cid, 10, 0);

        uint256[MAX_TOKENS] memory epvX128;
        epvX128[0] = 2 << 128;

        Closure storage c = Store.load().closures[cid];
        c.earningsPerValueX128 = epvX128;

        (, , uint256[MAX_TOKENS] memory feeBalances, ) = assetBook.query(
            recipient,
            cid
        );
        assertEq(feeBalances[0], 20);
    }

    function testQueryBalancesViaUnexchangedBgt() public {
        assetBook.add(recipient, cid, 20, 10);

        uint256[MAX_TOKENS] memory unepbvX128;
        unepbvX128[0] = 2 << 128;

        Closure storage c = Store.load().closures[cid];
        c.unexchangedPerBgtValueX128 = unepbvX128;

        (, , uint256[MAX_TOKENS] memory feeBalances, ) = assetBook.query(
            recipient,
            cid
        );
        assertEq(feeBalances[0], 20);
    }

    function testQueryBgt() public {
        assetBook.add(recipient, cid, 20, 10);

        Closure storage c = Store.load().closures[cid];
        c.bgtPerBgtValueX128 = 2 << 128;

        (, , , uint256 bgtBalance) = assetBook.query(recipient, cid);
        assertEq(bgtBalance, 20);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertQueryUninitializedClosure() public {
        vm.expectRevert(
            abi.encodeWithSelector(Store.UninitializedClosure.selector, 2)
        );
        assetBook.query(recipient, ClosureId.wrap(2));
    }

    // -- remove tests ----

    function testRemove() public {
        assetBook.add(recipient, cid, 12e18, 7e18);
        assetBook.remove(recipient, cid, 5e18, 2e18);

        Asset storage a = assetBook.assets[recipient][cid];
        assertEq(a.value, 7e18);
        assertEq(a.bgtValue, 5e18);
    }

    function testRemoveCollects() public {
        assetBook.add(recipient, cid, 12e18, 7e18);

        // verify collect is called by checking a checkpoint is updated
        Closure storage c = Store.load().closures[cid];
        c.bgtPerBgtValueX128 = 2 << 128;

        assetBook.remove(recipient, cid, 1e18, 1e18);

        Asset storage a = assetBook.assets[recipient][cid];
        assertEq(a.bgtPerValueX128Check, 2 << 128);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertRemoveMoreBgtThanValue() public {
        assetBook.add(recipient, cid, 12e18, 7e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetBookImpl.InsufficientValue.selector,
                0,
                1
            )
        );
        assetBook.remove(recipient, cid, 0, 1);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertRemoveMoreValueThanOwed() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetBookImpl.InsufficientValue.selector,
                0,
                1
            )
        );
        assetBook.remove(recipient, cid, 1, 0);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertRemoveMoreBgtThanOwed() public {
        assetBook.add(recipient, cid, 12e18, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetBookImpl.InsufficientBgtValue.selector,
                0,
                1
            )
        );
        assetBook.remove(recipient, cid, 2e18, 1);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertRemoveInsufficientNonBgtValue() public {
        assetBook.add(recipient, cid, 12e18, 11e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetBookImpl.InsufficientNonBgtValue.selector,
                10e18,
                11e18
            )
        );
        assetBook.remove(recipient, cid, 2e18, 0);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertRemoveUninitializedClosure() public {
        vm.expectRevert(
            abi.encodeWithSelector(Store.UninitializedClosure.selector, 2)
        );
        assetBook.remove(recipient, ClosureId.wrap(2), 0, 0);
    }

    // -- collect tests ----

    function testCollectBalancesViaEarning() public {
        assetBook.add(recipient, cid, 10, 0);

        uint256[MAX_TOKENS] memory epvX128;
        epvX128[0] = 2 << 128;

        Closure storage c = Store.load().closures[cid];
        c.earningsPerValueX128 = epvX128;

        assetBook.collect(recipient, cid);

        Asset storage a = assetBook.assets[recipient][cid];
        assertEq(a.collectedBalances[0], 20);
        assertEq(a.earningsPerValueX128Check[0], 2 << 128);
    }

    function testCollectBalancesViaUnexchangedBgt() public {
        assetBook.add(recipient, cid, 20, 10);

        uint256[MAX_TOKENS] memory unepbvX128;
        unepbvX128[0] = 2 << 128;

        Closure storage c = Store.load().closures[cid];
        c.unexchangedPerBgtValueX128 = unepbvX128;

        assetBook.collect(recipient, cid);

        Asset storage a = assetBook.assets[recipient][cid];
        assertEq(a.collectedBalances[0], 20);
        assertEq(a.unexchangedPerBgtValueX128Check[0], 2 << 128);
    }

    function testCollectBgt() public {
        assetBook.add(recipient, cid, 20, 10);

        Closure storage c = Store.load().closures[cid];
        c.bgtPerBgtValueX128 = 2 << 128;

        assetBook.collect(recipient, cid);

        Asset storage a = assetBook.assets[recipient][cid];
        assertEq(a.bgtBalance, 20);
        assertEq(a.bgtPerValueX128Check, 2 << 128);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertCollectUninitializedClosure() public {
        vm.expectRevert(
            abi.encodeWithSelector(Store.UninitializedClosure.selector, 2)
        );
        assetBook.collect(recipient, ClosureId.wrap(2));
    }

    // -- claimFees tests ----

    function testClaimFees() public {
        Asset storage a = assetBook.assets[recipient][cid];
        a.collectedBalances[0] = 10e18;
        a.collectedBalances[1] = 20e18;
        a.bgtBalance = 30e18;

        // check fee result
        (uint256[MAX_TOKENS] memory feeBalances, uint256 bgtBalance) = assetBook
            .claimFees(recipient, cid);
        assertEq(feeBalances[0], 10e18);
        assertEq(feeBalances[1], 20e18);
        assertEq(bgtBalance, 30e18);

        // check asset state cleared
        assertEq(a.collectedBalances[0], 0);
        assertEq(a.collectedBalances[1], 0);
        assertEq(a.bgtBalance, 0);
    }

    function testClaimFeesCollects() public {
        // verify collect is called by checking a checkpoint is updated
        Closure storage c = Store.load().closures[cid];
        c.bgtPerBgtValueX128 = 2 << 128;

        assetBook.claimFees(recipient, cid);

        Asset storage a = assetBook.assets[recipient][cid];
        assertEq(a.bgtPerValueX128Check, 2 << 128);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testRevertClaimFeesUninitializedClosure() public {
        vm.expectRevert(
            abi.encodeWithSelector(Store.UninitializedClosure.selector, 2)
        );
        assetBook.claimFees(recipient, ClosureId.wrap(2));
    }
}
