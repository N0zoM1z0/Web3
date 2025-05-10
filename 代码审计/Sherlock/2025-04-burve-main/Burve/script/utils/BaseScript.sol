// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Vm, VmSafe} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {MockERC20} from "../../test/mocks/MockERC20.sol";
import {MockERC4626} from "../../test/mocks/MockERC4626.sol";
import {SimplexDiamond as BurveDiamond} from "../../src/multi/Diamond.sol";
import {ValueFacet} from "../../src/multi/facets/ValueFacet.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {LockFacet} from "../../src/multi/facets/LockFacet.sol";
import {VaultFacet} from "../../src/multi/facets/VaultFacet.sol";
import {ValueTokenFacet} from "../../src/multi/facets/ValueTokenFacet.sol";

abstract contract BaseScript is Script {
    // Core contracts
    BurveDiamond public diamond;
    ValueFacet public valueFacet;
    SwapFacet public swapFacet;
    SimplexFacet public simplexFacet;
    LockFacet public lockFacet;
    VaultFacet public vaultFacet;
    ValueTokenFacet public valueTokenFacet;

    // Dynamic arrays for tokens and vaults
    MockERC20[] public tokens;
    MockERC4626[] public vaults;

    function setUp() public virtual {
        // Read deployment.json
        string memory json = vm.readFile("script/deployment.json");

        // Parse diamond address with better error handling
        string memory diamondStr = vm.parseJsonString(json, ".diamond");
        require(
            bytes(diamondStr).length > 0,
            "Diamond address not found in JSON"
        );
        address diamondAddr = vm.parseAddress(diamondStr);

        // Initialize core contracts
        diamond = BurveDiamond(payable(diamondAddr));
        valueFacet = ValueFacet(diamondAddr);
        swapFacet = SwapFacet(diamondAddr);
        simplexFacet = SimplexFacet(diamondAddr);
        lockFacet = LockFacet(diamondAddr);
        vaultFacet = VaultFacet(diamondAddr);
        valueTokenFacet = ValueTokenFacet(diamondAddr);

        // Parse tokens array with better error handling
        string[] memory tokenAddrs = vm.parseJsonStringArray(json, ".tokens");
        require(tokenAddrs.length > 0, "No tokens found in JSON");

        // Initialize tokens
        for (uint256 i = 0; i < tokenAddrs.length; i++) {
            require(
                bytes(tokenAddrs[i]).length > 0,
                "Empty token address found"
            );
            tokens.push(MockERC20(vm.parseAddress(tokenAddrs[i])));
        }

        // Parse vaults array with better error handling
        string[] memory vaultAddrs = vm.parseJsonStringArray(json, ".vaults");
        require(vaultAddrs.length > 0, "No vaults found in JSON");

        // Initialize vaults
        for (uint256 i = 0; i < vaultAddrs.length; i++) {
            require(
                bytes(vaultAddrs[i]).length > 0,
                "Empty vault address found"
            );
            vaults.push(MockERC4626(vm.parseAddress(vaultAddrs[i])));
        }

        // Log setup
        console2.log("Setup complete with:");
        console2.log("Diamond:", diamondAddr);
        console2.log("Tokens:", tokens.length);
        console2.log("Vaults:", vaults.length);
    }

    // Helper function to get the appropriate private key
    function _getPrivateKey() internal view returns (uint256) {
        return vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    // Helper function to get the appropriate sender address
    function _getSender() internal view returns (address) {
        return vm.addr(_getPrivateKey());
    }

    // Helper function to mint tokens and approve spending
    function _mintAndApprove(
        address token,
        address to,
        uint256 amount
    ) internal {
        MockERC20(token).mint(to, amount);
        MockERC20(token).approve(address(diamond), amount);
    }

    // Helper to get token address by index
    function _getTokenByIndex(uint8 index) internal view returns (address) {
        require(index < tokens.length, "Invalid token index");
        return address(tokens[index]);
    }

    // Helper to get vault address by index
    function _getVaultByIndex(uint8 index) internal view returns (address) {
        require(index < vaults.length, "Invalid vault index");
        return address(vaults[index]);
    }

    // Helper to get number of tokens
    function _getNumTokens() internal view returns (uint256) {
        return tokens.length;
    }

    // Helper to mint tokens based on closure ID
    function _mintTokensForClosure(
        uint16 closureId,
        address to,
        uint256 amount
    ) internal {
        for (uint8 i = 0; i < tokens.length; i++) {
            if ((1 << i) & closureId > 0) {
                _mintAndApprove(address(tokens[i]), to, amount);
            }
        }
    }
}
