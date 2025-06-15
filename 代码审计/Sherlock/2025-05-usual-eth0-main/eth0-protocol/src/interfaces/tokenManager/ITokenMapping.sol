// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

interface ITokenMapping {
    /*//////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an collateral token is linked to ETH0 token.
    /// @param collateral The address of the collateral token.
    /// @param collateralId The ID of the collateral token.
    event AddEth0CollateralToken(address indexed collateral, uint256 indexed collateralId);

    /*//////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Links an collateral token to ETH0 token.
    /// @dev Only the admin can link the collateral token to ETH0 token.
    /// @dev Ensures the collateral token is valid and not already linked to ETH0 token.
    /// @param collateral The address of the collateral token.
    /// @return A boolean value indicating success.
    function addEth0CollateralToken(address collateral) external returns (bool);

    /// @notice Retrieves the collateral token linked to ETH0 token.
    /// @dev Returns the address of the collateral token associated with ETH0 token.
    /// @param collateralId The ID of the collateral token.
    /// @return The address of the associated collateral token.
    function getEth0CollateralTokenById(uint256 collateralId) external view returns (address);

    /// @notice Retrieves all collateral tokens linked to ETH0 token.
    /// @dev Returns an array of addresses of all collateral tokens associated with ETH0 token.
    /// @dev the maximum number of collateral tokens that can be associated with ETH0 token is 10.
    /// @return An array of addresses of associated collateral tokens.
    function getAllEth0CollateralTokens() external view returns (address[] memory);

    /// @notice Retrieves the last collateral ID for ETH0 token.
    /// @dev Returns the highest index used for the collateral tokens associated with the ETH0 token.
    /// @return The last collateral ID used in the STBC to collateral mapping.
    function getLastEth0CollateralTokenId() external view returns (uint256);

    /// @notice Checks if the collateral token is linked to ETH0 token.
    /// @dev Returns a boolean value indicating if the collateral token is linked to ETH0 token.
    /// @param collateral The address of the collateral token.
    /// @return A boolean value indicating if the collateral token is linked to ETH0 token.
    function isEth0Collateral(address collateral) external view returns (bool);
}
