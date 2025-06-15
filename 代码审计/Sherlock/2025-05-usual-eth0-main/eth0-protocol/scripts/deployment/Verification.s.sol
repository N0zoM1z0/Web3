// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {
    CONTRACT_REGISTRY_ACCESS,
    CONTRACT_DAO_COLLATERAL,
    CONTRACT_TOKEN_MAPPING,
    CONTRACT_ORACLE,
    CONTRACT_ETH0,
    ETH0_BURN,
    ETH0_MINT,
    USUAL_PROXY_ADMIN_MAINNET,
    USUAL_MULTISIG_MAINNET,
    DEFAULT_ADMIN_ROLE,
    TREASURY_MAINNET
} from "src/constants.sol";

contract VerifyScript is Script {
    IRegistryContract public registryContract;
    IRegistryAccess public registryAccess;
    address public eth0;
    address public tokenMapping;
    address public daoCollateral;
    address public classicalOracle;

    address public constant CONTRACT_REGISTRY_MAINNET = 0x0594cb5ca47eFE1Ff25C7B8B43E221683B4Db34c;

    address eth0Mainnet = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5;
    address tokenMappingMainnet = 0x43882C864a406D55411b8C166bCA604709fDF624;
    address daoCollateralMainnet = 0xde6e1F680C4816446C8D515989E2358636A38b04;
    address registryAccessMainnet = 0x0D374775E962c3608B8F0A4b8B10567DF739bb56;
    address registryContractMainnet = 0x0594cb5ca47eFE1Ff25C7B8B43E221683B4Db34c;
    address classicalOracleMainnet = 0xb97e163cE6A8296F36112b042891CFe1E23C35BF;

    address eth0MainnetImplementation = 0xAe12F6F805842e6Dafe71a6d2b41B28BA5fC821e;
    address tokenMappingMainnetImplementation = 0x334b18E5e81657efA2057F80e19b8E81F0e5783C;
    address daoCollateralMainnetImplementation = 0x0eEc861D49f15F585D6Bb4301FC4f89BCe22AF4e;
    address registryAccessMainnetImplementation = 0x7D355D14b8dE1210ac69EbE3aEbCc5e002cDf63B;
    address registryContractMainnetImplementation = 0x81221180B4B2fc01975817d4B7E1F4ADADcf8388;
    address classicalOracleMainnetImplementation = 0xdec568b8b19ba18af4F48863eF096a383C0eD8FD;

    ProxyAdmin eth0ProxyAdmin;
    ProxyAdmin registryAccessProxyAdmin;
    ProxyAdmin registryContractProxyAdmin;
    ProxyAdmin tokenMappingProxyAdmin;
    ProxyAdmin daoCollateralProxyAdmin;
    ProxyAdmin classicalOracleProxyAdmin;

    function run() public {
        if (block.chainid == 1) {
            // Mainnet
            registryContract = IRegistryContract(CONTRACT_REGISTRY_MAINNET);
        } else {
            revert("Unsupported network");
        }
        registryAccess = IRegistryAccess(registryContract.getContract(CONTRACT_REGISTRY_ACCESS));
        daoCollateral = registryContract.getContract(CONTRACT_DAO_COLLATERAL);
        eth0 = registryContract.getContract(CONTRACT_ETH0);
        tokenMapping = registryContract.getContract(CONTRACT_TOKEN_MAPPING);
        classicalOracle = registryContract.getContract(CONTRACT_ORACLE);

        // Set the RegistryAccess contract address and expected addresses based on the network
        if (block.chainid == 1) {
            console.log("####################################################");
            console.log("# Fetching addresses from Mainnet ContractRegistry #");
            console.log("####################################################");
            // Mainnet
            verifyExpectedAddress(eth0Mainnet, eth0);
            verifyExpectedAddress(tokenMappingMainnet, tokenMapping);
            verifyExpectedAddress(daoCollateralMainnet, daoCollateral);
            verifyExpectedAddress(registryAccessMainnet, address(registryAccess));

            eth0ProxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(eth0Mainnet));
            registryAccessProxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(registryAccessMainnet));
            registryContractProxyAdmin =
                ProxyAdmin(Upgrades.getAdminAddress(registryContractMainnet));
            tokenMappingProxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(tokenMappingMainnet));
            daoCollateralProxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(daoCollateralMainnet));
            classicalOracleProxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(classicalOracleMainnet));

            console.log("Verifying Accounts Assigned the role: ETH0_MINT");
            verifyRole(ETH0_MINT, daoCollateral);
            console.log("Verifying Accounts Assigned the role: ETH0_BURN");
            verifyRole(ETH0_BURN, daoCollateral);
            console.log("Verifying Accounts Assigned the role: DEFAULT_ADMIN_ROLE");
            verifyRole(DEFAULT_ADMIN_ROLE, USUAL_MULTISIG_MAINNET);

            console.log("###################################################################");
            console.log("# Verifying the owner of the admin contracts for proxy is correct #");
            console.log("###################################################################");

            verifyOwner(eth0ProxyAdmin, USUAL_PROXY_ADMIN_MAINNET);
            console.log("ETH0 ProxyAdmin OK");
            verifyOwner(registryAccessProxyAdmin, USUAL_PROXY_ADMIN_MAINNET);
            console.log("RegistryAccess ProxyAdmin OK");
            verifyOwner(registryContractProxyAdmin, USUAL_PROXY_ADMIN_MAINNET);
            console.log("RegistryContract ProxyAdmin OK");
            verifyOwner(tokenMappingProxyAdmin, USUAL_PROXY_ADMIN_MAINNET);
            console.log("TokenMappingProxyAdmin OK");
            verifyOwner(daoCollateralProxyAdmin, USUAL_PROXY_ADMIN_MAINNET);
            console.log("DaoCollateral ProxyAdmin OK");
            verifyOwner(classicalOracleProxyAdmin, USUAL_PROXY_ADMIN_MAINNET);
            console.log("ClassicalOracle ProxyAdmin OK");

            console.log("######################################################");
            console.log("# Verifying the implementation addresses are what we expect #");
            console.log("######################################################");

            verifyImplementation(eth0Mainnet, eth0MainnetImplementation);
            console.log("ETH0 implementation OK");
            verifyImplementation(registryAccessMainnet, registryAccessMainnetImplementation);
            console.log("RegistryAccess implementation OK");
            verifyImplementation(registryContractMainnet, registryContractMainnetImplementation);
            console.log("RegistryContract implementation OK");
            verifyImplementation(tokenMappingMainnet, tokenMappingMainnetImplementation);
            console.log("TokenMapping implementation OK");
            verifyImplementation(daoCollateralMainnet, daoCollateralMainnetImplementation);
            console.log("DaoCollateral implementation OK");
            verifyImplementation(classicalOracleMainnet, classicalOracleMainnetImplementation);
            console.log("ClassicalOracle implementation OK");
        } else {
            revert("Unsupported network");
        }
        DisplayProxyAdminAddresses();
    }

    function verifyRole(bytes32 role, address roleAddress) internal view {
        bool hasRole = registryAccess.hasRole(role, roleAddress);
        require(hasRole, "Role not set correctly");
        console.log("Role verified for address", roleAddress);
    }

    function verifyOwner(ProxyAdmin proxyAdmin, address owner) internal view {
        require(proxyAdmin.owner() == owner);
    }

    function verifyImplementation(address proxy, address implementation) internal view {
        require(
            Upgrades.getImplementationAddress(proxy) == implementation,
            "Implementation address for proxy is not correct"
        );
    }

    function verifyExpectedAddress(address expected, address actual) internal pure {
        require(expected == actual, "Address does not match expected on current network");
    }

    function DisplayProxyAdminAddresses() public view {
        IRegistryContract RegistryContractProxy;
        // Check that the script is running on the correct chain
        if (block.chainid == 1) {
            RegistryContractProxy = IRegistryContract(CONTRACT_REGISTRY_MAINNET);
        } else {
            console.log("Invalid chain");
            return;
        }
        address eth0_ = RegistryContractProxy.getContract(CONTRACT_ETH0);
        address registryAccess_ = RegistryContractProxy.getContract(CONTRACT_REGISTRY_ACCESS);
        address tokenMapping_ = RegistryContractProxy.getContract(CONTRACT_TOKEN_MAPPING);
        address daoCollateral_ = RegistryContractProxy.getContract(CONTRACT_DAO_COLLATERAL);
        address classicalOracle_ = RegistryContractProxy.getContract(CONTRACT_ORACLE);

        ProxyAdmin proxyAdmin;
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(eth0_));
        console.log("ETH0 ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());

        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(registryAccess_));
        console.log("RegistryAccess ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(address(RegistryContractProxy)));
        console.log(
            "RegistryContract ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner()
        );
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(tokenMapping_));
        console.log("TokenMapping ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(daoCollateral_));
        console.log("DaoCollateral ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
        proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(classicalOracle_));
        console.log("ClassicalOracle ProxyAdmin", address(proxyAdmin), "owner:", proxyAdmin.owner());
    }
}
