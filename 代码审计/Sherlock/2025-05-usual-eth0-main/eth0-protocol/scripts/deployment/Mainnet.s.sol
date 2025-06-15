// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {RegistryAccess} from "src/registry/RegistryAccess.sol";
import {RegistryContract} from "src/registry/RegistryContract.sol";
import {TokenMapping} from "src/TokenMapping.sol";
import {Eth0} from "src/token/Eth0.sol";

import {DaoCollateral} from "src/daoCollateral/DaoCollateral.sol";
import {RwaFactoryMock} from "src/mock/rwaFactoryMock.sol";

import {ClassicalOracle} from "src/oracles/ClassicalOracle.sol";
import {LidoProxyWstETHPriceFeed} from "src/oracles/LidoWstEthOracle.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {
    CONTRACT_DAO_COLLATERAL,
    CONTRACT_ORACLE,
    CONTRACT_REGISTRY_ACCESS,
    CONTRACT_TOKEN_MAPPING,
    CONTRACT_TREASURY,
    CONTRACT_ETH0,
    ETH0Name,
    ETH0Symbol,
    WSTETH,
    CONTRACT_YIELD_TREASURY,
    TREASURY_MAINNET,
    TREASURY_YIELD_MAINNET,
    ETH0_MINT,
    ETH0_BURN,
    USUAL_PROXY_ADMIN_MAINNET
} from "src/constants.sol";
import {
    REGISTRY_SALT,
    DETERMINISTIC_DEPLOYMENT_PROXY,
    REDEEM_FEE,
    CONTRACT_RWA_FACTORY
} from "src/mock/constants.sol";
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

contract ContractScript is Script {
    TokenMapping public tokenMapping;
    LidoProxyWstETHPriceFeed public lidoWstEthOracle;
    IRegistryContract public registryContract;
    Eth0 public ETH0;
    DaoCollateral public daoCollateral;
    RwaFactoryMock public rwaFactoryMock;
    IRegistryAccess public registryAccess;
    ClassicalOracle public classicalOracle;

    uint256 public constant INITIAL_MINT_CAP = 1 ether;
    // TODO: Change this
    address public constant DAO_ADMIN = 0x3B512A330bD4E899D37D61C80187Af49C3ad249A;

    function _computeAddress(bytes32 salt, bytes memory _code, address _deployerAddress)
        internal
        pure
        returns (address addr)
    {
        bytes memory bytecode = abi.encodePacked(_code, abi.encode(_deployerAddress));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), DETERMINISTIC_DEPLOYMENT_PROXY, salt, keccak256(bytecode)
            )
        );
        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        Options memory upgradeOptions;
        vm.startBroadcast(deployerPrivateKey);
        // Get deployer address
        address deployerAddress = vm.addr(deployerPrivateKey);
        address computedRegAccessAddress =
            _computeAddress(REGISTRY_SALT, type(RegistryAccess).creationCode, deployerAddress);
        registryAccess = IRegistryAccess(computedRegAccessAddress);
        // RegistryAccess
        if (computedRegAccessAddress.code.length == 0) {
            upgradeOptions.defender.salt = REGISTRY_SALT;
            registryAccess = IRegistryAccess(
                Upgrades.deployTransparentProxy(
                    "RegistryAccess.sol",
                    USUAL_PROXY_ADMIN_MAINNET,
                    abi.encodeCall(RegistryAccess.initialize, (address(deployerAddress))),
                    upgradeOptions
                )
            );
            console.log("RegistryAccess deployed at: %s", address(registryAccess));
        }
        address computedRegContractAddress = _computeAddress(
            REGISTRY_SALT, type(RegistryContract).creationCode, address(deployerAddress)
        );
        registryContract = RegistryContract(computedRegContractAddress);
        // RegistryContract
        if (computedRegContractAddress.code.length == 0) {
            upgradeOptions.defender.salt = REGISTRY_SALT;
            registryContract = IRegistryContract(
                Upgrades.deployTransparentProxy(
                    "RegistryContract.sol",
                    USUAL_PROXY_ADMIN_MAINNET,
                    abi.encodeCall(RegistryContract.initialize, (address(registryAccess))),
                    upgradeOptions
                )
            );
            console.log("RegistryContract deployed at: %s", address(registryContract));
        }

        // Set yield treasury to registry contract
        registryContract.setContract(CONTRACT_YIELD_TREASURY, TREASURY_YIELD_MAINNET);

        registryContract.setContract(CONTRACT_REGISTRY_ACCESS, address(registryAccess));
        // TokenMapping
        tokenMapping = TokenMapping(
            Upgrades.deployTransparentProxy(
                "TokenMapping.sol",
                USUAL_PROXY_ADMIN_MAINNET,
                abi.encodeCall(
                    TokenMapping.initialize, (address(registryAccess), address(registryContract))
                )
            )
        );
        console.log("TokenMapping deployed at: %s", address(tokenMapping));
        registryContract.setContract(CONTRACT_TOKEN_MAPPING, address(tokenMapping));
        // Eth0
        ETH0 = Eth0(
            Upgrades.deployTransparentProxy(
                "Eth0.sol",
                USUAL_PROXY_ADMIN_MAINNET,
                abi.encodeCall(Eth0.initialize, (address(registryContract), ETH0Name, ETH0Symbol))
            )
        );
        registryContract.setContract(CONTRACT_ETH0, address(ETH0));

        // Add wstETH to token mapping
        tokenMapping.addEth0CollateralToken(WSTETH);

        // BucketDistribution
        registryContract.setContract(CONTRACT_TREASURY, TREASURY_MAINNET);

        classicalOracle = ClassicalOracle(
            Upgrades.deployTransparentProxy(
                "ClassicalOracle.sol",
                USUAL_PROXY_ADMIN_MAINNET,
                abi.encodeCall(ClassicalOracle.initialize, address(registryContract))
            )
        );
        console.log("ClassicalOracle deployed at: %s", address(classicalOracle));
        registryContract.setContract(CONTRACT_ORACLE, address(classicalOracle));
        // Deploy wstETH oracle and include it into classical oracle
        lidoWstEthOracle = new LidoProxyWstETHPriceFeed(WSTETH);
        console.log("LidoWstEthOracle deployed at: %s", address(lidoWstEthOracle));
        classicalOracle.initializeTokenOracle(WSTETH, address(lidoWstEthOracle), 4 days, false);
        // DAOCollateral
        daoCollateral = DaoCollateral(
            Upgrades.deployTransparentProxy(
                "DaoCollateral.sol",
                USUAL_PROXY_ADMIN_MAINNET,
                abi.encodeCall(DaoCollateral.initialize, (address(registryContract), REDEEM_FEE))
            )
        );
        console.log("DaoCollateral deployed at: %s", address(daoCollateral));
        registryContract.setContract(CONTRACT_DAO_COLLATERAL, address(daoCollateral));

        // Grant ETH0 mint role and burn role to DaoCollateral
        registryAccess.grantRole(ETH0_MINT, address(daoCollateral));
        registryAccess.grantRole(ETH0_BURN, address(daoCollateral));

        // Add mint cap to ETH0
        ETH0.setMintCap(INITIAL_MINT_CAP);
        // Give admin role to DAO admin and renounce the role
        registryAccess.beginDefaultAdminTransfer(DAO_ADMIN);
        vm.stopBroadcast();
    }
}
