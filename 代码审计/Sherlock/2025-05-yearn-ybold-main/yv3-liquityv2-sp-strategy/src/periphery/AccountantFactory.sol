// SPDX-License-Identifier: GNU AGPLv3
pragma solidity >=0.8.18;

import {Accountant} from "./Accountant.sol";

/**
 * @title AccountantFactory
 * @dev A factory contract for deploying Accountant contracts
 */
contract AccountantFactory {

    event NewAccountant(address indexed newAccountant);

    /**
     * @dev Deploys a new Accountant contract with specified fee configurations and addresses
     * @param feeManager The address to receive management and performance fees
     * @param feeRecipient The address to receive refund fees
     * @param defaultMaxGain Default maximum gain
     * @param defaultMaxLoss Default maximum loss
     * @return _newAccountant The address of the newly deployed Accountant contract
     */
    function newAccountant(
        address feeManager,
        address feeRecipient,
        uint16 defaultMaxGain,
        uint16 defaultMaxLoss
    ) public returns (address _newAccountant) {
        _newAccountant = address(new Accountant(feeManager, feeRecipient, defaultMaxGain, defaultMaxLoss));

        emit NewAccountant(_newAccountant);
    }

}
