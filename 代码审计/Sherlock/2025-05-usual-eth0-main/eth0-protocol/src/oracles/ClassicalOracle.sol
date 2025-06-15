// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {AbstractOracle} from "src/oracles/AbstractOracle.sol";
import {IAggregator} from "src/interfaces/oracles/IAggregator.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";
import {DEFAULT_ADMIN_ROLE, ONE_WEEK} from "src/constants.sol";
import {
    NullAddress,
    OracleNotWorkingNotCurrent,
    OracleNotInitialized,
    InvalidTimeout
} from "src/errors.sol";

/// @author  Usual Tech Team
/// @title   Classical Oracle System
/// @dev     This oracle aggregates existing oracles for various tokens.
/// @dev     It makes the price of these tokens available through a common interface.
contract ClassicalOracle is AbstractOracle {
    using CheckAccessControl for IRegistryAccess;

    /*//////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Constructor for initializing the contract.
    /// @dev    This constructor is used to set the initial state of the contract.
    /// @param  registryContract The registry contract address.
    function initialize(address registryContract) public initializer {
        __AbstractOracle_init_unchained(registryContract);
    }

    /// @notice Initialize a new supported token.
    /// @dev    When adding a new token, we assume that the provided oracle is working.
    /// @param  token          The address of the new token.
    /// @param  dataSource The address of the Chainlink aggregator, i.e. underlying oracle.
    /// @param  timeout        The timeout in seconds.
    function initializeTokenOracle(
        address token,
        address dataSource,
        uint64 timeout,
        bool isStablecoin
    ) external {
        if (token == address(0)) revert NullAddress();
        if (dataSource == address(0)) revert NullAddress(); // 价格预言机存在
        // The timeout can't be zero and must be at most one week
        if (timeout == 0 || timeout > ONE_WEEK) revert InvalidTimeout(); // 有效的新鲜的时间戳

        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = IAggregator(dataSource).latestRoundData();
        if (answer <= 0 || updatedAt == 0 || block.timestamp > updatedAt + timeout) { // 最新
            revert OracleNotWorkingNotCurrent(); // 首次健康检查
        }

        AbstractOracle.AbstractOracleStorageV0 storage $ = _abstractOracleStorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);

        $.tokenToOracleInfo[token].dataSource = dataSource;
        $.tokenToOracleInfo[token].isStablecoin = isStablecoin;
        $.tokenToOracleInfo[token].timeout = timeout;
    }

    /// @inheritdoc AbstractOracle
    function _latestRoundData(address token) internal view override returns (uint256, uint256) {
        // 缺失了对回合完整性 / 回合是否按顺序回答 的检验
        AbstractOracleStorageV0 storage $ = _abstractOracleStorageV0();
        IAggregator priceAggregatorProxy = IAggregator($.tokenToOracleInfo[token].dataSource);

        if (address(priceAggregatorProxy) == address(0)) revert OracleNotInitialized();

        uint256 decimals = priceAggregatorProxy.decimals();

        // slither-disable-next-line unused-return
        (, int256 answer,, uint256 updatedAt,) = priceAggregatorProxy.latestRoundData();
        if (answer <= 0) revert OracleNotWorkingNotCurrent(); // 确保返回的价格 >0
        if (updatedAt > block.timestamp) revert OracleNotWorkingNotCurrent();
        // track the updatedAt value from  latestRoundData()
        // to make sure that the latest answer is recent enough for your application to use it
        // detects that the reported answer is not updated within the heartbeat timeout
        if (block.timestamp > $.tokenToOracleInfo[token].timeout + updatedAt) {
            revert OracleNotWorkingNotCurrent();
        }
        return (uint256(answer), decimals);
    }
}
