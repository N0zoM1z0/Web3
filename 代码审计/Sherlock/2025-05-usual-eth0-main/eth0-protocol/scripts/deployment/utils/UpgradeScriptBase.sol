// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {ProxyAdmin} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ITransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {
    CONTRACT_REGISTRY_ACCESS,
    REGISTRY_CONTRACT_MAINNET,
    USUAL_MULTISIG_MAINNET,
    USUAL_PROXY_ADMIN_MAINNET,
    CONTRACT_REGISTRY
} from "src/constants.sol";
import {console} from "forge-std/console.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

abstract contract UpgradeScriptBase is Script {
    IRegistryContract RegistryContractProxy;
    address public USUAL_DEPLOYER = 0x10dcEb0D2717F0EfA9524D2109567526C9374B26;

    function bytesToHexString(bytes memory data) public pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory hexString = new bytes(2 + data.length * 2);

        hexString[0] = "0";
        hexString[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            hexString[2 + 2 * i] = hexChars[uint8(data[i] >> 4)];
            hexString[3 + 2 * i] = hexChars[uint8(data[i] & 0x0f)];
        }

        return string(hexString);
    }

    function run() public virtual {
        if (block.chainid == 1) {
            RegistryContractProxy = IRegistryContract(REGISTRY_CONTRACT_MAINNET);
        } else {
            console.log("Invalid chain");
            return;
        }
    }

    function DeployImplementationAndLogs(
        string memory contractName,
        bytes32 registryKey,
        bytes memory initData
    ) public returns (address proxyAdmin, address newImplementation) {
        Options memory emptyUpgradeOptions;
        address proxy;
        if (registryKey == CONTRACT_REGISTRY) {
            proxy = address(RegistryContractProxy);
        } else {
            proxy = RegistryContractProxy.getContract(registryKey);
        }
        proxyAdmin = Upgrades.getAdminAddress(proxy);
        vm.startBroadcast(USUAL_DEPLOYER);
        newImplementation = Upgrades.deployImplementation(contractName, emptyUpgradeOptions);
        vm.stopBroadcast();
        console.log(
            string(
                abi.encodePacked(
                    "Call to ", contractName, " Proxy Admin from the proxy admin multisig:"
                )
            ),
            USUAL_PROXY_ADMIN_MAINNET
        );
        console.log("Manual intervention required for upgrading");
        console.log("----8<--------8<--------8<--------8<--------8<--------");
        console.log("To(ProxyAdmin):", proxyAdmin);
        console.log("Function: upgradeAndCall (sig: 0x9623609d )");
        console.log("From(ProxyAdmin Owner):", Ownable(proxyAdmin).owner());
        console.log("Proxy:", proxy);
        console.log("Implementation:", newImplementation);
        console.log("Data: ", bytesToHexString(initData));
        console.log("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
        console.log(
            "Selector and encoded data:",
            bytesToHexString(
                abi.encodeCall(
                    ProxyAdmin.upgradeAndCall,
                    (ITransparentUpgradeableProxy(proxy), newImplementation, initData)
                )
            )
        );
        console.log("----8<--------8<--------8<--------8<--------8<--------");
        console.log("");
    }

    function SetContractAndLogs(bytes32 name, address contractAddress) public view {
        console.log(
            "Call to RegistryContract from the administrative multiSig:", USUAL_MULTISIG_MAINNET
        );
        console.log("Manual intervention required for registering");
        console.log("----8<--------8<--------8<--------8<--------8<--------");
        console.log("To RegistryContract:", address(RegistryContractProxy));
        console.log("Function: setContract (sig: 0x7ed77c9c )");
        console.log("Name(hex): ", bytesToHexString(abi.encodePacked(name)));
        console.log("Address:", contractAddress);
        console.log("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
        console.log(
            "Selector and encoded data:",
            bytesToHexString(abi.encodeCall(IRegistryContract.setContract, (name, contractAddress)))
        );
        console.log("----8<--------8<--------8<--------8<--------8<--------");
        console.log("");
    }

    function grantRoleAndLogs(bytes32 role, address account) public view {
        IAccessControl RegistryAccessProxy =
            IAccessControl(RegistryContractProxy.getContract(CONTRACT_REGISTRY_ACCESS));
        console.log(
            "/!\\ Call to RegistryAccess /!\\ from the administrative multiSig: ",
            USUAL_MULTISIG_MAINNET
        );
        console.log("Manual intervention required for granting role");
        console.log("----8<--------8<--------8<--------8<--------8<--------");
        console.log("Function: grantRole (sig: 0x2f2ff15d)");
        console.log("To RegistryAccess:", address(RegistryAccessProxy));
        console.log("Account:", account);
        console.log("Role:", bytesToHexString(abi.encodePacked(role)));
        console.log("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
        console.log(
            "selector and encoded data:",
            bytesToHexString(abi.encodeCall(IAccessControl.grantRole, (role, account)))
        );
        console.log("----8<--------8<--------8<--------8<--------8<--------");
        console.log("");
    }

    function DeployNewProxyWithImplementationAndLogsOrFail(
        string memory contractName,
        bytes32 registryKey,
        bytes memory initData
    ) public returns (address proxyAdmin, address newProxy, address newImplementation) {
        require(address(RegistryContractProxy) != address(0), "RegistryContractProxy not set");

        // Check if the contract is already registered
        try RegistryContractProxy.getContract(registryKey) {
            revert("Contract already registered in RegistryContract");
        } catch {}

        // New proxy admin owner will be the same as the owner of the proxy admin of RegistryContractProxy
        proxyAdmin = Upgrades.getAdminAddress(address(RegistryContractProxy));
        address proxyAdminOwner = Ownable(proxyAdmin).owner();

        // Deploy new implementation
        vm.startBroadcast(USUAL_DEPLOYER);
        // Deploy new proxy
        newProxy = Upgrades.deployTransparentProxy(contractName, proxyAdminOwner, initData);
        vm.stopBroadcast();

        proxyAdmin = Upgrades.getAdminAddress(newProxy);
        require(
            Ownable(proxyAdmin).owner() == USUAL_PROXY_ADMIN_MAINNET,
            "ProxyAdmin owner is not USUAL_DEPLOYER"
        );
        newImplementation = Upgrades.getImplementationAddress(newProxy);

        console.log(
            string(
                abi.encodePacked("Deployed new proxy for ", contractName, " with these parameters:")
            )
        );

        console.log("Information below needs to be saved");
        console.log("----8<--------8<--------8<--------8<--------8<--------");
        console.log("New contract:", contractName);
        console.log("Proxy:", newProxy);
        console.log("Implementation:", newImplementation);
        console.log("Proxy Admin:", proxyAdmin);
        console.log("Registry Key:", bytesToHexString(abi.encodePacked(registryKey)));
        console.log("Init Data: ", bytesToHexString(initData));
        console.log("----8<--------8<--------8<--------8<--------8<--------");
        console.log("");
        // Log the setContract call for RegistryContract
        SetContractAndLogs(registryKey, newProxy);
    }
}
