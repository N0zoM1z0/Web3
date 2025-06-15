// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import {LToken} from "../../LToken.sol";

abstract contract LendtrollerInterfaceV2 {
    function getCollateralFactorMantissa(address lToken)
        external
        view
        virtual
        returns (uint256 collateralFactorMantissa);

    function enterMarkets(address[] calldata cTokens) external virtual returns (uint256[] memory);
    function isDeprecated(LToken cToken) external view virtual returns (bool);
    function liquidateCalculateSeizeTokens(address lTokenBorrowed, address lTokenCollateral, uint256 repayAmount)
        external
        view
        virtual
        returns (uint256, uint256);
    function getLendAddress() external view virtual returns (address);
    function claimLend(address holder) external virtual;
    function lendSupplyState(address lToken) external view virtual returns (uint224 index, uint32 block);
    function lendBorrowState(address lToken) external view virtual returns (uint224 index, uint32 block);
    function closeFactorMantissa() external view virtual returns (uint256);
    function getAccountLiquidity(address account) external view virtual returns (uint256, uint256, uint256);
    function triggerSupplyIndexUpdate(address lToken) external virtual;
    function triggerBorrowIndexUpdate(address lToken) external virtual;
}
