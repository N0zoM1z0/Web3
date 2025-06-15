// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import "forge-std/Test.sol";
// Import script utils
import {FinalConfigScript} from "scripts/deployment/FinalConfig.s.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IEth0} from "src/interfaces/token/IEth0.sol";
import {WSTETH} from "src/constants.sol";

import {DaoCollateral} from "src/daoCollateral/DaoCollateral.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {TokenMapping} from "src/TokenMapping.sol";
import {ClassicalOracle} from "src/oracles/ClassicalOracle.sol";

/// @author  Usual Tech Team
/// @title   Curve Deployment Script
/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting

contract BaseDeploymentTest is Test {
    FinalConfigScript public deploy;
    IRegistryContract public registryContract;
    IRegistryAccess public registryAccess;
    IEth0 public ETH0;
    ERC20 public collateralToken = ERC20(WSTETH);
    TokenMapping public tokenMapping;
    ClassicalOracle public classicalOracle;
    address public usual;
    address public alice;
    address public bob;
    address public usualDAO;
    DaoCollateral public daoCollateral;
    address public treasury;
    address public mintcapOperator;
    address public constant STABLESWAP_NG_FACTORY = 0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf;

    function setUp() public virtual {
        uint256 forkId = vm.createFork("eth");
        vm.selectFork(forkId);
        require(vm.activeFork() == forkId, "Fork not found");
        deploy = new FinalConfigScript();
        deploy.run();
        ETH0 = deploy.eth0();
        console.log("ETH0 address:", address(ETH0));
        vm.label(address(ETH0), "ETH0");
        vm.label(address(collateralToken), "collateralToken");
        registryContract = deploy.registryContract();
        registryAccess = deploy.registryAccess();
        classicalOracle = deploy.classicalOracle();
        vm.label(address(classicalOracle), "classicalOracle");
        tokenMapping = deploy.tokenMapping();
        treasury = deploy.treasury();
        vm.label(treasury, "treasury");
        usualDAO = deploy.usual();
        vm.label(address(usualDAO), "usualDAO");
        daoCollateral = deploy.daoCollateral();
        vm.label(address(daoCollateral), "daoCollateral");
        alice = deploy.alice();
        vm.label(alice, "alice");
        bob = deploy.bob();
        vm.label(bob, "bob");
        mintcapOperator = deploy.mintcapOperator();
        vm.label(mintcapOperator, "mintcapOperator");
    }
}
