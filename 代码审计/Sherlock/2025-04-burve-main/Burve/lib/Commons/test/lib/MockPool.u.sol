// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

/*
 * Here we emulate the behavior of deploying a 2sAMM with a factory/deployer.
 * The deployment process is somewhat complicated and we use this to test
 * each component.
 */

contract MockDeployer {
    struct Params {
        bytes32 pepper;
    }

    Params public parameters;

    // We don't need an extra deploy step but to better immitate real deploys we do this.
    function deploy(bytes32 salt) public returns (address pool) {
        parameters.pepper = salt;
        pool = address(new MockPool{ salt: salt }());
        delete parameters;
    }
}

contract MockFactory is MockDeployer {
    function createPool(bytes32 salt) public returns (address pool) {
        pool = deploy(salt);
    }
}

contract MockPool {
    bytes32 pepper;

    // An argumentless contract so we can deterministically
    // predict the deployed address.
    constructor() {
        pepper = MockDeployer(msg.sender).parameters();
    }
}
