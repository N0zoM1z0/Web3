// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {IDiamond} from "Commons/Diamond/interfaces/IDiamond.sol";
import {DiamondCutFacet} from "Commons/Diamond/facets/DiamondCutFacet.sol";
import {InitLib, BurveFacets} from "../src/multi/InitLib.sol";
import {SimplexDiamond as BurveDiamond} from "../src/multi/Diamond.sol";
import {SimplexFacet} from "../src/multi/facets/SimplexFacet.sol";
import {LockFacet} from "../src/multi/facets/LockFacet.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockERC4626} from "../test/mocks/MockERC4626.sol";
import {SwapFacet} from "../src/multi/facets/SwapFacet.sol";
import {ValueFacet} from "../src/multi/facets/ValueFacet.sol";
import {ValueTokenFacet} from "../src/multi/facets/ValueTokenFacet.sol";
import {VaultType} from "../src/multi/vertex/VaultProxy.sol";
import {IAdjustor} from "../src/integrations/adjustor/IAdjustor.sol";
import {NullAdjustor} from "../src/integrations/adjustor/NullAdjustor.sol";

contract DeployBurve is Script {
    /* Deployer */
    address deployerAddr;

    uint256 constant INITIAL_MINT_AMOUNT = 1e30;
    uint128 constant INITIAL_VALUE = 1_000_000e18;

    /* Diamond */
    address public diamond;
    ValueFacet public valueFacet;
    ValueTokenFacet public valueTokenFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    LockFacet public lockFacet;

    /* Test Tokens */
    address[] public tokens;
    MockERC4626[] public vaults;

    function run() public {
        deployerAddr = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        BurveFacets memory facets = InitLib.deployFacets();
        diamond = address(new BurveDiamond(facets, "ValueToken", "BVT"));
        console2.log("Burve deployed at:", diamond);

        valueFacet = ValueFacet(diamond);
        valueTokenFacet = ValueTokenFacet(diamond);
        simplexFacet = SimplexFacet(diamond);
        swapFacet = SwapFacet(diamond);
        lockFacet = LockFacet(diamond);

        // Deploy tokens and install them as vertices
        _newTokens(3);

        IAdjustor nAdj = new NullAdjustor();
        simplexFacet.setAdjustor(address(nAdj));

        // Initialize a closure with both tokens
        _initializeClosure(3);
        _initializeClosure(4);
        _initializeClosure(5);
        _initializeClosure(6);
        _initializeClosure(7);

        vm.stopBroadcast();

        // Log deployed addresses
        console2.log("Diamond deployed at:", address(diamond));
        for (uint256 i = 0; i < tokens.length; i++) {
            console2.log(
                string.concat("Token", Strings.toString(i), " deployed at:"),
                tokens[i]
            );
            console2.log(
                string.concat("Vault", Strings.toString(i), " deployed at:"),
                address(vaults[i])
            );
        }

        // Write addresses to JSON file
        string memory json = _generateDeploymentJson();
        vm.writeJson(json, "script/deployment.json");
    }

    function _generateDeploymentJson() internal view returns (string memory) {
        string memory json = "{";
        json = string.concat(
            json,
            '"diamond": "',
            vm.toString(address(diamond)),
            '",'
        );

        // Add tokens and vaults arrays
        json = string.concat(json, '"tokens": [');
        for (uint256 i = 0; i < tokens.length; i++) {
            json = string.concat(json, '"', vm.toString(tokens[i]), '"');
            if (i < tokens.length - 1) json = string.concat(json, ",");
        }
        json = string.concat(json, "],");

        json = string.concat(json, '"vaults": [');
        for (uint256 i = 0; i < vaults.length; i++) {
            json = string.concat(
                json,
                '"',
                vm.toString(address(vaults[i])),
                '"'
            );
            if (i < vaults.length - 1) json = string.concat(json, ",");
        }
        json = string.concat(json, "]");

        json = string.concat(json, "}");
        return json;
    }

    /// Deploy tokens and install them as vertices in the diamond with an edge.
    function _newTokens(uint8 numTokens) internal {
        // Setup test tokens
        for (uint8 i = 0; i < numTokens; ++i) {
            string memory idx = Strings.toString(i);
            tokens.push(
                address(
                    new MockERC20(
                        string.concat("Test Token ", idx),
                        string.concat("TEST", idx),
                        18
                    )
                )
            );
        }

        // Sort the entire tokens array
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = i + 1; j < tokens.length; j++) {
                if (tokens[i] > tokens[j]) {
                    (tokens[i], tokens[j]) = (tokens[j], tokens[i]);
                }
            }
        }

        // Add vaults and vertices
        for (uint256 i = 0; i < tokens.length; ++i) {
            string memory idx = Strings.toString(i);
            // Have to setup vaults here in case the token order changed.
            vaults.push(
                new MockERC4626(
                    MockERC20(tokens[i]),
                    string.concat("Vault ", idx),
                    string.concat("V", idx)
                )
            );
            simplexFacet.addVertex(
                tokens[i],
                address(vaults[i]),
                VaultType.E4626
            );
        }
    }

    /// Initialize a zero fee closure with the initial value amount.
    function _initializeClosure(uint16 cid) internal {
        // Mint ourselves enough to fund the initial target of the pool.
        for (uint256 i = 0; i < tokens.length; ++i) {
            if ((1 << i) & cid > 0) {
                MockERC20(tokens[i]).mint(deployerAddr, INITIAL_VALUE);
                MockERC20(tokens[i]).approve(
                    address(diamond),
                    type(uint256).max
                );
            }
        }
        simplexFacet.addClosure(cid, INITIAL_VALUE, 0, 0);
    }
}
