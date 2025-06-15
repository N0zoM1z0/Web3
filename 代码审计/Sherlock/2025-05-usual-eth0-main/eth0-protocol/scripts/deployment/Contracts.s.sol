// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {DataPublisher} from "src/mock/dataPublisher.sol";
import {RegistryAccess} from "src/registry/RegistryAccess.sol";
import {RegistryContract} from "src/registry/RegistryContract.sol";
import {TokenMapping} from "src/TokenMapping.sol";
import {DaoCollateral} from "src/daoCollateral/DaoCollateral.sol";
import {RwaFactoryMock} from "src/mock/rwaFactoryMock.sol";
import {ClassicalOracle} from "src/oracles/ClassicalOracle.sol";

import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {ProxyAdmin} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from
    "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Eth0} from "src/token/Eth0.sol";

import {
    CONTRACT_RWA_FACTORY,
    REGISTRY_SALT,
    DETERMINISTIC_DEPLOYMENT_PROXY
} from "src/mock/constants.sol";

import {
    ETH0Name,
    ETH0Symbol,
    CONTRACT_ETH0,
    REDEEM_FEE,
    CONTRACT_TOKEN_MAPPING,
    CONTRACT_REGISTRY_ACCESS,
    CONTRACT_ORACLE,
    CONTRACT_DATA_PUBLISHER,
    CONTRACT_DAO_COLLATERAL,
    CONTRACT_TREASURY,
    CONTRACT_YIELD_TREASURY
} from "src/constants.sol";

import {BaseScript} from "scripts/deployment/Base.s.sol";

contract ContractScript is BaseScript {
    TokenMapping public tokenMapping;
    DaoCollateral public daoCollateral;
    RwaFactoryMock public rwaFactoryMock;
    DataPublisher public dataPublisher;
    ClassicalOracle public classicalOracle;
    Eth0 public eth0;

    function _computeAddress(bytes32 salt, bytes memory _code, address _usual)
        internal
        pure
        returns (address addr)
    {
        bytes memory bytecode = abi.encodePacked(_code, abi.encode(_usual));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), DETERMINISTIC_DEPLOYMENT_PROXY, salt, keccak256(bytecode)
            )
        );
        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function run() public virtual override {
        super.run();
        Options memory upgradeOptions;
        vm.startBroadcast(deployerPrivateKey);
        address computedRegAccessAddress =
            _computeAddress(REGISTRY_SALT, type(RegistryAccess).creationCode, usual);
        registryAccess = IRegistryAccess(computedRegAccessAddress);
        // RegistryAccess
        if (computedRegAccessAddress.code.length == 0) {
            upgradeOptions.defender.salt = REGISTRY_SALT;
            registryAccess = IRegistryAccess(
                Upgrades.deployTransparentProxy(
                    "RegistryAccess.sol",
                    usualProxyAdmin,
                    abi.encodeCall(RegistryAccess.initialize, (address(usual))),
                    upgradeOptions
                )
            );
        }
        address computedRegContractAddress = _computeAddress(
            REGISTRY_SALT, type(RegistryContract).creationCode, address(registryAccess)
        );
        registryContract = RegistryContract(computedRegContractAddress);
        // RegistryContract
        if (computedRegContractAddress.code.length == 0) {
            upgradeOptions.defender.salt = REGISTRY_SALT;
            registryContract = IRegistryContract(
                Upgrades.deployTransparentProxy(
                    "RegistryContract.sol",
                    usualProxyAdmin,
                    abi.encodeCall(RegistryContract.initialize, (address(registryAccess))),
                    upgradeOptions
                )
            );
        }
        vm.stopBroadcast();
        vm.startBroadcast(usualPrivateKey);
        registryContract.setContract(CONTRACT_REGISTRY_ACCESS, address(registryAccess));
        vm.stopBroadcast();

        vm.startBroadcast(usualPrivateKey);

        // TokenMapping
        tokenMapping = TokenMapping(
            Upgrades.deployTransparentProxy(
                "TokenMapping.sol",
                usualProxyAdmin,
                abi.encodeCall(
                    TokenMapping.initialize, (address(registryAccess), address(registryContract))
                )
            )
        );

        registryContract.setContract(CONTRACT_TOKEN_MAPPING, address(tokenMapping));

        eth0 = Eth0(
            Upgrades.deployTransparentProxy(
                "Eth0.sol",
                usualProxyAdmin,
                abi.encodeCall(Eth0.initialize, (address(registryContract), ETH0Name, ETH0Symbol))
            )
        );

        registryContract.setContract(CONTRACT_ETH0, address(eth0));

        registryContract.setContract(CONTRACT_YIELD_TREASURY, treasury);
        registryContract.setContract(CONTRACT_TREASURY, treasury);

        // Oracle
        dataPublisher = new DataPublisher(address(registryContract));
        registryContract.setContract(CONTRACT_DATA_PUBLISHER, address(dataPublisher));

        classicalOracle = ClassicalOracle(
            Upgrades.deployTransparentProxy(
                "ClassicalOracle.sol",
                usualProxyAdmin,
                abi.encodeCall(ClassicalOracle.initialize, address(registryContract))
            )
        );
        registryContract.setContract(CONTRACT_ORACLE, address(classicalOracle));

        // DAOCollateral
        daoCollateral = DaoCollateral(
            Upgrades.deployTransparentProxy(
                "DaoCollateral.sol",
                usualProxyAdmin,
                abi.encodeCall(DaoCollateral.initialize, (address(registryContract), REDEEM_FEE))
            )
        );

        vm.stopBroadcast();
        vm.startBroadcast(usualPrivateKey);
        registryContract.setContract(CONTRACT_DAO_COLLATERAL, address(daoCollateral));

        // RwaFactoryMock
        rwaFactoryMock = new RwaFactoryMock(address(registryContract));
        registryContract.setContract(CONTRACT_RWA_FACTORY, address(rwaFactoryMock));

        vm.stopBroadcast();
    }
}
