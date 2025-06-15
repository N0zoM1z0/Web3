import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ZETACHAIN_TESTNET_CONFIG as config } from "../../config/zetachain_testnet";
import { BigNumber } from "@ethersproject/bignumber";
import * as dotenv from 'dotenv';
import { ethers } from "hardhat";
dotenv.config();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const { ethers, upgrades } = require("hardhat");
  
    await main();
  
    async function main() {
        await deployProxys();
        // await upgradeProxys();
    }
  
    async function deployContract(name: string, contract: string, args?: any[], verify?: boolean) {
        if (typeof args == 'undefined') {
            args = []
        }
        if (typeof verify == 'undefined') {
            verify = false
        }
        const deployedAddress = config.deployedAddress[name as keyof typeof config.deployedAddress]
        if (!deployedAddress || deployedAddress == "") {
                console.log("Deploying contract:", name);
                const deployResult = await deploy(contract, {
                from: deployer,
                args: args,
                log: true,
            });
            return deployResult.address;
        } else {
            if (verify) {
                await verifyContract(deployedAddress, args);
            }
            console.log("Fetch previous deployed address for", name, deployedAddress );
            return deployedAddress;
        }
    }
  
    async function verifyContract(address: string, args?: any[]) {
        if (typeof args == 'undefined') {
            args = []
        }
        try {
            await hre.run("verify:verify", {
                address: address,
                constructorArguments: args,
            });
        } catch (e) {
            if ((e as Error).message != "Contract source code already verified") {
                throw(e)
            }
            console.log((e as Error).message)
        }
    }

    async function deployProxys() {
        const d = config.defaultAddress;
        const feePercent = 10; // 1%
        const slippage = 10;
        const gasLimit = 1000000;
        
        const GatewayCrossChain = await ethers.getContractFactory('GatewayCrossChain');
        const gatewayCrossChain = await upgrades.deployProxy(GatewayCrossChain, [
            d.Gateway,
            d.MultiSig,
            d.DODORouteProxy,
            d.DODOApprove,
            feePercent,
            slippage,
            gasLimit
        ])
        await gatewayCrossChain.waitForDeployment();
        console.log("✅ GatewayCrossChain proxy deployed at:", gatewayCrossChain.target);
        const implAddress1 = await upgrades.erc1967.getImplementationAddress(gatewayCrossChain.target);
        console.log("🔧 GatewayCrossChain implementation deployed at:", implAddress1);

        const GatewayTransferNative = await ethers.getContractFactory('GatewayTransferNative');
        const gatewayTransferNative = await upgrades.deployProxy(GatewayTransferNative, [
            d.Gateway,
            d.MultiSig,
            d.DODORouteProxy,
            d.DODOApprove,
            feePercent,
            slippage,
            gasLimit
        ])
        await gatewayTransferNative.waitForDeployment();
        console.log("✅ GatewayTransferNative proxy deployed at:", gatewayTransferNative.target);
        const implAddress2 = await upgrades.erc1967.getImplementationAddress(gatewayTransferNative.target);
        console.log("🔧 GatewayTransferNative implementation deployed at:", implAddress2);
    }

    async function upgradeProxys() {
        const d = config.deployedAddress;

        const GatewayCrossChain = await ethers.getContractFactory('GatewayCrossChain');
        const upgraded1 = await upgrades.upgradeProxy(d.GatewayCrossChainProxy, GatewayCrossChain);
        console.log("✅ GatewayCrossChain proxy upgraded at:", upgraded1.target);
        const implAddress1 = await upgrades.erc1967.getImplementationAddress(upgraded1.target);
        console.log("🔧 New GatewayCrossChain implementation deployed at:", implAddress1);

        const GatewayTransferNative = await ethers.getContractFactory('GatewayTransferNative');
        const upgraded2 = await upgrades.upgradeProxy(d.GatewayTransferNativeProxy, GatewayTransferNative);
        console.log("✅ GatewayTransferNative proxy upgraded at:", upgraded2.target);
        const implAddress2 = await upgrades.erc1967.getImplementationAddress(upgraded2.target);
        console.log("🔧 New GatewayTransferNative implementation deployed at:", implAddress2);
    }
};

export default func;