// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CrossChainRouterMock} from "./mocks/CrossChainRouterMock.sol";
import {CoreRouter} from "../src/LayerZero/CoreRouter.sol";
import {LendStorage} from "../src/LayerZero/LendStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Lendtroller} from "../src/Lendtroller.sol";
import {InterestRateModel} from "../src/InterestRateModel.sol";
import {SimplePriceOracle} from "../src/SimplePriceOracle.sol";
import {LTokenInterface} from "../src/LTokenInterfaces.sol";
import {LToken} from "../src/LToken.sol";
import "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";

contract TestSupplying is Test {
    HelperConfig public helperConfig;
    address public layerZeroEndpoint;
    address[] public supportedTokens;
    bool public isTestnet;
    address public deployer;

    CrossChainRouterMock public router;
    LendStorage public lendStorage;
    CoreRouter public coreRouter;
    Lendtroller public lendtroller;
    InterestRateModel public interestRateModel;
    SimplePriceOracle public priceOracle;

    TestHelper public testHelper;

    address[] public lTokens;

    // Events to test
    event SupplySuccess(address indexed supplier, address indexed lToken, uint256 supplyAmount, uint256 supplyTokens);

    function setUp() public {
        deployer = makeAddr("deployer");

        // Deploy the entire protocol
        Deploy deploy = new Deploy();
        (
            address priceOracleAddress,
            address lendtrollerAddress,
            address interestRateModelAddress,
            address[] memory lTokenAddresses,
            address payable routerAddress,
            address payable coreRouterAddress,
            address lendStorageAddress,
            address _layerZeroEndpoint,
            address[] memory _supportedTokens
        ) = deploy.run();

        // Store the values in contract state variables
        router = CrossChainRouterMock(routerAddress);
        lendtroller = Lendtroller(lendtrollerAddress);
        interestRateModel = InterestRateModel(interestRateModelAddress);
        priceOracle = SimplePriceOracle(priceOracleAddress);
        lTokens = lTokenAddresses;
        lendStorage = LendStorage(lendStorageAddress);
        coreRouter = CoreRouter(coreRouterAddress);
        layerZeroEndpoint = _layerZeroEndpoint;
        supportedTokens = _supportedTokens;

        testHelper = TestHelper(payable(layerZeroEndpoint));

        // Set up initial prices for supported tokens
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            // Set price to 1e18 (1:1 with ETH) for testing
            priceOracle.setDirectPrice(supportedTokens[i], 1e18);
        }
    }

    function test_that_supplying_zero_amount_reverts() public {
        vm.startPrank(deployer);
        address token = supportedTokens[0];

        vm.expectRevert();
        coreRouter.supply(0, token);

        vm.stopPrank();
    }

    function test_that_supplying_unsupported_token_reverts() public {
        vm.startPrank(deployer);
        ERC20Mock unsupportedToken = new ERC20Mock();

        vm.expectRevert("Unsupported Token");
        coreRouter.supply(1e18, address(unsupportedToken));

        vm.stopPrank();
    }

    function test_that_supplying_without_approval_reverts(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max);
        vm.startPrank(deployer);

        address token = supportedTokens[0];
        ERC20Mock(token).mint(deployer, amount);

        vm.expectRevert();
        coreRouter.supply(amount, token);

        vm.stopPrank();
    }

    function test_that_supplying_with_insufficient_balance_reverts(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max);
        vm.startPrank(deployer);

        address token = supportedTokens[0];
        ERC20Mock(token).mint(deployer, amount - 1);
        IERC20(token).approve(address(coreRouter), amount);

        vm.expectRevert();
        coreRouter.supply(amount, token);

        vm.stopPrank();
    }

    function test_that_supplying_liquidity_works(uint256 amount) public {
        // Assume reasonable amount bounds
        vm.assume(amount > 1e18 && amount < 1e36);
        vm.startPrank(deployer);

        address token = supportedTokens[0];
        address lToken = lendStorage.underlyingTolToken(token);

        // Mint tokens to deployer
        ERC20Mock(token).mint(deployer, amount);
        IERC20(token).approve(address(coreRouter), amount);

        // Calculate expected tokens based on exchange rate
        uint256 exchangeRate = LTokenInterface(lToken).exchangeRateStored();
        uint256 expectedTokens = (amount * 1e18) / exchangeRate;

        // Expect SupplySuccess event with correct token amounts
        vm.expectEmit(true, true, true, true);
        emit SupplySuccess(deployer, lToken, amount, expectedTokens);

        coreRouter.supply(amount, token);

        // Verify state changes
        assertEq(IERC20(token).balanceOf(lToken), amount, "Router should have received tokens");
        assertGt(lendStorage.totalInvestment(deployer, lToken), 0, "Total investment should be updated");
        assertEq(
            LTokenInterface(lToken).balanceOf(address(coreRouter)),
            expectedTokens,
            "Router should have received correct amount of lTokens"
        );

        vm.stopPrank();
    }

    function test_that_multiple_supplies_accumulate_correctly(uint256[] calldata amounts) public {
        vm.assume(amounts.length > 0 && amounts.length <= 10); // Test up to 10 supplies
        vm.startPrank(deployer);

        address token = supportedTokens[0];
        address lToken = lendStorage.underlyingTolToken(token);
        uint256 totalSupplied = 0;
        uint256 totalLTokens = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = bound(amounts[i], 1, 1e30); // Bound each amount to reasonable values
            ERC20Mock(token).mint(deployer, amount);
            IERC20(token).approve(address(coreRouter), amount);

            // Get balance before supply
            uint256 lTokenBalanceBefore = LTokenInterface(lToken).balanceOf(address(coreRouter));

            coreRouter.supply(amount, token);

            // Get balance after supply and calculate tokens received
            uint256 lTokenBalanceAfter = LTokenInterface(lToken).balanceOf(address(coreRouter));
            uint256 tokensReceived = lTokenBalanceAfter - lTokenBalanceBefore;

            totalSupplied += amount;
            totalLTokens += tokensReceived;
        }

        // Check the total investment matches the total lTokens received
        assertEq(
            lendStorage.totalInvestment(deployer, lToken),
            LTokenInterface(lToken).balanceOf(address(coreRouter)),
            "Total investment should equal final lToken balance"
        );

        // Check the underlying balance matches total supplied
        assertEq(
            IERC20(token).balanceOf(lToken), totalSupplied, "Total underlying balance should equal sum of all supplies"
        );

        vm.stopPrank();
    }

    function test_that_user_supplied_assets_are_tracked() public {
        vm.startPrank(deployer);

        address token = supportedTokens[0];
        address lToken = lendStorage.underlyingTolToken(token);
        uint256 amount = 1e18;

        ERC20Mock(token).mint(deployer, amount);
        IERC20(token).approve(address(coreRouter), amount);

        coreRouter.supply(amount, token);

        // Use the public mapping to verify the asset is tracked
        (uint256 sumBorrowPlusEffects, uint256 sumCollateral) =
            lendStorage.getHypotheticalAccountLiquidityCollateral(deployer, LToken(lToken), 0, 0);

        assertGt(sumCollateral, 0, "Collateral should be tracked");
        assertGe(sumCollateral, sumBorrowPlusEffects, "Should not have shortfall");

        vm.stopPrank();
    }
}
