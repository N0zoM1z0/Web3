// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./LEther.sol";

/**
 * @title Lend's Maximillion Contract
 * @author Compound
 */
contract Maximillion {
    /**
     * @notice The default lEther market to repay in
     */
    LEther public lEther;

    /**
     * @notice Construct a Maximillion to repay max in a LEther market
     */
    constructor(LEther lEther_) {
        lEther = lEther_;
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in the lEther market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     */
    function repayBehalf(address borrower) public payable {
        repayBehalfExplicit(borrower, lEther);
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in a lEther market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     * @param lEther_ The address of the lEther contract to repay in
     */
    function repayBehalfExplicit(address borrower, LEther lEther_) public payable {
        uint256 received = msg.value;
        uint256 borrows = lEther_.borrowBalanceCurrent(borrower);
        if (received > borrows) {
            lEther_.repayBorrowBehalf{value: borrows}(borrower);
            payable(msg.sender).transfer(received - borrows);
        } else {
            lEther_.repayBorrowBehalf{value: received}(borrower);
        }
    }
}
