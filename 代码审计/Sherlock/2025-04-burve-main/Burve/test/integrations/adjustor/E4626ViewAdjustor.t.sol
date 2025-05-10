// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {E4626ViewAdjustor} from "../../../src/integrations/adjustor/E4626ViewAdjustor.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {MockERC4626} from "../../mocks/MockERC4626.sol";

contract E4626ViewAdjustorTest is Test {
    E4626ViewAdjustor public adj;
    // asset and vault used with adjustor
    address asset;
    address vault;
    // asset and vault unrelated to adjustor
    address mysteryAsset;
    address mysteryVault;

    function setUp() public {
        ERC20 eth = new MockERC20("Ether", "ETH", 18);
        asset = address(eth);
        vault = address(
            new MockERC4626(eth, "Liquid staked Ether 2.0", "stETH")
        );

        ERC20 mystery = new MockERC20("unknown", "?", 18);
        mysteryAsset = address(mystery);
        mysteryVault = address(new MockERC4626(mystery, "Other vault", "oV"));

        adj = new E4626ViewAdjustor(asset);
    }

    // constructor tests

    function testConstructor() public view {
        assertEq(adj.assetToken(), asset);
    }

    // toNominal uint tests

    function testToNominalUint() public view {
        uint256 real = 10e18;
        uint256 shares = adj.toNominal(vault, real, true);
        assertEq(shares, IERC4626(vault).convertToShares(real));
    }

    function testToNominalUintCallsConvertToShares() public {
        uint256 real = 10e18;
        vm.expectCall(
            vault,
            abi.encodeCall(IERC4626(vault).convertToShares, (real))
        );
        adj.toNominal(vault, real, true);
    }

    function testRevertToNominalUintAssetMismatch() public {
        uint256 real = 10e18;
        vm.expectRevert(
            abi.encodeWithSelector(
                E4626ViewAdjustor.AssetMismatch.selector,
                mysteryAsset,
                asset
            )
        );
        adj.toNominal(mysteryVault, real, true);
    }

    // toNominal int tests

    function testToNominalIntPositive() public view {
        int256 real = 10e18;
        int256 shares = adj.toNominal(vault, real, true);
        assertEq(
            shares,
            int256(IERC4626(vault).convertToShares(uint256(real)))
        );
    }

    function testToNominalIntNegative() public view {
        int256 real = -10e18;
        int256 shares = adj.toNominal(vault, real, true);
        assertEq(
            shares,
            -int256(IERC4626(vault).convertToShares(uint256(-real)))
        );
    }

    function testToNominalIntPositiveCallsConvertToShares() public {
        int256 real = 10e18;
        vm.expectCall(
            vault,
            abi.encodeCall(IERC4626(vault).convertToShares, (uint256(real)))
        );
        adj.toNominal(vault, real, true);
    }

    function testToNominalIntNegativeCallsConvertToShares() public {
        int256 real = -10e18;
        vm.expectCall(
            vault,
            abi.encodeCall(IERC4626(vault).convertToShares, (uint256(-real)))
        );
        adj.toNominal(vault, real, true);
    }

    function testRevertToNominalIntAssetMismatch() public {
        int256 real = 10e18;
        vm.expectRevert(
            abi.encodeWithSelector(
                E4626ViewAdjustor.AssetMismatch.selector,
                mysteryAsset,
                asset
            )
        );
        adj.toNominal(mysteryVault, real, true);
    }

    // toReal uint tests

    function testToRealUint() public view {
        uint256 shares = 10e18;
        uint256 real = adj.toReal(vault, shares, true);
        assertEq(real, IERC4626(vault).convertToAssets(shares));
    }

    function testToRealUintCallsConvertToAssets() public {
        uint256 shares = 10e18;
        vm.expectCall(
            vault,
            abi.encodeCall(IERC4626(vault).convertToAssets, (shares))
        );
        adj.toReal(vault, shares, true);
    }

    function testRevertToRealUintAssetMismatch() public {
        uint256 shares = 10e18;
        vm.expectRevert(
            abi.encodeWithSelector(
                E4626ViewAdjustor.AssetMismatch.selector,
                mysteryAsset,
                asset
            )
        );
        adj.toReal(mysteryVault, shares, true);
    }

    // toReal int tests

    function testToRealIntPositive() public view {
        int256 shares = 10e18;
        int256 real = adj.toReal(vault, shares, true);
        assertEq(
            real,
            int256(IERC4626(vault).convertToAssets(uint256(shares)))
        );
    }

    function testToRealIntNegative() public view {
        int256 shares = -10e18;
        int256 real = adj.toReal(vault, shares, true);
        assertEq(
            real,
            -int256(IERC4626(vault).convertToAssets(uint256(-shares)))
        );
    }

    function testToRealIntPositiveCallsConvertToAssets() public {
        int256 shares = 10e18;
        vm.expectCall(
            vault,
            abi.encodeCall(IERC4626(vault).convertToAssets, (uint256(shares)))
        );
        adj.toReal(vault, shares, true);
    }

    function testToRealIntNegativeCallsConvertToAssets() public {
        int256 shares = -10e18;
        vm.expectCall(
            vault,
            abi.encodeCall(IERC4626(vault).convertToAssets, (uint256(-shares)))
        );
        adj.toReal(vault, shares, true);
    }

    function testRevertToRealIntAssetMismatch() public {
        int256 shares = 10e18;
        vm.expectRevert(
            abi.encodeWithSelector(
                E4626ViewAdjustor.AssetMismatch.selector,
                mysteryAsset,
                asset
            )
        );
        adj.toReal(mysteryVault, shares, true);
    }
}
