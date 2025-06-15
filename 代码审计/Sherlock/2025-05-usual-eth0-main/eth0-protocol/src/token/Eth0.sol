// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IEth0} from "src/interfaces/token/IEth0.sol";
import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {ITokenMapping} from "src/interfaces/tokenManager/ITokenMapping.sol";
import {IOracle} from "src/interfaces/oracles/IOracle.sol";
import {
    CONTRACT_TOKEN_MAPPING,
    ETH0_MINT,
    ETH0_BURN,
    CONTRACT_TREASURY,
    CONTRACT_ORACLE,
    PAUSING_CONTRACTS_ROLE,
    BLACKLIST_ROLE,
    MINT_CAP_OPERATOR,
    UNPAUSING_CONTRACTS_ROLE,
    CONTRACT_REGISTRY_ACCESS
} from "src/constants.sol";
import {
    AmountIsZero,
    NullAddress,
    Blacklisted,
    SameValue,
    AmountExceedBacking,
    AmountExceedCap,
    NullContract,
    MintCapTooSmall
} from "src/errors.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {ERC20PausableUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title   Eth0 contract
/// @notice  Manages the ETH0 token, including minting, burning, and transfers with blacklist checks.
/// @dev     Implements IEth0 for ETH0-specific logic.
/// @author  Usual Tech team
contract Eth0 is ERC20PausableUpgradeable, ERC20PermitUpgradeable, IEth0 {
    using CheckAccessControl for IRegistryAccess;
    using SafeERC20 for ERC20;

    /// @custom:storage-location erc7201:Eth0.storage.v0
    struct Eth0StorageV0 {
        IRegistryAccess registryAccess;
        mapping(address => bool) isBlacklisted;
        IRegistryContract registryContract;
        ITokenMapping tokenMapping;
        uint256 mintCap;
    }

    // keccak256(abi.encode(uint256(keccak256("Eth0.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant Eth0StorageV0Location =
        0x1da13d17ef7469260d8a4ed769e6da31a754319d6a3df48193393a84b7d8bf00;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _eth0StorageV0() internal pure returns (Eth0StorageV0 storage $) {
        bytes32 position = Eth0StorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                             INITIALIZER
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the contract with the given parameters
    /// @param registryContract The address of the registry contract.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol of the token.
    function initialize(address registryContract, string memory name_, string memory symbol_)
        public
        initializer
    {
        // Initialize the contract with the registry contract.
        if (registryContract == address(0)) {
            revert NullContract();
        }
        Eth0StorageV0 storage $ = _eth0StorageV0();
        // Initialize the contract with token details.
        __ERC20_init(name_, symbol_);
        // Initialize the contract in an unpaused state.
        __ERC20Pausable_init();
        // Initialize the contract with permit functionality.
        __ERC20Permit_init(name_);

        $.registryContract = IRegistryContract(registryContract);
        $.registryAccess = IRegistryAccess($.registryContract.getContract(CONTRACT_REGISTRY_ACCESS));
        $.tokenMapping =
            ITokenMapping(IRegistryContract($.registryContract).getContract(CONTRACT_TOKEN_MAPPING));
    }

    /*//////////////////////////////////////////////////////////////
                               External
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IEth0
    function pause() external {
        Eth0StorageV0 storage $ = _eth0StorageV0();
        $.registryAccess.onlyMatchingRole(PAUSING_CONTRACTS_ROLE);
        _pause();
    }

    /// @inheritdoc IEth0
    function unpause() external {
        Eth0StorageV0 storage $ = _eth0StorageV0();
        $.registryAccess.onlyMatchingRole(UNPAUSING_CONTRACTS_ROLE);
        _unpause();
    }

    /// @inheritdoc IEth0
    function mint(address to, uint256 amount) public {
        if (amount == 0) {
            revert AmountIsZero();
        }

        Eth0StorageV0 storage $ = _eth0StorageV0();
        $.registryAccess.onlyMatchingRole(ETH0_MINT);
        IOracle oracle = IOracle($.registryContract.getContract(CONTRACT_ORACLE));
        address treasury = $.registryContract.getContract(CONTRACT_TREASURY);

        // Check if minting would exceed the mint cap
        if (totalSupply() + amount > $.mintCap) {
            revert AmountExceedCap();
        }

        address[] memory collateralTokens = $.tokenMapping.getAllEth0CollateralTokens();

        uint256 wadCollateralBackingInETH = 0;
        for (uint256 i = 0; i < collateralTokens.length;) {
            address collateralToken = collateralTokens[i];
            uint256 collateralTokenPriceInETH = uint256(oracle.getPrice(collateralToken));
            uint8 decimals = IERC20Metadata(collateralToken).decimals();

            wadCollateralBackingInETH += Math.mulDiv(
                collateralTokenPriceInETH,
                IERC20(collateralToken).balanceOf(treasury),
                10 ** decimals
            );

            unchecked {
                ++i;
            }
        }
        if (totalSupply() + amount > wadCollateralBackingInETH) {
            revert AmountExceedBacking();
        } // 核心不变性检查。确保铸造新的 amount ETH0 后，ETH0 的总供应量不超过金库中所有抵押品以ETH计价的总价值。
        _mint(to, amount);
    }

    /// @inheritdoc IEth0
    function burnFrom(address account, uint256 amount) public {
        if (amount == 0) {
            revert AmountIsZero();
        }
        Eth0StorageV0 storage $ = _eth0StorageV0();
        $.registryAccess.onlyMatchingRole(ETH0_BURN);
        _burn(account, amount); // _burn中的_update会检查accout合法性
    }

    /// @inheritdoc IEth0
    function setMintCap(uint256 newMintCap) external {
        Eth0StorageV0 storage $ = _eth0StorageV0();
        $.registryAccess.onlyMatchingRole(MINT_CAP_OPERATOR);
        if (newMintCap == 0) {
            revert AmountIsZero();
        }
        if (newMintCap == $.mintCap) {
            revert SameValue();
        }
        if (newMintCap < totalSupply()) {
            revert MintCapTooSmall();
        }
        $.mintCap = newMintCap;
        emit MintCapUpdated(newMintCap);
    }

    /// @inheritdoc IEth0
    function getMintCap() external view returns (uint256) {
        Eth0StorageV0 storage $ = _eth0StorageV0();
        return $.mintCap;
    }

    /// @inheritdoc IEth0
    function burn(uint256 amount) public {
        if (amount == 0) {
            revert AmountIsZero();
        }
        Eth0StorageV0 storage $ = _eth0StorageV0();
        $.registryAccess.onlyMatchingRole(ETH0_BURN);
        _burn(msg.sender, amount);
    }

    /// @notice Hook that ensures token transfers are not made from or to not blacklisted addresses.
    /// @param from The address sending the tokens.
    /// @param to The address receiving the tokens.
    /// @param amount The amount of tokens being transferred.
    function _update(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20PausableUpgradeable, ERC20Upgradeable)
    {
        Eth0StorageV0 storage $ = _eth0StorageV0();
        if ($.isBlacklisted[from] || $.isBlacklisted[to]) {
            revert Blacklisted();
        }
        super._update(from, to, amount);
    }

    /// @inheritdoc IEth0
    function blacklist(address account) external {
        if (account == address(0)) {
            revert NullAddress();
        }
        Eth0StorageV0 storage $ = _eth0StorageV0();
        $.registryAccess.onlyMatchingRole(BLACKLIST_ROLE);
        if ($.isBlacklisted[account]) {
            revert SameValue();
        }
        $.isBlacklisted[account] = true;

        emit Blacklist(account);
    }

    /// @inheritdoc IEth0
    function unBlacklist(address account) external {
        // 没有检查 account == address(0); 但没什么影响
        Eth0StorageV0 storage $ = _eth0StorageV0();
        $.registryAccess.onlyMatchingRole(BLACKLIST_ROLE);
        if (!$.isBlacklisted[account]) {
            revert SameValue();
        }
        $.isBlacklisted[account] = false;

        emit UnBlacklist(account);
    }

    /// @inheritdoc IEth0
    function isBlacklisted(address account) external view returns (bool) {
        Eth0StorageV0 storage $ = _eth0StorageV0();
        return $.isBlacklisted[account];
    }
}
