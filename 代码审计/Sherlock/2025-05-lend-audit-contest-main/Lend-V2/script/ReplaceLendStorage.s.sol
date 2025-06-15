// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LendStorage} from "../src/LayerZero/LendStorage.sol";
import {CoreRouter} from "../src/LayerZero/CoreRouter.sol";
import {CrossChainRouter} from "../src/LayerZero/CrossChainRouter.sol";

/**
 * @dev Redeploys a LendStorage, CoreRouter and CrossChainRouter instance, as they're inter-dependent.
 * @dev Need to call SetPeer after deploying for multiple chains to connect them.
 */
contract ReplaceLendStorage is Script {
    address lendtroller = 0x00479E804dDAb9D5542e18F1DA2B369e53112B4A;
    address priceOracle = 0xDF213b7171e27947a1D0265b92E0129E1A671455;

    address[] supportedTokens = [
        0xB7bA3c24Fb455ed3a37c726512159F854A3C2158, // DAI
        0x90eacA77935C287674a5fd1E46F5654B8945cBB0, // USDC
        0xEbCAC186e57691086E12ef49A5DfD7d18fD5bdDC, // USDT
        0x71fe94dFBe7437942C81dfa403F7012f3D45cf4a, // WETH
        0x0dF0535fb274d995e17a0ebBDa09d49884FA205f // WBTC
    ];

    address[] lTokens = [
        0x62E78F69D994e12D277E19B7266456265c3Fa426,
        0xcdD1619B28FFD61F7d96fc6422e8731bd4824DED,
        0xe48259E5c0587bB389bA50FB55d73BA4258Bb0be,
        0x4F298691843da212Aa9633b98FA002a55De4C44a,
        0xC50F0fcF37A6884fbc93FbcCf08Ad2aBeE6903Ff
    ];

    // Set by helper config
    address layerZeroEndpoint;
    uint32 currentEid;

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        (layerZeroEndpoint,,,, currentEid,,) = helperConfig.getActiveNetworkConfig();

        vm.startBroadcast();
        LendStorage lendStorage = new LendStorage(lendtroller, priceOracle, currentEid);

        CoreRouter coreRouter = new CoreRouter(address(lendStorage), priceOracle, lendtroller);

        // Deploy the real CrossChainRouter contract
        CrossChainRouter crossChainRouter = new CrossChainRouter(
            layerZeroEndpoint,
            msg.sender,
            address(lendStorage),
            lendtroller,
            priceOracle,
            payable(address(coreRouter)),
            currentEid
        );

        coreRouter.setCrossChainRouter(address(crossChainRouter));

        // Set authorized contracts
        lendStorage.setAuthorizedContract(address(coreRouter), true);
        lendStorage.setAuthorizedContract(address(crossChainRouter), true);

        // Add supported tokens and their corresponding lTokens
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            lendStorage.addSupportedTokens(supportedTokens[i], lTokens[i]);
        }

        vm.stopBroadcast();
    }
}
