// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

abstract contract LendtrollerInterface {
    /// @notice Indicator that this is a Lendtroller contract (for inspection)
    bool public constant isLendtroller = true;

    /**
     * Assets You Are In **
     */
    function enterMarkets(address[] calldata lTokens) external virtual returns (uint256[] memory);
    function exitMarket(address lToken) external virtual returns (uint256);

    /**
     * Policy Hooks **
     */
    function mintAllowed(address lToken, address minter, uint256 mintAmount) external virtual returns (uint256);
    function mintVerify(address lToken, address minter, uint256 mintAmount, uint256 mintTokens) external virtual;

    function redeemAllowed(address lToken, address redeemer, uint256 redeemTokens) external virtual returns (uint256);
    function redeemVerify(address lToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens)
        external
        virtual;

    function borrowAllowed(address lToken, address borrower, uint256 borrowAmount) external virtual returns (uint256);
    function borrowVerify(address lToken, address borrower, uint256 borrowAmount) external virtual;

    function repayBorrowAllowed(address lToken, address payer, address borrower, uint256 repayAmount)
        external
        virtual
        returns (uint256);
    function repayBorrowVerify(
        address lToken,
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 borrowerIndex
    ) external virtual;

    function liquidateBorrowAllowed(
        address lTokenBorrowed,
        address lTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external virtual returns (uint256);
    function liquidateBorrowVerify(
        address lTokenBorrowed,
        address lTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount,
        uint256 seizeTokens
    ) external virtual;

    function seizeAllowed(
        address lTokenCollateral,
        address lTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external virtual returns (uint256);
    function seizeVerify(
        address lTokenCollateral,
        address lTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external virtual;

    function transferAllowed(address lToken, address src, address dst, uint256 transferTokens)
        external
        virtual
        returns (uint256);
    function transferVerify(address lToken, address src, address dst, uint256 transferTokens) external virtual;

    /**
     * Liquidity/Liquidation Calculations **
     */
    function liquidateCalculateSeizeTokens(address lTokenBorrowed, address lTokenCollateral, uint256 repayAmount)
        external
        view
        virtual
        returns (uint256, uint256);
}
