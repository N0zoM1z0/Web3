// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CrossChainRouter} from "../src/LayerZero/CrossChainRouter.sol";
import {Lendtroller} from "../src/Lendtroller.sol";
import {LendtrollerInterface} from "../src/LendtrollerInterface.sol";
import {SimplePriceOracle} from "../src/SimplePriceOracle.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {WhitePaperInterestRateModel} from "../src/WhitePaperInterestRateModel.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LErc20} from "../src/LErc20.sol";
import {LErc20Immutable} from "../src/LErc20Immutable.sol";
import {LEther} from "../src/LEther.sol";
import {LToken} from "../src/LToken.sol";
import {UniswapAnchoredView} from "../src/Uniswap/UniswapAnchoredView.sol";
import {UniswapConfig} from "../src/Uniswap/UniswapConfig.sol";
import {EndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/EndpointV2.sol";
import {CrossChainRouterMock} from "../test/mocks/CrossChainRouterMock.sol";
import {CoreRouter} from "../src/LayerZero/CoreRouter.sol";
import {LendStorage} from "../src/LayerZero/LendStorage.sol";
import {PythOracle} from "../src/Pyth/PythOracle.sol";
import {ChainlinkOracle} from "../src/Chainlink/ChainlinkOracle.sol";
import {Lend} from "../src/Governance/Lend.sol";

/// @dev After running, to connect protocols, run ConnectProtocols.s.sol
contract Deploy is Script {
    HelperConfig public helperConfig;

    // Constants for interest rate model
    uint256 constant BASE_RATE = 0.1e18; // 10% base rate
    uint256 constant MULTIPLIER = 0.05e18; // 5% multiplier

    address[] lTokens;

    bool isMock;
    bytes32[] pythPriceIds;
    address[] chainlinkFeeds;
    // Get deployment configurations, but ignore the endpoint from config
    address configuredEndpoint;
    uint32 currentEid;

    address lendTokenAddress;

    address pythAddress;

    function run(address _endpoint)
        public
        returns (
            address priceOracleAddress,
            address lendtrollerAddress,
            address interestRateModelAddress,
            address[] memory lTokenAddresses,
            address payable crossChainRouterAddress,
            address payable coreRouterAddress,
            address lendStorageAddress,
            address layerZeroEndpoint,
            address[] memory supportedTokens
        )
    {
        helperConfig = new HelperConfig();

        (configuredEndpoint, supportedTokens, isMock, pythPriceIds, currentEid, pythAddress, chainlinkFeeds) =
            helperConfig.getActiveNetworkConfig();

        // Use the provided endpoint instead
        layerZeroEndpoint = _endpoint != address(0) ? _endpoint : configuredEndpoint;

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy appropriate price oracle based on network type
        address priceOracle;
        if (isMock) {
            // Use SimplePriceOracle for testnets
            priceOracle = address(new SimplePriceOracle());
        } else {
            if (currentEid == 40264 || currentEid == 30266 || currentEid == 40349 || currentEid == 40362) {
                // Use PythOracle for Merlin Testnet / Mainnet, Sonic Testnet, and HyperEVM Testnet
                priceOracle = address(new PythOracle(pythAddress));
            } else {
                priceOracle = address(new ChainlinkOracle());
            }
        }

        // Next: deploy a lendtroller
        lendtrollerAddress = address(new Lendtroller());
        Lendtroller(lendtrollerAddress)._setPriceOracle(PriceOracle(priceOracle));
        Lendtroller(lendtrollerAddress)._setCloseFactor(0.5e18);

        // Next, deploy lend token
        lendTokenAddress = address(new Lend(lendtrollerAddress));
        Lendtroller(lendtrollerAddress).setLendToken(lendTokenAddress);

        // Note: If we want to make upgradable, we can deploy a Unitroller contract
        // and delegate calls to the lendtroller implementation

        // Then: deploy the interest rate model
        interestRateModelAddress = address(new WhitePaperInterestRateModel(BASE_RATE, MULTIPLIER));

        // Deploy lTokens for each supported token
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == address(0)) {
                // Deploy LEther for ETH (ETH has 18 decimals)
                // initialExchangeRate = 0.02 * 10^(18 + 18 - 8) = 2 * 10^26
                uint256 initialExchangeRate = 2e26;
                lTokens.push(
                    address(
                        new LEther(
                            LendtrollerInterface(lendtrollerAddress),
                            WhitePaperInterestRateModel(interestRateModelAddress),
                            initialExchangeRate,
                            "Lending Ether",
                            "lETH",
                            8,
                            payable(msg.sender)
                        )
                    )
                );
            } else {
                // Get decimals of underlying token
                // Calculate initial exchange rate based on underlying decimals
                // Formula: 0.02 * 10^(18 + underlying_decimals - 8)
                // We multiply by 16, so 2 == 0.01 (remove 2 decimal places from 18)
                uint256 initialExchangeRate = 2 * 10 ** (16 + IERC20Metadata(supportedTokens[i]).decimals() - 8);

                lTokens.push(
                    address(
                        new LErc20Immutable(
                            supportedTokens[i],
                            LendtrollerInterface(lendtrollerAddress),
                            WhitePaperInterestRateModel(interestRateModelAddress),
                            initialExchangeRate,
                            string(abi.encodePacked("Lending ", IERC20Metadata(supportedTokens[i]).name())),
                            string(abi.encodePacked("l", IERC20Metadata(supportedTokens[i]).symbol())),
                            8, // 8 decimals for lTokens
                            payable(msg.sender)
                        )
                    )
                );
            }

            if (isMock) {
                SimplePriceOracle(priceOracle).setDirectPrice(supportedTokens[i], 1e18);
            } else {
                // Sonic, Hype etc.
                if (currentEid == 40264 || currentEid == 30266 || currentEid == 40349 || currentEid == 40362) {
                    // Add price feed IDs for each token
                    PythOracle(priceOracle).addLTokenToPriceId(lTokens[i], pythPriceIds[i]);
                } else {
                    // Add l token to testnet oracle
                    ChainlinkOracle(priceOracle).addLTokenToFeed(lTokens[i], chainlinkFeeds[i]);
                }
            }

            // Support market in lendtroller
            Lendtroller(lendtrollerAddress)._supportMarket(LToken(lTokens[i]));

            // Set collateral factor (75%)
            Lendtroller(lendtrollerAddress)._setCollateralFactor(LToken(lTokens[i]), 0.75e18);

            // Set liquidation incentive (8%)
            Lendtroller(lendtrollerAddress)._setLiquidationIncentive(1.08e18);
        }

        address payable router;

        lendStorageAddress = address(new LendStorage(lendtrollerAddress, priceOracle, currentEid));

        coreRouterAddress = payable(address(new CoreRouter(lendStorageAddress, priceOracle, lendtrollerAddress)));

        if (isMock) {
            // Deploy a mock CrossChainRouter contract
            router = payable(
                address(
                    new CrossChainRouterMock(
                        lendStorageAddress, address(priceOracle), lendtrollerAddress, coreRouterAddress, currentEid
                    )
                )
            );
        } else {
            // Deploy the real CrossChainRouter contract
            router = payable(
                address(
                    new CrossChainRouter(
                        layerZeroEndpoint,
                        msg.sender,
                        lendStorageAddress,
                        priceOracle,
                        lendtrollerAddress,
                        coreRouterAddress,
                        currentEid
                    )
                )
            );
        }

        CoreRouter(coreRouterAddress).setCrossChainRouter(address(router));

        // Set authorized contracts
        LendStorage(lendStorageAddress).setAuthorizedContract(coreRouterAddress, true);
        LendStorage(lendStorageAddress).setAuthorizedContract(router, true);

        // Set the LendStorage address in the lendtroller
        Lendtroller(lendtrollerAddress).setLendStorage(lendStorageAddress);

        // Add supported tokens and their corresponding lTokens
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            LendStorage(lendStorageAddress).addSupportedTokens(supportedTokens[i], lTokens[i]);
        }

        // After all markets have been supported and collateral factors set:
        for (uint256 i = 0; i < lTokens.length; i++) {
            LToken[] memory marketArray = new LToken[](1);
            marketArray[0] = LToken(lTokens[i]);

            uint256[] memory supplySpeeds = new uint256[](1);
            uint256[] memory borrowSpeeds = new uint256[](1);

            // For testing, set a small nonzero speed to confirm indexes advance:
            supplySpeeds[0] = 1e14; // Example: 0.0001 LEND per block to suppliers
            borrowSpeeds[0] = 1e14; // Example: 0.0001 LEND per block to borrowers

            Lendtroller(lendtrollerAddress)._setLendSpeeds(marketArray, supplySpeeds, borrowSpeeds);
        }

        vm.stopBroadcast();

        return (
            priceOracle,
            lendtrollerAddress,
            interestRateModelAddress,
            lTokens,
            router,
            coreRouterAddress,
            lendStorageAddress,
            layerZeroEndpoint,
            supportedTokens
        );
    }

    // Keep the original run() function for normal deployments
    function run()
        public
        returns (
            address priceOracleAddress,
            address lendtrollerAddress,
            address interestRateModelAddress,
            address[] memory lTokenAddresses,
            address payable routerAddress,
            address payable coreRouterAddress,
            address lendStorageAddress,
            address layerZeroEndpoint,
            address[] memory supportedTokens
        )
    {
        return run(address(0)); // Deploy will use config endpoint when 0 address is passed
    }
}
