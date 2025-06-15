// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

interface IDaoCollateral {
    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when tokens are swapped.
    /// @param owner The address of the owner
    /// @param tokenSwapped The address of the token swapped
    /// @param amount The amount of tokens swapped
    /// @param amountInEth The amount in ETH
    event Swap(
        address indexed owner, address indexed tokenSwapped, uint256 amount, uint256 amountInEth
    );

    /// @notice Emitted when tokens are redeemed.
    /// @param redeemer The address of the redeemer
    /// @param collateralToken The address of the collateralToken
    /// @param amountRedeemed The amount of tokens redeemed
    /// @param returnedCollateralAmount The amount of collateralToken returned
    /// @param stableFeeAmount The amount of stableToken fee
    event Redeem(
        address indexed redeemer,
        address indexed collateralToken,
        uint256 amountRedeemed,
        uint256 returnedCollateralAmount,
        uint256 stableFeeAmount
    );

    /// @notice Emitted when redeem functionality is paused.
    event RedeemPaused();

    /// @notice Emitted when redeem functionality is unpaused.
    event RedeemUnPaused();

    /// @notice Emitted when swap functionality is paused.
    event SwapPaused();

    /// @notice Emitted when swap functionality is unpaused.
    event SwapUnPaused();

    /// @notice Emitted when the Counter Bank Run (CBR) mechanism is activated.
    /// @param cbrCoef The Counter Bank Run (CBR) coefficient.
    event CBRActivated(uint256 cbrCoef);

    /// @notice Emitted when the Counter Bank Run (CBR) mechanism is deactivated.
    event CBRDeactivated();

    /// @notice Emitted when the redeem fee is updated.
    /// @param redeemFee The new redeem fee.
    event RedeemFeeUpdated(uint256 redeemFee);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Activates the Counter Bank Run (CBR) mechanism.
    /// @param coefficient the CBR coefficient to activate
    function activateCBR(uint256 coefficient) external;

    /// @notice Deactivates the Counter Bank Run (CBR) mechanism.
    function deactivateCBR() external;

    /// @notice Sets the redeem fee.
    /// @param redeemFee The new redeem fee to set.
    function setRedeemFee(uint256 redeemFee) external;

    /// @notice Pauses the redeem functionality.
    function pauseRedeem() external;

    /// @notice Unpauses the redeem functionality.
    function unpauseRedeem() external;

    /// @notice Pauses the swap functionality.
    function pauseSwap() external;

    /// @notice Unpauses the swap functionality.
    function unpauseSwap() external;

    /// @notice Pauses the contract.
    function pause() external;

    /// @notice Unpauses the contract.
    function unpause() external;

    /// @notice  swap method
    /// @dev     Function that enable you to swap your collateralToken for stablecoin
    /// @dev     Will exchange LST (collateralToken) for ETH0 (stableToken)
    /// @param   collateralToken  address of the token to swap
    /// @param   amount  amount of collateralToken to swap
    /// @param   minAmountOut minimum amount of stableToken to receive
    function swap(address collateralToken, uint256 amount, uint256 minAmountOut) external;

    /// @notice  swap method with permit
    /// @dev     Function that enable you to swap your collateralToken for stablecoin with permit
    /// @dev     Will exchange LST (collateralToken) for ETH0 (stableToken)
    /// @param   collateralToken  address of the token to swap
    /// @param   amount  amount of collateralToken to swap
    /// @param   deadline The deadline for the permit
    /// @param   v The v value for the permit
    /// @param   r The r value for the permit
    /// @param   s The s value for the permit
    function swapWithPermit(
        address collateralToken,
        uint256 amount,
        uint256 minAmountOut,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice  redeem method
    /// @dev     Function that enable you to redeem your stable token for collateralToken
    /// @dev     Will exchange ETH0 (stableToken) for LST (collateralToken)
    /// @param   collateralToken address of the token that will be sent to the you
    /// @param   amount  amount of stableToken to redeem
    /// @param   minAmountOut minimum amount of collateralToken to receive
    function redeem(address collateralToken, uint256 amount, uint256 minAmountOut) external;

    // * Getter functions

    /// @notice get the redeem fee percentage
    /// @return the fee value
    function redeemFee() external view returns (uint256);

    /// @notice check if the CBR (Counter Bank Run) is activated
    /// @dev flag indicate the status of the CBR (see documentation for more details)
    /// @return the status of the CBR
    function isCBROn() external view returns (bool);

    /// @notice Returns the cbrCoef value.
    function cbrCoef() external view returns (uint256);

    /// @notice get the status of pause for the redeem function
    /// @return the status of the pause
    function isRedeemPaused() external view returns (bool);

    /// @notice get the status of pause for the swap function
    /// @return the status of the pause
    function isSwapPaused() external view returns (bool);

    /// @notice  redeem method for DAO
    /// @dev     Function that enables DAO to redeem stableToken for collateralToken
    /// @dev     Will exchange ETH0 (stableToken) for LST (collateralToken)
    /// @param   collateralToken address of the token that will be sent to the you
    /// @param   amount  amount of stableToken to redeem
    function redeemDao(address collateralToken, uint256 amount) external;
}
