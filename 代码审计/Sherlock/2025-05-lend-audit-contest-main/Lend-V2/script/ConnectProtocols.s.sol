// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {LendStorage} from "../src/LayerZero/LendStorage.sol";
import {CrossChainRouter} from "../src/LayerZero/CrossChainRouter.sol";

// @important - Tokens must match across all protocols.
/**
 * For 3 chains: Sepolia (A), Base Sepolia (B), Sonic Testnet (C)
 * A <-> B, A <-> C
 * B <-> C
 */
contract ConnectProtocols is Script {
    // Protocol A (Sepolia)
    address constant LEND_STORAGE_A = 0x4979286C4C397531FB6020403C9F802bca82eC6F;
    // Using coreRouterAddress
    address payable constant CROSS_CHAIN_ROUTER_A = payable(address(0xf98C3a3AfEC7377c611E29Bf2349d9ee33FEb749));
    address[] SUPPORTED_TOKENS_A = [
        0xF44D750F14203A659E9A95a9c4f787D623591208,
        0xE96754e5725d326C38f9f7CA764cb9ccFb8482D2,
        0x1eD0A99367C0Cff94b9A7cC288DCE077Ee0476e5,
        0x6F9552aeF602CD14817F64193FDDee20C86451d6,
        0x08d87C7aB886e07e0847D56e2174203C442210DF
    ];
    address[] L_TOKENS_A = [
        0x3BF04b493D844f135E934Fd18480D9FE22A6734B,
        0x30817a22f0F8f2182F855469D75D4aCb002f22D9,
        0x05F7713b2830792dCdEB3D455Bb0499C5917373F,
        0xA3c6a4d9b1a74Da7ec13f3766C3F8aF07AC39d73,
        0x849A42a741E11BbF422De0338F07Df91D1B491be
    ];

    // Protocol B (Base Sepolia)
    address constant LEND_STORAGE_B = 0xA5A18998Bf9891a8cA4A422A03fd460A0EDEC964;
    // Using coreRouterAddress
    address payable constant CROSS_CHAIN_ROUTER_B = payable(address(0x10F1fD65B33636786504ED7a92294B2516aF6326));
    address[] SUPPORTED_TOKENS_B = [
        0x3d3d3d1a0d62aa2e3e965c1752C426D2972F757a,
        0x21Df6dfBeB2220781e4CaE37B98E799247a9d187,
        0xbDbBF567F7cdb479e3D9Ae293a33031212925247,
        0x2D5B8f18391B128DB047adaB914d4956b2955D5F,
        0x3D3821B52a3b76208C65ad5D230aABf567919A8E
    ];
    address[] L_TOKENS_B = [
        0xcc11459bfA52e40c895F6A808CBD522f09E222d5,
        0x11c111B406d5b2d6E8E8b794896ac1Ae9947a44b,
        0xf33A2C025D3E200A3703d1fC55E4D644CFed209B,
        0x8554931084223498E5AD46AEaeEf3Fa7d513cbDC,
        0xEbA118B054F0c07AD6107Be9c5989eb9De715419
    ];

    // Protocol C (Sonic Testnet)
    address constant LEND_STORAGE_C = 0xC33b446a0D2703852EB26cFe6B63940B40ffd5dD;
    // Using coreRouterAddress
    address payable constant CROSS_CHAIN_ROUTER_C = payable(address(0xF3da9908b057B8bd06040B64b806A1D0Ca72C6bA));
    address[] SUPPORTED_TOKENS_C = [
        0xe2C93c997dcB166046E6892EA84D3a23CDEc5cE0,
        0x562eddAc6dEbc3037E969e6a32EC50d9FD93a59B,
        0x1F508bC15E18f132DAe86d745E946EcE42ABBcf3,
        0xaf771DeD6CA98bF48D337A2B81f38cB76B453711,
        0xa78cFdC1c888b6CEC732Df3d96cF9Fb907A486e9
    ];
    address[] L_TOKENS_C = [
        0xa0ADe3D787bC93E57374e701F9def5C4Bf2388B7,
        0xa95DBEfE119901517c034a0256ec3fb0Be9A73d4,
        0x98a96D882EabF05A3d31C67531D7d6729c92A86A,
        0xd626939670e5837819fDefCAF6b15c04e1C407E9,
        0x49e267199bFA85726b734ed61FC73ECAB3923bB1
    ];

    // Chain EIDs --> THESE ARE NOT CHAIN IDS
    uint32 constant CHAIN_A_EID = 40161; // Sepolia
    uint32 constant CHAIN_B_EID = 40245; // Base Sepolia
    uint32 constant CHAIN_C_EID = 40349; // Sonic Testnet

    function connectProtocolA() public {
        // Connect Sepolia (A) to Base Sepolia (B) and Sonic (C)
        LendStorage lendStorageA = LendStorage(LEND_STORAGE_A);

        for (uint256 i = 0; i < SUPPORTED_TOKENS_A.length; i++) {
            // Connect to B (Base Sepolia)
            lendStorageA.addUnderlyingToDestUnderlying(SUPPORTED_TOKENS_A[i], SUPPORTED_TOKENS_B[i], CHAIN_B_EID);
            lendStorageA.addUnderlyingToDestlToken(SUPPORTED_TOKENS_A[i], L_TOKENS_B[i], CHAIN_B_EID);
            lendStorageA.setChainAssetMap(SUPPORTED_TOKENS_A[i], CHAIN_B_EID, SUPPORTED_TOKENS_B[i]);
            lendStorageA.setChainLTokenMap(L_TOKENS_A[i], CHAIN_B_EID, L_TOKENS_B[i]);
            lendStorageA.setChainLTokenMap(L_TOKENS_B[i], CHAIN_B_EID, L_TOKENS_A[i]); // Reverse mapping for LToken

            // Connect to C (Sonic Testnet)
            lendStorageA.addUnderlyingToDestUnderlying(SUPPORTED_TOKENS_A[i], SUPPORTED_TOKENS_C[i], CHAIN_C_EID);
            lendStorageA.addUnderlyingToDestlToken(SUPPORTED_TOKENS_A[i], L_TOKENS_C[i], CHAIN_C_EID);
            lendStorageA.setChainAssetMap(SUPPORTED_TOKENS_A[i], CHAIN_C_EID, SUPPORTED_TOKENS_C[i]);
            lendStorageA.setChainLTokenMap(L_TOKENS_A[i], CHAIN_C_EID, L_TOKENS_C[i]);
            lendStorageA.setChainLTokenMap(L_TOKENS_C[i], CHAIN_C_EID, L_TOKENS_A[i]); // Reverse mapping for LToken
        }

        bytes32 chainBPeerAddress = bytes32(uint256(uint160(address(CROSS_CHAIN_ROUTER_B))));
        bytes32 chainCPeerAddress = bytes32(uint256(uint160(address(CROSS_CHAIN_ROUTER_C))));

        CrossChainRouter(CROSS_CHAIN_ROUTER_A).setPeer(CHAIN_B_EID, chainBPeerAddress);
        CrossChainRouter(CROSS_CHAIN_ROUTER_A).setPeer(CHAIN_C_EID, chainCPeerAddress);
    }

    function connectProtocolB() public {
        // Connect Base Sepolia (B) to Sepolia (A) and Sonic (C)
        LendStorage lendStorageB = LendStorage(LEND_STORAGE_B);

        for (uint256 i = 0; i < SUPPORTED_TOKENS_B.length; i++) {
            // Connect to A (Sepolia)
            lendStorageB.addUnderlyingToDestUnderlying(SUPPORTED_TOKENS_B[i], SUPPORTED_TOKENS_A[i], CHAIN_A_EID);
            lendStorageB.addUnderlyingToDestlToken(SUPPORTED_TOKENS_B[i], L_TOKENS_A[i], CHAIN_A_EID);
            lendStorageB.setChainAssetMap(SUPPORTED_TOKENS_B[i], CHAIN_A_EID, SUPPORTED_TOKENS_A[i]);
            lendStorageB.setChainLTokenMap(L_TOKENS_B[i], CHAIN_A_EID, L_TOKENS_A[i]);
            lendStorageB.setChainLTokenMap(L_TOKENS_A[i], CHAIN_A_EID, L_TOKENS_B[i]); // Reverse mapping for LToken

            // Connect to C (Sonic Testnet)
            lendStorageB.addUnderlyingToDestUnderlying(SUPPORTED_TOKENS_B[i], SUPPORTED_TOKENS_C[i], CHAIN_C_EID);
            lendStorageB.addUnderlyingToDestlToken(SUPPORTED_TOKENS_B[i], L_TOKENS_C[i], CHAIN_C_EID);
            lendStorageB.setChainAssetMap(SUPPORTED_TOKENS_B[i], CHAIN_C_EID, SUPPORTED_TOKENS_C[i]);
            lendStorageB.setChainLTokenMap(L_TOKENS_B[i], CHAIN_C_EID, L_TOKENS_C[i]);
            lendStorageB.setChainLTokenMap(L_TOKENS_C[i], CHAIN_C_EID, L_TOKENS_B[i]); // Reverse mapping for LToken
        }

        bytes32 chainAPeerAddress = bytes32(uint256(uint160(address(CROSS_CHAIN_ROUTER_A))));
        bytes32 chainCPeerAddress = bytes32(uint256(uint160(address(CROSS_CHAIN_ROUTER_C))));

        CrossChainRouter(CROSS_CHAIN_ROUTER_B).setPeer(CHAIN_A_EID, chainAPeerAddress);
        CrossChainRouter(CROSS_CHAIN_ROUTER_B).setPeer(CHAIN_C_EID, chainCPeerAddress);
    }

    function connectProtocolC() public {
        // Connect Sonic Testnet (C) to Sepolia (A) and Base Sepolia (B)
        LendStorage lendStorageC = LendStorage(LEND_STORAGE_C);

        for (uint256 i = 0; i < SUPPORTED_TOKENS_C.length; i++) {
            // Connect to A (Sepolia)
            lendStorageC.addUnderlyingToDestUnderlying(SUPPORTED_TOKENS_C[i], SUPPORTED_TOKENS_A[i], CHAIN_A_EID);
            lendStorageC.addUnderlyingToDestlToken(SUPPORTED_TOKENS_C[i], L_TOKENS_A[i], CHAIN_A_EID);
            lendStorageC.setChainAssetMap(SUPPORTED_TOKENS_C[i], CHAIN_A_EID, SUPPORTED_TOKENS_A[i]);
            lendStorageC.setChainLTokenMap(L_TOKENS_C[i], CHAIN_A_EID, L_TOKENS_A[i]);
            lendStorageC.setChainLTokenMap(L_TOKENS_A[i], CHAIN_A_EID, L_TOKENS_C[i]); // Reverse mapping for LToken

            // Connect to B (Base Sepolia)
            lendStorageC.addUnderlyingToDestUnderlying(SUPPORTED_TOKENS_C[i], SUPPORTED_TOKENS_B[i], CHAIN_B_EID);
            lendStorageC.addUnderlyingToDestlToken(SUPPORTED_TOKENS_C[i], L_TOKENS_B[i], CHAIN_B_EID);
            lendStorageC.setChainAssetMap(SUPPORTED_TOKENS_C[i], CHAIN_B_EID, SUPPORTED_TOKENS_B[i]);
            lendStorageC.setChainLTokenMap(L_TOKENS_C[i], CHAIN_B_EID, L_TOKENS_B[i]);
            lendStorageC.setChainLTokenMap(L_TOKENS_B[i], CHAIN_B_EID, L_TOKENS_C[i]); // Reverse mapping for LToken
        }

        bytes32 chainAPeerAddress = bytes32(uint256(uint160(address(CROSS_CHAIN_ROUTER_A))));
        bytes32 chainBPeerAddress = bytes32(uint256(uint160(address(CROSS_CHAIN_ROUTER_B))));

        CrossChainRouter(CROSS_CHAIN_ROUTER_C).setPeer(CHAIN_A_EID, chainAPeerAddress);
        CrossChainRouter(CROSS_CHAIN_ROUTER_C).setPeer(CHAIN_B_EID, chainBPeerAddress);
    }

    function run() public {
        require(
            SUPPORTED_TOKENS_A.length == SUPPORTED_TOKENS_B.length
                && SUPPORTED_TOKENS_A.length == SUPPORTED_TOKENS_C.length && SUPPORTED_TOKENS_A.length == L_TOKENS_A.length
                && L_TOKENS_A.length == L_TOKENS_B.length && L_TOKENS_B.length == L_TOKENS_C.length,
            "Array lengths must match"
        );

        vm.startBroadcast();
        if (block.chainid == 11155111) {
            // Sepolia (A)
            connectProtocolA();
        } else if (block.chainid == 84532) {
            // Base Sepolia (B)
            connectProtocolB();
        } else if (block.chainid == 57054) {
            // Sonic Testnet (C)
            connectProtocolC();
        } else {
            revert("Unsupported chain");
        }
        vm.stopBroadcast();
    }
}
