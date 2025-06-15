// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

import {IStrategyInterface as IStrategy} from "../interfaces/IStrategyInterface.sol";
import {IMultiTroveGetter} from "../interfaces/IMultiTroveGetter.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {ICollateralRegistry} from "../interfaces/ICollateralRegistry.sol";

contract StrategyAprOracle is AprOracleBase {

    // ===============================================================
    // Storage
    // ===============================================================

    /// @notice Collateral index to bias mapping
    mapping(uint256 collateralIndex => uint256 bias) public collateralBias;

    // ===============================================================
    // Constants
    // ===============================================================

    /// @notice WAD constant
    uint256 private constant WAD = 1e18;

    /// @notice MultiTroveGetter contract
    IMultiTroveGetter public immutable MULTI_TROVE_GETTER;

    /// @notice CollateralRegistry contract
    ICollateralRegistry public immutable COLLATERAL_REGISTRY;

    // ===============================================================
    // Constructor
    // ===============================================================

    /// @param _governance Address of the Governance contract
    /// @param _multiTroveGetter Address of the MultiTroveGetter contract
    /// @param _collateralRegistry Address of the CollateralRegistry contract
    constructor(
        address _governance,
        address _multiTroveGetter,
        address _collateralRegistry
    ) AprOracleBase("Liquity V2 SP Strategy APR Oracle", _governance) {
        MULTI_TROVE_GETTER = IMultiTroveGetter(_multiTroveGetter);
        COLLATERAL_REGISTRY = ICollateralRegistry(_collateralRegistry);
    }

    // ===============================================================
    // Governance functions
    // ===============================================================

    /// @notice Sets the bias for a specific collateral type
    /// @param _collateralIndex The collateral index
    /// @param _bias The bias multiplier (e.g., 1e18 = no bias, 1.2e18 = 20% increase)
    function setCollateralBias(uint256 _collateralIndex, uint256 _bias) external onlyGovernance {
        require(_bias >= 1e18, "!_bias");
        collateralBias[_collateralIndex] = _bias;
    }

    // ===============================================================
    // View functions
    // ===============================================================

    /**
     * @notice Will return the expected Apr of a strategy post a debt change.
     * @dev _delta is a signed integer so that it can also represent a debt
     * decrease.
     *
     * This should return the annual expected return at the current timestamp
     * represented as 1e18.
     *
     *      ie. 10% == 1e17
     *
     * _delta will be == 0 to get the current apr.
     *
     * This will potentially be called during non-view functions so gas
     * efficiency should be taken into account.
     *
     * @param _strategy The token to get the apr for.
     * @param _delta The difference in debt.
     * @return . The expected apr for the strategy represented as 1e18.
     */
    function aprAfterDebtChange(address _strategy, int256 _delta) external view override returns (uint256) {
        uint256 _collateralIndex = _getCollateralIndex(IStrategy(_strategy).COLL());
        ITroveManager _troveManager = COLLATERAL_REGISTRY.getTroveManager(_collateralIndex);
        uint256 _count = _troveManager.sortedTroves().getSize();
        IMultiTroveGetter.CombinedTroveData[] memory _troves = MULTI_TROVE_GETTER.getMultipleSortedTroves(
            _collateralIndex,
            0, // startIdx
            _count
        );

        // slither-disable-start uninitialized-local
        uint256 _totalDebt;
        uint256 _weightedInterestRate;
        for (uint256 i = 0; i < _count; ++i) {
            uint256 _debt = _troves[i].entireDebt;
            uint256 _annualInterestRate = _troves[i].annualInterestRate;
            if (_debt == 0 || _annualInterestRate == 0) continue;
            _totalDebt += _debt;
            _weightedInterestRate += _annualInterestRate * _debt;
        }

        if (_totalDebt == 0 || _weightedInterestRate == 0) return 0;

        uint256 _stabilityPoolDeposits = _troveManager.stabilityPool().getTotalBoldDeposits();
        if (_stabilityPoolDeposits == 0) return 0;
        if (_delta < 0) require(uint256(_delta * -1) < _stabilityPoolDeposits, "!delta");

        uint256 _bias = collateralBias[_collateralIndex];
        if (_bias == 0) _bias = WAD;

        // slither-disable-next-line divide-before-multiply
        return _weightedInterestRate / _totalDebt * _totalDebt / uint256(int256(_stabilityPoolDeposits) + _delta)
            * _bias / WAD;
    }

    // ===============================================================
    // Internal functions
    // ===============================================================

    function _getCollateralIndex(
        address _collateralToken
    ) internal view returns (uint256) {
        uint256 _length = COLLATERAL_REGISTRY.totalCollaterals();
        for (uint256 i = 0; i < _length; ++i) {
            if (COLLATERAL_REGISTRY.getToken(i) == _collateralToken) return i;
        }
        revert("!_collateralToken");
    }

}
