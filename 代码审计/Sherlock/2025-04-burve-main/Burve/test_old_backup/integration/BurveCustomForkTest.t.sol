// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ForkableTest} from "Commons/Test/ForkableTest.sol";
import {Auto165} from "Commons/ERC/Auto165.sol";
import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {EdgeFacet} from "../../src/multi/facets/EdgeFacet.sol";
import {LiqFacet} from "../../src/multi/facets/LiqFacet.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {ViewFacet} from "../../src/multi/facets/ViewFacet.sol";
import {BurveFacets, InitLib} from "../../src/InitLib.sol";
import {BurveMultiLPToken} from "../../src/multi/LPToken.sol";
import {VaultType} from "../../src/multi/VaultProxy.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {ClosureId} from "../../src/multi/Closure.sol";
import {TokenRegLib} from "../../src/multi/Token.sol";

/// @title BurveCustomForkTest - fork test for custom token setup
/// @notice Sets up Burve with HONEY, USDe and rUSD using Dolomite vaults
contract BurveCustomForkTest is ForkableTest, Auto165 {
    // Core contracts
    SimplexDiamond public diamond;
    LiqFacet public liqFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    ViewFacet public viewFacet;

    // Tokens
    // IERC20 public usdc;  // Commented out for now
    IERC20 public honey;
    IERC20 public usde;
    IERC20 public rUsd;

    // Dolomite vaults
    // IERC4626 public usdcVault;  // Commented out for now
    IERC4626 public honeyVault;
    IERC4626 public usdeVault;
    IERC4626 public rUsdVault;

    uint128 constant MIN_SQRT_PRICE_X96 = uint128(1 << 96) / 1000;
    uint128 constant MAX_SQRT_PRICE_X96 = uint128(1000 << 96);

    // LP tokens
    mapping(uint16 => BurveMultiLPToken) public lpTokens;

    // Constants
    uint256 public constant INITIAL_MINT_AMOUNT = 1000000e18;
    uint256 public constant INITIAL_LIQUIDITY_AMOUNT = 5e18;
    uint256 public constant INITIAL_DEPOSIT_AMOUNT = 5e18;

    function forkSetup() internal virtual override {
        // Initialize token interfaces from addresses
        // usdc = IERC20(vm.envAddress("USDC"));  // Commented out for now
        honey = IERC20(vm.envAddress("HONEY"));
        usde = IERC20(vm.envAddress("USDe"));
        rUsd = IERC20(vm.envAddress("rUSD"));

        // Initialize Dolomite vault interfaces
        // usdcVault = IERC4626(vm.envAddress("DOLOMITE_USDC_VAULT"));  // Commented out for now
        honeyVault = IERC4626(vm.envAddress("DOLOMITE_HONEY_VAULT"));
        usdeVault = IERC4626(vm.envAddress("DOLOMITE_USDe_VAULT"));
        rUsdVault = IERC4626(vm.envAddress("DOLOMITE_rUSD_VAULT"));

        // Deploy the diamond and facets
        BurveFacets memory burveFacets = InitLib.deployFacets();
        diamond = new SimplexDiamond(burveFacets);

        // Cast the diamond address to the facet interfaces
        liqFacet = LiqFacet(address(diamond));
        simplexFacet = SimplexFacet(address(diamond));
        swapFacet = SwapFacet(address(diamond));
        viewFacet = ViewFacet(address(diamond));

        // Set up the pool configuration similar to Env.s.sol
        simplexFacet.setName("stables");
        simplexFacet.setDefaultEdge(101, -46063, 46063, 3000, 200);

        // Add vertices for each token-vault pair
        // simplexFacet.addVertex(address(usdc), address(usdcVault), VaultType.E4626);  // Commented out for now
        simplexFacet.addVertex(
            address(honey),
            address(honeyVault),
            VaultType.E4626
        );
        simplexFacet.addVertex(
            address(usde),
            address(usdeVault),
            VaultType.E4626
        );
        simplexFacet.addVertex(
            address(rUsd),
            address(rUsdVault),
            VaultType.E4626
        );

        // Setup edges between all pairs
        _setupEdges();

        // Setup closures and LP tokens
        _setupClosuresAndLPTokens();
    }

    function deploySetup() internal pure override {}

    function postSetup() internal override {
        // Label addresses for better trace output
        // vm.label(address(usdc), "USDC");  // Commented out for now
        vm.label(address(honey), "HONEY");
        vm.label(address(usde), "USDe");
        vm.label(address(rUsd), "rUSD");
        // vm.label(address(usdcVault), "vUSDC");  // Commented out for now
        vm.label(address(honeyVault), "vHONEY");
        vm.label(address(usdeVault), "vUSDe");
        vm.label(address(rUsdVault), "vrUSD");
        vm.label(address(diamond), "BurveDiamond");

        // Fund test contract with tokens
        // deal(address(usdc), address(this), INITIAL_MINT_AMOUNT);  // Commented out for now
        deal(address(honey), address(this), INITIAL_MINT_AMOUNT);
        deal(address(usde), address(this), INITIAL_MINT_AMOUNT);
        deal(address(rUsd), address(this), INITIAL_MINT_AMOUNT);

        // Approve tokens for diamond
        // usdc.approve(address(diamond), type(uint256).max);  // Commented out for now
        honey.approve(address(diamond), type(uint256).max);
        usde.approve(address(diamond), type(uint256).max);
        rUsd.approve(address(diamond), type(uint256).max);
    }

    function _setupEdges() internal {
        address[] memory tokens = new address[](3);
        tokens[0] = address(honey);
        tokens[1] = address(usde);
        tokens[2] = address(rUsd);

        // Create edges between all token pairs
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = i + 1; j < tokens.length; j++) {
                EdgeFacet(address(diamond)).setEdge(
                    tokens[i],
                    tokens[j],
                    101, // amplitude
                    -46063, // lowTick
                    46063 // highTick
                );
            }
        }
    }

    function _setupClosuresAndLPTokens() internal {
        address[] memory tokens = new address[](3);
        tokens[0] = address(honey);
        tokens[1] = address(usde);
        tokens[2] = address(rUsd);

        // Generate all possible 2-token combinations
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = i + 1; j < tokens.length; j++) {
                address[] memory pair = new address[](2);
                pair[0] = tokens[i];
                pair[1] = tokens[j];

                uint16 pairId = ClosureId.unwrap(viewFacet.getClosureId(pair));
                lpTokens[pairId] = new BurveMultiLPToken(
                    ClosureId.wrap(pairId),
                    address(diamond)
                );
            }
        }

        // Generate 3-token combination
        address[] memory triple = new address[](3);
        triple[0] = tokens[0];
        triple[1] = tokens[1];
        triple[2] = tokens[2];

        uint16 tripleId = ClosureId.unwrap(viewFacet.getClosureId(triple));
        lpTokens[tripleId] = new BurveMultiLPToken(
            ClosureId.wrap(tripleId),
            address(diamond)
        );
    }

    function testAddLiquidityHoneyUsde() public forkOnly {
        // Start acting as the deployer
        address deployer = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        vm.startPrank(deployer);

        // Fund the deployer with tokens
        deal(address(honey), deployer, INITIAL_MINT_AMOUNT);
        deal(address(usde), deployer, INITIAL_MINT_AMOUNT);

        honey.approve(address(diamond), type(uint256).max);
        usde.approve(address(diamond), type(uint256).max);
        rUsd.approve(address(diamond), type(uint256).max);

        // Get the existing LP token instance for HONEY-USDe pair
        address[] memory tokens = new address[](2);
        tokens[0] = address(honey);
        tokens[1] = address(usde);
        uint16 pairId = ClosureId.unwrap(viewFacet.getClosureId(tokens));
        BurveMultiLPToken lpToken = lpTokens[pairId];

        // Print initial balances
        console.log("Initial HONEY balance:", honey.balanceOf(deployer));
        console.log("Initial USDe balance:", usde.balanceOf(deployer));
        console.log("Initial LP token balance:", lpToken.balanceOf(deployer));

        // Prepare amounts for liquidity provision
        uint8 numVertices = TokenRegLib.numVertices();
        uint128[] memory depositAmounts = new uint128[](numVertices);
        depositAmounts[0] = uint128(INITIAL_DEPOSIT_AMOUNT); // HONEY amount
        depositAmounts[1] = uint128(INITIAL_DEPOSIT_AMOUNT); // USDe amount
        depositAmounts[2] = 0; // rUSD amount

        // Add liquidity
        uint256 shares = liqFacet.addLiq(deployer, pairId, depositAmounts);

        // Print final balances
        console.log("Shares received:", shares);
        console.log("Final HONEY balance:", honey.balanceOf(deployer));
        console.log("Final USDe balance:", usde.balanceOf(deployer));
        console.log("Final LP token balance:", lpToken.balanceOf(deployer));

        // Verify we received shares
        assertGt(shares, 0, "Should have received LP shares");
        assertEq(
            lpToken.balanceOf(deployer),
            shares,
            "LP token balance should match shares"
        );

        vm.stopPrank();

        // Setup trader account for swap testing
        address trader = makeAddr("trader");
        uint256 tradeAmount = 1e18; // 1 token

        // Fund trader with HONEY
        deal(address(honey), trader, tradeAmount * 2);

        vm.startPrank(trader);
        // Record initial balances
        uint256 initialHoneyBalance = honey.balanceOf(trader);
        uint256 initialUsdeBalance = usde.balanceOf(trader);

        // Approve tokens for trading
        honey.approve(address(diamond), type(uint256).max);
        usde.approve(address(diamond), type(uint256).max);

        // Perform HONEY -> USDe swap
        (uint256 inAmount, uint256 outAmount) = swapFacet.swap(
            trader, // recipient - who receives the output tokens
            address(honey), // inToken - token being swapped from
            address(usde), // outToken - token being swapped to
            int256(tradeAmount), // amountSpecified - positive for exact input, negative for exact output
            MAX_SQRT_PRICE_X96 - 1 // sqrtPriceLimitX96 - maximum price limit for the swap
        );

        // Verify swap results
        assertGt(outAmount, 0, "Should have received USDe tokens");
        assertEq(
            honey.balanceOf(trader),
            initialHoneyBalance - inAmount,
            "HONEY balance should be reduced by trade amount"
        );
        assertEq(
            usde.balanceOf(trader),
            initialUsdeBalance + outAmount,
            "USDe balance should be increased by swap output"
        );

        // Perform reverse swap USDe -> HONEY
        (uint256 reverseInAmount, uint256 reverseOutAmount) = swapFacet.swap(
            trader, // recipient - who receives the output tokens
            address(usde), // inToken - token being swapped from
            address(honey), // outToken - token being swapped to
            int256(outAmount), // amountSpecified - positive for exact input, negative for exact output
            MIN_SQRT_PRICE_X96 + 1 // sqrtPriceLimitX96 - minimum price limit for the swap
        );

        // Verify reverse swap results
        assertGt(reverseOutAmount, 0, "Should have received HONEY tokens");
        assertLt(
            reverseOutAmount,
            tradeAmount,
            "Should receive less HONEY than original trade due to fees"
        );

        vm.stopPrank();
    }

    function testAddLiquidityUsdeRusd() public forkOnly {
        // Start acting as the deployer
        address deployer = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        vm.startPrank(deployer);

        // Fund the deployer with tokens
        deal(address(usde), deployer, INITIAL_MINT_AMOUNT);
        deal(address(rUsd), deployer, INITIAL_MINT_AMOUNT);

        // Get the existing LP token instance for USDe-rUSD pair
        address[] memory tokens = new address[](2);
        tokens[0] = address(usde);
        tokens[1] = address(rUsd);
        uint16 pairId = ClosureId.unwrap(viewFacet.getClosureId(tokens));
        BurveMultiLPToken lpToken = lpTokens[pairId];

        // Print initial balances
        console.log("Initial USDe balance:", usde.balanceOf(deployer));
        console.log("Initial rUSD balance:", rUsd.balanceOf(deployer));
        console.log("Initial LP token balance:", lpToken.balanceOf(deployer));

        // Prepare amounts for liquidity provision
        uint8 numVertices = TokenRegLib.numVertices();
        uint128[] memory depositAmounts = new uint128[](numVertices);
        depositAmounts[0] = 0; // HONEY amount
        depositAmounts[1] = uint128(INITIAL_DEPOSIT_AMOUNT); // USDe amount
        depositAmounts[2] = uint128(INITIAL_DEPOSIT_AMOUNT); // rUSD amount

        // Add liquidity
        uint256 shares = liqFacet.addLiq(deployer, pairId, depositAmounts);

        // Print final balances
        console.log("Shares received:", shares);
        console.log("Final USDe balance:", usde.balanceOf(deployer));
        console.log("Final rUSD balance:", rUsd.balanceOf(deployer));
        console.log("Final LP token balance:", lpToken.balanceOf(deployer));

        // Verify we received shares
        assertGt(shares, 0, "Should have received LP shares");
        assertEq(
            lpToken.balanceOf(deployer),
            shares,
            "LP token balance should match shares"
        );

        vm.stopPrank();

        // Setup trader account for swap testing
        address trader = makeAddr("trader");
        uint256 tradeAmount = 1e18; // 1 token

        // Fund trader with USDe
        deal(address(usde), trader, tradeAmount * 2);

        vm.startPrank(trader);
        // Record initial balances
        uint256 initialUsdeBalance = usde.balanceOf(trader);
        uint256 initialRusdBalance = rUsd.balanceOf(trader);

        // Approve tokens for trading
        usde.approve(address(diamond), type(uint256).max);
        rUsd.approve(address(diamond), type(uint256).max);

        // Perform USDe -> rUSD swap
        (uint256 inAmount, uint256 outAmount) = swapFacet.swap(
            trader, // recipient - who receives the output tokens
            address(usde), // inToken - token being swapped from
            address(rUsd), // outToken - token being swapped to
            int256(tradeAmount), // amountSpecified - positive for exact input, negative for exact output
            MIN_SQRT_PRICE_X96 + 1 // sqrtPriceLimitX96 - minimum price limit for the swap
        );

        // Verify swap results
        assertGt(outAmount, 0, "Should have received rUSD tokens");
        assertEq(
            usde.balanceOf(trader),
            initialUsdeBalance - inAmount,
            "USDe balance should be reduced by trade amount"
        );
        assertEq(
            rUsd.balanceOf(trader),
            initialRusdBalance + outAmount,
            "rUSD balance should be increased by swap output"
        );

        // Perform reverse swap rUSD -> USDe
        (uint256 reverseInAmount, uint256 reverseOutAmount) = swapFacet.swap(
            trader, // recipient - who receives the output tokens
            address(rUsd), // inToken - token being swapped from
            address(usde), // outToken - token being swapped to
            int256(outAmount), // amountSpecified - positive for exact input, negative for exact output
            MAX_SQRT_PRICE_X96 - 1 // sqrtPriceLimitX96 - maximum price limit for the swap
        );

        // Verify reverse swap results
        assertGt(reverseOutAmount, 0, "Should have received USDe tokens");
        assertLt(
            reverseOutAmount,
            tradeAmount,
            "Should receive less USDe than original trade due to fees"
        );

        vm.stopPrank();
    }
}
