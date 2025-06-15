// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./LToken.sol";
import "./PriceOracle.sol";

contract UnitrollerAdminStorage {
    /**
     * @notice Administrator for this contract
     */
    address public admin;

    /**
     * @notice Pending administrator for this contract
     */
    address public pendingAdmin;

    /**
     * @notice Active brains of Unitroller
     */
    address public lendtrollerImplementation;

    /**
     * @notice Pending brains of Unitroller
     */
    address public pendingLendtrollerImplementation;
}

contract LendtrollerV1Storage is UnitrollerAdminStorage {
    /**
     * @notice Oracle which gives the price of any given asset
     */
    PriceOracle public oracle;

    /**
     * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
     */
    uint256 public closeFactorMantissa;

    /**
     * @notice Multiplier representing the discount on collateral that a liquidator receives
     */
    uint256 public liquidationIncentiveMantissa;

    /**
     * @notice Max number of assets a single account can participate in (borrow or use as collateral)
     */
    uint256 public maxAssets;

    /**
     * @notice Per-account mapping of "assets you are in", capped by maxAssets
     */
    mapping(address => LToken[]) public accountAssets;
}

contract LendtrollerV2Storage is LendtrollerV1Storage {
    struct Market {
        // Whether or not this market is listed
        bool isListed;
        //  Multiplier representing the most one can borrow against their collateral in this market.
        //  For instance, 0.9 to allow borrowing 90% of collateral value.
        //  Must be between 0 and 1, and stored as a mantissa.
        uint256 collateralFactorMantissa;
        // Per-market mapping of "accounts in this asset"
        mapping(address => bool) accountMembership;
        // Whether or not this market receives LEND
        bool isLended;
    }

    /**
     * @notice Official mapping of lTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => Market) public markets;

    /**
     * @notice The Pause Guardian can pause certain actions as a safety mechanism.
     *  Actions which allow users to remove their own assets cannot be paused.
     *  Liquidation / seizing / transfer can only be paused globally, not by market.
     */
    address public pauseGuardian;
    bool public _mintGuardianPaused;
    bool public _borrowGuardianPaused;
    bool public transferGuardianPaused;
    bool public seizeGuardianPaused;
    mapping(address => bool) public mintGuardianPaused;
    mapping(address => bool) public borrowGuardianPaused;
}

contract LendtrollerV3Storage is LendtrollerV2Storage {
    struct LendMarketState {
        // The market's last updated lendBorrowIndex or lendSupplyIndex
        uint224 index;
        // The block number the index was last updated at
        uint32 block;
    }

    /// @notice A list of all markets
    LToken[] public allMarkets;

    /// @notice The rate at which the flywheel distributes LEND, per block
    uint256 public lendRate;

    /// @notice The portion of lendRate that each market currently receives
    mapping(address => uint256) public lendSpeeds;

    /// @notice The LEND market supply state for each market
    mapping(address => LendMarketState) public lendSupplyState;

    /// @notice The LEND market borrow state for each market
    mapping(address => LendMarketState) public lendBorrowState;

    /// @notice The LEND borrow index for each market for each supplier as of the last time they accrued LEND
    mapping(address => mapping(address => uint256)) public lendSupplierIndex;

    /// @notice The LEND borrow index for each market for each borrower as of the last time they accrued LEND
    mapping(address => mapping(address => uint256)) public lendBorrowerIndex;

    /// @notice The LEND accrued but not yet transferred to each user
    mapping(address => uint256) public lendAccrued;
}

contract LendtrollerV4Storage is LendtrollerV3Storage {
    // @notice The borrowCapGuardian can set borrowCaps to any number for any market. Lowering the borrow cap uld disable borrowing on the given market.
    address public borrowCapGuardian;

    // @notice Borrow caps enforced by borrowAllowed for each lToken address. Defaults to zero which corresponds to unlimited borrowing.
    mapping(address => uint256) public borrowCaps;
}

contract LendtrollerV5Storage is LendtrollerV4Storage {
    /// @notice The portion of LEND that each contributor receives per block
    mapping(address => uint256) public lendContributorSpeeds;

    /// @notice Last block at which a contributor's LEND rewards have been allocated
    mapping(address => uint256) public lastContributorBlock;
}

contract LendtrollerV6Storage is LendtrollerV5Storage {
    /// @notice The rate at which lend is distributed to the corresponding borrow market (per block)
    mapping(address => uint256) public lendBorrowSpeeds;

    /// @notice The rate at which lend is distributed to the corresponding supply market (per block)
    mapping(address => uint256) public lendSupplySpeeds;
}

contract LendtrollerV7Storage is LendtrollerV6Storage {
    /// @notice Flag indicating whether the function to fix LEND accruals has been executed (RE: proposal 62 bug)
    bool public proposal65FixExecuted;

    /// @notice Accounting storage mapping account addresses to how much LEND they owe the protocol.
    mapping(address => uint256) public lendReceivable;
}
