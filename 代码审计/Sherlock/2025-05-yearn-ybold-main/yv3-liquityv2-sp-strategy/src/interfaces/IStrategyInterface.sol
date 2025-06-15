// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IBaseHealthCheck} from "@periphery/Bases/HealthCheck/IBaseHealthCheck.sol";

interface IStrategyInterface is IBaseHealthCheck {

    // Storage
    function openDeposits() external view returns (bool);
    function maxGasPriceToTend() external view returns (uint256);
    function bufferPercentage() external view returns (uint256);
    function dustThreshold() external view returns (uint256);
    function allowed(
        address _address
    ) external view returns (bool);
    function ORACLE_DOWN_BUFFER_PCT_MULTIPLIER() external view returns (uint256);
    function MIN_BUFFER_PERCENTAGE() external view returns (uint256);
    function MIN_DUST_THRESHOLD() external view returns (uint256);
    function COLL() external view returns (address);
    function COLL_PRICE_ORACLE() external view returns (address);
    function SP() external view returns (address);
    function AUCTION() external view returns (address);

    // View
    function isCollateralGainToClaim() external view returns (bool);
    function estimatedTotalAssets() external view returns (uint256);

    // Management
    function allowDeposits() external;
    function setMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) external;
    function setBufferPercentage(
        uint256 _bufferPercentage
    ) external;
    function setDustThreshold(
        uint256 _dustThreshold
    ) external;
    function setAllowed(
        address _address
    ) external;
    function sweep(
        ERC20 _token
    ) external;

    // Mutated
    function claim() external;
    function claimNoDeposit() external;

}
