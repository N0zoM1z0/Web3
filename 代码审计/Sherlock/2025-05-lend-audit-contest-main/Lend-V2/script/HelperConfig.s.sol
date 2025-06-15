// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {WETH9} from "../test/mocks/WETH9.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address layerZeroEndpoint;
        address[] supportedTokens;
        bool isMock;
        address wethAddress;
        bytes32[] pythPriceIds;
        address[] chainlinkFeeds;
        uint32 currentEid;
        address pythAddress;
    }

    NetworkConfig private activeNetworkConfig;

    // Testnet Chain IDs
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant HYPEREVM_TESTNET_CHAIN_ID = 999;
    uint256 public constant SONIC_TESTNET_CHAIN_ID = 57054;

    constructor() {
        if (block.chainid == HYPEREVM_TESTNET_CHAIN_ID) {
            activeNetworkConfig = getHyperEVMTestnetConfig();
        } else if (block.chainid == SONIC_TESTNET_CHAIN_ID) {
            activeNetworkConfig = getSonicTestnetConfig();
        } else if (block.chainid == BASE_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getBaseSepoliaConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        address dai = address(new ERC20Mock());
        address usdc = address(new ERC20Mock());
        address usdt = address(new ERC20Mock());
        address weth = address(new WETH9());
        address wbtc = address(new ERC20Mock());
        vm.stopBroadcast();

        address[] memory supportedTokens = new address[](5);
        supportedTokens[0] = dai;
        supportedTokens[1] = usdc;
        supportedTokens[2] = usdt;
        supportedTokens[3] = weth;
        supportedTokens[4] = wbtc;

        bytes32[] memory pythPriceIds = new bytes32[](5);
        pythPriceIds[0] = 0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;
        pythPriceIds[1] = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        pythPriceIds[2] = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
        pythPriceIds[3] = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
        pythPriceIds[4] = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

        address[] memory chainlinkFeeds = new address[](5);
        chainlinkFeeds[0] = 0xD1092a65338d049DB68D7Be6bD89d17a0929945e;
        chainlinkFeeds[1] = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
        chainlinkFeeds[2] = 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f;
        chainlinkFeeds[3] = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
        chainlinkFeeds[4] = 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298;

        uint32 eid = 40245;

        return NetworkConfig({
            layerZeroEndpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            supportedTokens: supportedTokens,
            isMock: false,
            wethAddress: weth,
            pythPriceIds: pythPriceIds,
            chainlinkFeeds: chainlinkFeeds,
            currentEid: eid,
            pythAddress: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729
        });
    }

    function getHyperEVMTestnetConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        address dai = address(new ERC20Mock());
        address usdc = address(new ERC20Mock());
        address usdt = address(new ERC20Mock());
        address weth = address(new WETH9());
        address wbtc = address(new ERC20Mock());
        vm.stopBroadcast();

        address[] memory supportedTokens = new address[](5);
        supportedTokens[0] = dai;
        supportedTokens[1] = usdc;
        supportedTokens[2] = usdt;
        supportedTokens[3] = weth;
        supportedTokens[4] = wbtc;

        bytes32[] memory pythPriceIds = new bytes32[](5);
        pythPriceIds[0] = 0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;
        pythPriceIds[1] = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        pythPriceIds[2] = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
        pythPriceIds[3] = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
        pythPriceIds[4] = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

        address[] memory chainlinkFeeds = new address[](0);

        uint32 eid = 40362;

        return NetworkConfig({
            layerZeroEndpoint: 0xf9e1815F151024bDE4B7C10BAC10e8Ba9F6b53E1,
            supportedTokens: supportedTokens,
            isMock: false,
            wethAddress: weth,
            pythPriceIds: pythPriceIds,
            chainlinkFeeds: chainlinkFeeds,
            currentEid: eid,
            pythAddress: 0x2880aB155794e7179c9eE2e38200202908C17B43
        });
    }

    function getSonicTestnetConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        address dai = address(new ERC20Mock());
        address usdc = address(new ERC20Mock());
        address usdt = address(new ERC20Mock());
        address weth = address(new WETH9());
        address wbtc = address(new ERC20Mock());
        vm.stopBroadcast();

        address[] memory supportedTokens = new address[](5);
        supportedTokens[0] = dai;
        supportedTokens[1] = usdc;
        supportedTokens[2] = usdt;
        supportedTokens[3] = weth;
        supportedTokens[4] = wbtc;

        bytes32[] memory pythPriceIds = new bytes32[](5);
        pythPriceIds[0] = 0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;
        pythPriceIds[1] = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        pythPriceIds[2] = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
        pythPriceIds[3] = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
        pythPriceIds[4] = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

        address[] memory chainlinkFeeds = new address[](0);

        uint32 eid = 40349;

        return NetworkConfig({
            layerZeroEndpoint: 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff,
            supportedTokens: supportedTokens,
            isMock: false,
            wethAddress: weth,
            pythPriceIds: pythPriceIds,
            chainlinkFeeds: chainlinkFeeds,
            currentEid: eid,
            pythAddress: 0x2880aB155794e7179c9eE2e38200202908C17B43
        });
    }

    function getSepoliaConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();

        address dai = address(new ERC20Mock());

        address usdc = address(new ERC20Mock());

        address usdt = address(new ERC20Mock());

        address weth = address(new WETH9());

        address wbtc = address(new ERC20Mock());

        vm.stopBroadcast();

        address[] memory supportedTokens = new address[](5);
        supportedTokens[0] = dai;
        supportedTokens[1] = usdc;
        supportedTokens[2] = usdt;
        supportedTokens[3] = weth;
        supportedTokens[4] = wbtc;

        bytes32[] memory pythPriceIds = new bytes32[](5);
        pythPriceIds[0] = 0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;
        pythPriceIds[1] = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
        pythPriceIds[2] = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
        pythPriceIds[3] = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
        pythPriceIds[4] = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

        address[] memory chainlinkFeeds = new address[](5);
        chainlinkFeeds[0] = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
        chainlinkFeeds[1] = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
        chainlinkFeeds[2] = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
        chainlinkFeeds[3] = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        chainlinkFeeds[4] = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

        uint32 eid = 40161;

        return NetworkConfig({
            layerZeroEndpoint: 0x6EDCE65403992e310A62460808c4b910D972f10f,
            supportedTokens: supportedTokens,
            isMock: false,
            wethAddress: weth,
            pythPriceIds: pythPriceIds,
            chainlinkFeeds: chainlinkFeeds,
            currentEid: eid,
            pythAddress: 0xDd24F84d36BF92C65F92307595335bdFab5Bbd21
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // Deploy mocks for local testing
        vm.startBroadcast();

        // Deploy mock tokens
        ERC20Mock mockToken1 = new ERC20Mock();
        ERC20Mock mockToken2 = new ERC20Mock();

        // Setup mock addresses array
        address[] memory supportedTokens = new address[](2);
        supportedTokens[0] = address(mockToken1);
        supportedTokens[1] = address(mockToken2);

        bytes32[] memory pythPriceIds = new bytes32[](0);

        address[] memory chainlinkFeeds = new address[](0);

        uint32 eid = 31337;

        vm.stopBroadcast();

        return NetworkConfig({
            layerZeroEndpoint: address(0), // Mock LZ endpoint
            supportedTokens: supportedTokens,
            isMock: true,
            wethAddress: address(0),
            pythPriceIds: pythPriceIds,
            chainlinkFeeds: chainlinkFeeds,
            currentEid: eid,
            pythAddress: 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729
        });
    }

    function getActiveNetworkConfig()
        external
        view
        returns (address, address[] memory, bool, bytes32[] memory, uint32, address, address[] memory)
    {
        return (
            activeNetworkConfig.layerZeroEndpoint,
            activeNetworkConfig.supportedTokens,
            activeNetworkConfig.isMock,
            activeNetworkConfig.pythPriceIds,
            activeNetworkConfig.currentEid,
            activeNetworkConfig.pythAddress,
            activeNetworkConfig.chainlinkFeeds
        );
    }
}
