// SPDX-License-Identifier: BUSL-1.1
// Copyright 2024 Itos Inc.
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";

import { Shares, SharesImpl } from "../../src/Util/Shares.sol";

contract SharesTest is Test {
    using SharesImpl for Shares;

    // addAmount tests

    function testAddAmountAtZeroTotalShares() public pure {
        Shares memory shares;
        uint256 sharesAdded = shares.addAmount(100);
        assertEq(sharesAdded, 100);
        assertEq(shares.totalShares, 100);
        assertEq(shares.totalAmount, 100);
    }

    function testAddAmountRewardingLessThanTotalShares() public pure {
        Shares memory shares;
        shares.addAmount(100);
        uint256 sharesAdded = shares.addAmount(20);
        assertEq(sharesAdded, 20);
        assertEq(shares.totalShares, 120);
        assertEq(shares.totalAmount, 120);
    }

    function testAddAmountRewardingGreaterThanTotalShares() public pure {
        Shares memory shares;
        shares.addAmount(100);
        uint256 sharesAdded = shares.addAmount(200);
        assertEq(sharesAdded, 200);
        assertEq(shares.totalShares, 300);
        assertEq(shares.totalAmount, 300);
    }

    // removeAmount tests

    function testRevertRemoveAmountOfZero() public {
        Shares memory shares;
        vm.expectRevert();
        shares.removeAmount(0);
    }

    function testRemoveAmountPartial() public pure {
        Shares memory shares;
        shares.addAmount(100);
        uint256 sharesRemoved = shares.removeAmount(20);
        assertEq(sharesRemoved, 20);
        assertEq(shares.totalShares, 80);
        assertEq(shares.totalAmount, 80);
    }

    function testRemoveAmountTotal() public pure {
        Shares memory shares;
        shares.addAmount(100);
        uint256 sharesRemoved = shares.removeAmount(100);
        assertEq(sharesRemoved, 100);
        assertEq(shares.totalShares, 0);
        assertEq(shares.totalAmount, 0);
    }

    // removeShares tests

    function testRevertRemoveSharesOfZero() public {
        Shares memory shares;
        vm.expectRevert();
        shares.removeShares(0);
    }

    function testRemoveSharesPartial() public pure {
        Shares memory shares;
        shares.addAmount(100);
        uint256 amountRemoved = shares.removeShares(20);
        assertEq(amountRemoved, 20);
        assertEq(shares.totalShares, 80);
        assertEq(shares.totalAmount, 80);
    }

    function testRemoveSharesTotal() public pure {
        Shares memory shares;
        shares.addAmount(100);
        uint256 amountRemoved = shares.removeShares(100);
        assertEq(amountRemoved, 100);
        assertEq(shares.totalShares, 0);
        assertEq(shares.totalAmount, 0);
    }
}
