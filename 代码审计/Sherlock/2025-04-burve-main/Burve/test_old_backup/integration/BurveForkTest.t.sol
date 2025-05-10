// SPDX-License-Identifier: BUSL-1.1
// Copyright 2024 Itos Inc.
pragma solidity ^0.8.27;

import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ForkableTest} from "Commons/Test/ForkableTest.sol";
import {Auto165} from "Commons/ERC/Auto165.sol";
import {ClosureId, newClosureId} from "../../src/multi/Closure.sol";

import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {EdgeFacet} from "../../src/multi/facets/EdgeFacet.sol";
import {LiqFacet} from "../../src/multi/facets/LiqFacet.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {ViewFacet} from "../../src/multi/facets/ViewFacet.sol";
import {BurveFacets, InitLib} from "../../src/InitLib.sol";
import {BurveMultiLPToken} from "../../src/multi/LPToken.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {VaultType} from "../../src/multi/VaultProxy.sol";

/// @title BurveForkTest - base contract for fork testing on Burve
/// @notice sets up the e2e contracts for fork testing of Burve
/// includes diamond creation, facet setup, and token/vault setup
contract BurveForkTest is ForkableTest, Auto165 {
    uint128 constant MIN_SQRT_PRICE_X96 = uint128(1 << 96) / 1000;
    uint128 constant MAX_SQRT_PRICE_X96 = uint128(1000 << 96);
    // Core contracts
    SimplexDiamond public diamond;
    LiqFacet public liqFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    ViewFacet public viewFacet;
    EdgeFacet public edgeFacet;

    // Real tokens
    IERC20 public honey;
    IERC20 public dai;
    IERC20 public mim;
    IERC20 public mead;

    // Mock vaults
    MockERC4626 public mockHoneyVault;
    MockERC4626 public mockDaiVault;
    MockERC4626 public mockMimVault;
    MockERC4626 public mockMeadVault;

    // Constants
    uint256 public constant INITIAL_MINT_AMOUNT = 1000000e18;
    uint256 public constant INITIAL_LIQUIDITY_AMOUNT = 5e18;
    uint256 public constant INITIAL_DEPOSIT_AMOUNT = 5e18;

    function forkSetup() internal virtual override {
        // Initialize token interfaces from real addresses
        honey = IERC20(vm.envAddress("HONEY_ADDRESS"));
        dai = IERC20(vm.envAddress("DAI_ADDRESS"));
        mim = IERC20(vm.envAddress("MIM_ADDRESS"));
        mead = IERC20(vm.envAddress("MEAD_ADDRESS"));

        // Initialize existing vault interfaces
        mockHoneyVault = MockERC4626(vm.envAddress("HONEY_VAULT_ADDRESS"));
        mockDaiVault = MockERC4626(vm.envAddress("DAI_VAULT_ADDRESS"));
        mockMimVault = MockERC4626(vm.envAddress("MIM_VAULT_ADDRESS"));
        mockMeadVault = MockERC4626(vm.envAddress("MEAD_VAULT_ADDRESS"));

        // Initialize existing diamond and facets
        diamond = SimplexDiamond(payable(vm.envAddress("DIAMOND_ADDRESS")));
        liqFacet = LiqFacet(address(diamond));
        simplexFacet = SimplexFacet(address(diamond));
        swapFacet = SwapFacet(address(diamond));
        viewFacet = ViewFacet(address(diamond));
        edgeFacet = EdgeFacet(address(diamond));
    }

    function deploySetup() internal pure override {}

    function postSetup() internal override {
        // Label addresses for better trace output
        vm.label(address(honey), "HONEY");
        vm.label(address(dai), "DAI");
        vm.label(address(mim), "MIM");
        vm.label(address(mead), "MEAD");
        vm.label(address(mockHoneyVault), "vHONEY");
        vm.label(address(mockDaiVault), "vDAI");
        vm.label(address(mockMimVault), "vMIM");
        vm.label(address(mockMeadVault), "vMEAD");
        vm.label(address(diamond), "BurveDiamond");

        // Fund test contract with tokens
        deal(address(honey), address(this), INITIAL_MINT_AMOUNT);
        deal(address(dai), address(this), INITIAL_MINT_AMOUNT);
        deal(address(mim), address(this), INITIAL_MINT_AMOUNT);
        deal(address(mead), address(this), INITIAL_MINT_AMOUNT);

        // Approve tokens for diamond
        honey.approve(address(diamond), type(uint256).max);
        dai.approve(address(diamond), type(uint256).max);
        mim.approve(address(diamond), type(uint256).max);
        mead.approve(address(diamond), type(uint256).max);

        // Start acting as the deployer for admin operations
        address deployer = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        vm.startPrank(deployer);

        // Set up the edge between HONEY and DAI
        edgeFacet.setEdge(
            address(honey),
            address(dai),
            101, // amplitude
            -46063, // lowTick
            46063 // highTick
        );

        // Set up the edge fee
        edgeFacet.setEdgeFee(
            address(honey),
            address(dai),
            3000, // 0.3% fee
            200 // 20% of fee goes to protocol
        );

        vm.stopPrank();
    }

    function testAddLiquidityMimHoney() public forkOnly {
        // Start acting as the deployer
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);

        // Fund the deployer with tokens
        deal(address(mim), deployer, INITIAL_MINT_AMOUNT);
        deal(address(honey), deployer, INITIAL_MINT_AMOUNT);

        // Create LP token instance for MIM-HONEY pair (closure ID 5)
        BurveMultiLPToken lpToken = BurveMultiLPToken(
            0x128b297B0331729b85783441a2694DADDBE4a05f
        );

        // Print initial balances
        console.log("Initial MIM balance:", mim.balanceOf(deployer));
        console.log("Initial HONEY balance:", honey.balanceOf(deployer));
        console.log("Initial LP token balance:", lpToken.balanceOf(deployer));

        // Prepare amounts for liquidity provision
        uint8 numVertices = simplexFacet.numVertices();
        uint128[] memory amounts = new uint128[](numVertices);
        amounts[0] = uint128(INITIAL_DEPOSIT_AMOUNT); // HONEY amount
        amounts[2] = uint128(INITIAL_DEPOSIT_AMOUNT); // MIM amount
        // Other positions are 0 by default

        // Approve tokens for LP token
        mim.approve(address(lpToken), type(uint256).max);
        honey.approve(address(lpToken), type(uint256).max);

        // Mint LP tokens directly
        uint256 shares = lpToken.mint(deployer, amounts);

        // Print final balances
        console.log("Shares received:", shares);
        console.log("Final MIM balance:", mim.balanceOf(deployer));
        console.log("Final HONEY balance:", honey.balanceOf(deployer));
        console.log("Final LP token balance:", lpToken.balanceOf(deployer));

        // Verify we received shares
        assertGt(shares, 0, "Should have received LP shares");
        assertEq(
            lpToken.balanceOf(deployer),
            shares,
            "LP token balance should match shares"
        );

        vm.stopPrank();
    }

    function testAddLiquidityHoneyDai() public forkOnly {
        // Start acting as the deployer
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);

        // Fund the deployer with tokens
        deal(address(honey), deployer, INITIAL_MINT_AMOUNT);
        deal(address(dai), deployer, INITIAL_MINT_AMOUNT);

        // Create LP token instance for HONEY-DAI pair (closure ID 3)
        BurveMultiLPToken lpToken = BurveMultiLPToken(
            0x8578791fd57E4d6CE2D3AA65374467c4d21f06B9
        );

        // Print initial balances
        console.log("Initial HONEY balance:", honey.balanceOf(deployer));
        console.log("Initial DAI balance:", dai.balanceOf(deployer));
        console.log("Initial LP token balance:", lpToken.balanceOf(deployer));

        // Prepare amounts for liquidity provision
        uint8 numVertices = simplexFacet.numVertices();
        uint128[] memory amounts = new uint128[](numVertices);
        amounts[0] = uint128(INITIAL_DEPOSIT_AMOUNT); // HONEY amount
        amounts[1] = uint128(INITIAL_DEPOSIT_AMOUNT); // DAI amount
        // Other positions are 0 by default

        // Approve tokens for LP token
        honey.approve(address(lpToken), type(uint256).max);
        dai.approve(address(lpToken), type(uint256).max);

        // Mint LP tokens directly
        uint256 shares = lpToken.mint(deployer, amounts);

        // Print final balances
        console.log("Shares received:", shares);
        console.log("Final HONEY balance:", honey.balanceOf(deployer));
        console.log("Final DAI balance:", dai.balanceOf(deployer));
        console.log("Final LP token balance:", lpToken.balanceOf(deployer));

        // Verify we received shares
        assertGt(shares, 0, "Should have received LP shares");
        assertEq(
            lpToken.balanceOf(deployer),
            shares,
            "LP token balance should match shares"
        );

        vm.stopPrank();
    }

    function testSwapHoneyToDai() public forkOnly {
        // Start acting as the deployer
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);

        // Fund the deployer with HONEY
        uint256 swapAmount = 1e18; // Swap 1 HONEY
        deal(address(honey), deployer, swapAmount);

        // Print initial balances
        console.log("Initial HONEY balance:", honey.balanceOf(deployer));
        console.log("Initial DAI balance:", dai.balanceOf(deployer));

        // Approve HONEY for the diamond
        honey.approve(address(diamond), type(uint256).max);

        // Get quote for swap
        (, uint256 expectedDaiAmount, uint160 sqrtPriceAfter) = swapFacet
            .simSwap(
                address(honey), // token in
                address(dai), // token out
                int256(swapAmount), // amount in
                uint160(MIN_SQRT_PRICE_X96) // min sqrt price
            );

        console.log("Expected DAI output:", expectedDaiAmount);
        console.log("Sqrt price after:", sqrtPriceAfter);

        // Perform the swap
        (uint256 honeyIn, uint256 daiOut) = swapFacet.swap(
            deployer, // recipient
            address(honey), // token in
            address(dai), // token out
            int256(swapAmount), // amount in
            uint160(MIN_SQRT_PRICE_X96) // min sqrt price
        );

        // Print final balances
        console.log("HONEY", address(honey));
        console.log("DAI", address(dai));
        console.log("MIN_SQRT_PRICE_X96", uint160(MIN_SQRT_PRICE_X96));
        console.log("Final HONEY balance:", honey.balanceOf(deployer));
        console.log("Final DAI balance:", dai.balanceOf(deployer));
        console.log("HONEY in:", honeyIn);
        console.log("DAI out:", daiOut);

        // Verify the swap was successful
        assertGt(daiOut, 0, "Should have received DAI");
        assertEq(honey.balanceOf(deployer), 0, "Should have spent all HONEY");
        assertApproxEqRel(
            daiOut,
            expectedDaiAmount,
            0.001e18, // 0.1% tolerance
            "Received amount should be close to simulated amount"
        );

        vm.stopPrank();
    }
}
