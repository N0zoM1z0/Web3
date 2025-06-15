// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {ITokenMapping} from "src/interfaces/tokenManager/ITokenMapping.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {DEFAULT_ADMIN_ROLE, MAX_COLLATERAL_TOKEN_COUNT} from "src/constants.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";

import {
    NullAddress, InvalidToken, SameValue, Invalid, TooManyCollateralTokens
} from "src/errors.sol";

/// @title   TokenMapping contract
/// @notice  TokenMapping contract to manage Eth0 collateral tokens and Eth0 tokens.
/// @dev     This contract provides functionalities to link Eth0 collateral tokens with ETH0 tokens and manage token pairs.
/// @dev     It's part of the Usual Tech team's broader ecosystem to facilitate various operations within the platform.
/// @author  Usual Tech team
contract TokenMapping is Initializable, ITokenMapping {
    using CheckAccessControl for IRegistryAccess;

    struct TokenMappingStorageV0 {
        /// @notice Immutable instance of the REGISTRY_ACCESS contract for role checks.
        IRegistryAccess _registryAccess;
        /// @notice Immutable instance of the REGISTRY_CONTRACT for contract interaction.
        IRegistryContract _registryContract;
        /// @dev track last associated Eth0 collateral token ID associated to ETH0.
        uint256 _eth0ToCollateralTokenLastId;
        /// @dev assign a Eth0 collateral token address to ETH0 token address.
        mapping(address => bool) isEth0Collateral;
        /// @dev  Eth0 collateral token ID associated with ETH0 token address.
        // solhint-disable-next-line var-name-mixedcase
        mapping(uint256 => address) ETH0CollateralTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("tokenmapping.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant TokenMappingStorageV0Location =
        0xb0e2a10694f571e49337681df93856b25ecda603d0f0049769ee36b541ef2300;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _tokenMappingStorageV0() private pure returns (TokenMappingStorageV0 storage $) {
        bytes32 position = TokenMappingStorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the TokenMapping contract with registry information.
    /// @dev Sets the registry access and contract addresses upon deployment.
    /// @param registryAccess The address of the registry access contract.
    /// @param registryContract The address of the registry contract.
    function initialize(address registryAccess, address registryContract) public initializer {
        if (registryAccess == address(0) || registryContract == address(0)) {
            revert NullAddress();
        }

        TokenMappingStorageV0 storage $ = _tokenMappingStorageV0();
        $._registryAccess = IRegistryAccess(registryAccess);
        $._registryContract = IRegistryContract(registryContract);
    }

    /// @inheritdoc ITokenMapping
    function addEth0CollateralToken(address collateral) external returns (bool) {
        if (collateral == address(0)) {
            revert NullAddress();
        }
        // check if there is a decimals function at the address
        // and if there is at least 1 decimal
        // if not, revert
        if (IERC20Metadata(collateral).decimals() == 0) {
            revert Invalid();
        }

        TokenMappingStorageV0 storage $ = _tokenMappingStorageV0();
        $._registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);

        // is the collateral token already registered as a ETH0 collateral
        if ($.isEth0Collateral[collateral]) revert SameValue();
        $.isEth0Collateral[collateral] = true;
        // 0 index is always empty
        ++$._eth0ToCollateralTokenLastId;
        if ($._eth0ToCollateralTokenLastId > MAX_COLLATERAL_TOKEN_COUNT) {
            revert TooManyCollateralTokens();
        }
        $.ETH0CollateralTokens[$._eth0ToCollateralTokenLastId] = collateral;
        emit AddEth0CollateralToken(collateral, $._eth0ToCollateralTokenLastId);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                 View
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITokenMapping
    function getEth0CollateralTokenById(uint256 collateralId) external view returns (address) {
        TokenMappingStorageV0 storage $ = _tokenMappingStorageV0();
        address collateralToken = $.ETH0CollateralTokens[collateralId];
        if (collateralToken == address(0)) {
            revert InvalidToken();
        }
        return collateralToken;
    }

    /// @inheritdoc ITokenMapping
    function getAllEth0CollateralTokens() external view returns (address[] memory) {
        TokenMappingStorageV0 storage $ = _tokenMappingStorageV0();
        address[] memory collateralTokens = new address[]($._eth0ToCollateralTokenLastId);
        // maximum of 10 collateral tokens
        uint256 length = $._eth0ToCollateralTokenLastId;
        for (uint256 i = 1; i <= length;) {
            collateralTokens[i - 1] = $.ETH0CollateralTokens[i];
            unchecked {
                ++i;
            }
        }
        return collateralTokens;
    }

    /// @inheritdoc ITokenMapping
    function getLastEth0CollateralTokenId() external view returns (uint256) {
        TokenMappingStorageV0 storage $ = _tokenMappingStorageV0();
        return $._eth0ToCollateralTokenLastId;
    }

    /// @inheritdoc ITokenMapping
    function isEth0Collateral(address collateral) external view returns (bool) {
        TokenMappingStorageV0 storage $ = _tokenMappingStorageV0();
        return $.isEth0Collateral[collateral];
    }
}
