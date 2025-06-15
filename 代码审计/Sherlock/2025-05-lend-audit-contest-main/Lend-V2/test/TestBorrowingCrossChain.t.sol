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
import {SendLibMock} from "@layerzerolabs/lz-evm-messagelib-v2/test/mocks/SendLibMock.sol";
import "@layerzerolabs/lz-evm-protocol-v2/test/utils/LayerZeroTest.sol";

contract TestBorrowingCrossChain is LayerZeroTest {
    HelperConfig public helperConfig;
    address public layerZeroEndpoint;
    address[] public supportedTokensA;
    address[] public supportedTokensB;
    address[] public supportedTokensC;
    bool public isTestnet;
    address public deployer;

    // Chain A (Source)
    CrossChainRouterMock public routerA;
    LendStorage public lendStorageA;
    CoreRouter public coreRouterA;
    Lendtroller public lendtrollerA;
    InterestRateModel public interestRateModelA;
    SimplePriceOracle public priceOracleA;
    address[] public lTokensA;

    // Chain B (Destination)
    CrossChainRouterMock public routerB;
    LendStorage public lendStorageB;
    CoreRouter public coreRouterB;
    Lendtroller public lendtrollerB;
    InterestRateModel public interestRateModelB;
    SimplePriceOracle public priceOracleB;
    address[] public lTokensB;

    uint32 constant CHAIN_A_ID = 1;
    uint32 constant CHAIN_B_ID = 2;

    EndpointV2 public endpointA;
    EndpointV2 public endpointB;
    SimpleMessageLib public simpleMsgLibA;
    SimpleMessageLib public simpleMsgLibB;

    // Events to test
    event BorrowSuccess(address indexed borrower, address indexed lToken, uint256 accountBorrow);

    function setUp() public override(LayerZeroTest) {
        super.setUp();

        deployer = makeAddr("deployer");
        vm.deal(deployer, 1000 ether);

        // Deploy protocol on Chain A using the endpoint we just created
        Deploy deployA = new Deploy();
        (
            address priceOracleAddressA,
            address lendtrollerAddressA,
            address interestRateModelAddressA,
            address[] memory lTokenAddressesA,
            address payable routerAddressA,
            address payable coreRouterAddressA,
            address lendStorageAddressA,
            , //address _layerZeroEndpoint
            address[] memory _supportedTokensA
        ) = deployA.run(address(endpointA)); // Pass the endpoint address to Deploy.run

        // Store Chain A values
        routerA = CrossChainRouterMock(payable(routerAddressA));
        lendStorageA = LendStorage(lendStorageAddressA);
        coreRouterA = CoreRouter(coreRouterAddressA);
        lendtrollerA = Lendtroller(lendtrollerAddressA);
        interestRateModelA = InterestRateModel(interestRateModelAddressA);
        priceOracleA = SimplePriceOracle(priceOracleAddressA);
        lTokensA = lTokenAddressesA;
        supportedTokensA = _supportedTokensA;

        // Deploy protocol on Chain B
        Deploy deployB = new Deploy();
        (
            address priceOracleAddressB,
            address lendtrollerAddressB,
            address interestRateModelAddressB,
            address[] memory lTokenAddressesB,
            address payable routerAddressB,
            address payable coreRouterAddressB,
            address lendStorageAddressB,
            , // address _layerZeroEndpoint
            address[] memory _supportedTokensB
        ) = deployB.run(address(endpointB));

        // Store Chain B values
        routerB = CrossChainRouterMock(payable(routerAddressB));
        lendStorageB = LendStorage(lendStorageAddressB);
        coreRouterB = CoreRouter(coreRouterAddressB);
        lendtrollerB = Lendtroller(lendtrollerAddressB);
        interestRateModelB = InterestRateModel(interestRateModelAddressB);
        priceOracleB = SimplePriceOracle(priceOracleAddressB);
        lTokensB = lTokenAddressesB;
        supportedTokensB = _supportedTokensB;

        // Now set up cross-chain mappings as the owner
        vm.startPrank(routerA.owner());
        for (uint256 i = 0; i < supportedTokensA.length; i++) {
            lendStorageA.addUnderlyingToDestUnderlying(supportedTokensA[i], supportedTokensB[i], CHAIN_B_ID);
            // Add mapping from underlying token to destination lToken
            lendStorageA.addUnderlyingToDestlToken(supportedTokensA[i], lTokensB[i], CHAIN_B_ID);
        }
        vm.stopPrank();

        vm.startPrank(routerB.owner());
        for (uint256 i = 0; i < supportedTokensB.length; i++) {
            lendStorageB.addUnderlyingToDestUnderlying(supportedTokensB[i], supportedTokensA[i], CHAIN_A_ID);
            // Add mapping from underlying token to destination lToken
            lendStorageB.addUnderlyingToDestlToken(supportedTokensB[i], lTokensA[i], CHAIN_A_ID);
        }
        vm.stopPrank();

        // Set up initial prices for supported tokens on both chains

        for (uint256 i = 0; i < supportedTokensA.length; i++) {
            priceOracleA.setDirectPrice(supportedTokensA[i], 1e18);
        }

        for (uint256 i = 0; i < supportedTokensB.length; i++) {
            priceOracleB.setDirectPrice(supportedTokensB[i], 1e18);
        }

        vm.label(address(routerA), "Router A");
        vm.label(address(routerB), "Router B");
        // After deploying routers, set up their pair contracts
        routerA = CrossChainRouterMock(payable(routerAddressA));
        routerB = CrossChainRouterMock(payable(routerAddressB));

        // Set up pair relationships
        routerA.setPairContract(payable(address(routerB)));
        routerB.setPairContract(payable(address(routerA)));
    }

    // Helper function to supply tokens before testing borrowing
    function _supplyA(uint256 amount) internal returns (address token, address lToken) {
        // Deal ether for LayerZero fees
        vm.deal(address(routerA), 1 ether);

        token = supportedTokensA[0];
        lToken = lendStorageA.underlyingTolToken(token);

        vm.startPrank(deployer);
        ERC20Mock(token).mint(deployer, amount);
        IERC20(token).approve(address(coreRouterA), amount);
        coreRouterA.supply(amount, token);
        vm.stopPrank();
    }

    function _supplyB(uint256 amount) internal returns (address token, address lToken) {
        // Deal ether for LayerZero fees
        vm.deal(address(routerB), 1 ether);

        token = supportedTokensB[0];
        lToken = lendStorageB.underlyingTolToken(token);

        vm.startPrank(deployer);
        ERC20Mock(token).mint(deployer, amount);
        IERC20(token).approve(address(coreRouterB), amount);
        coreRouterB.supply(amount, token);
        vm.stopPrank();
    }

    function test_that_cross_chain_borrowing_with_no_collateral_reverts() public {
        vm.startPrank(deployer);
        address token = supportedTokensA[0];

        vm.deal(address(routerA), 1 ether);

        vm.expectRevert();
        routerA.borrowCrossChain(1e18, token, CHAIN_B_ID);

        vm.stopPrank();
    }

    function test_that_cross_chain_borrowing_works(uint256 amountToSupply, uint256 amountToBorrow) public {
        // Bound amount between 1e18 and 1e30 to ensure reasonable test values
        amountToSupply = bound(amountToSupply, 1e18, 1e30);

        // Fund Router A with ETH for LayerZero fees
        vm.deal(address(routerA), 1 ether);

        // First supply tokens as collateral on Chain A
        (address tokenA,) = _supplyA(amountToSupply);

        // Then supply tokens as borrowable on Chain B
        // @note - Has to be enough tokens to cover the borrow on the destination chain...
        _supplyB(amountToSupply * 2);

        // Calculate maximum allowed borrow (using actual collateral factor) --> scale down for precision loss
        uint256 maxBorrow = (lendStorageA.getMaxBorrowAmount(deployer, tokenA) * 0.9e18) / 1e18;

        uint256 boundedBorrow = bound(amountToBorrow, 0.1e18, maxBorrow);

        // Verify token mappings
        address destToken = lendStorageA.underlyingToDestUnderlying(tokenA, CHAIN_B_ID);

        require(destToken != address(0), "Token mapping not set up correctly");

        // Get initial balances
        uint256 initialTokenBalance = IERC20(destToken).balanceOf(deployer);

        vm.startPrank(deployer);

        // Expect BorrowSuccess event
        vm.expectEmit(true, true, true, true);
        emit BorrowSuccess(deployer, tokenA, boundedBorrow);

        // Call borrowCrossChain with token address
        routerA.borrowCrossChain(boundedBorrow, tokenA, CHAIN_B_ID);

        // Verify the borrow was successful
        assertEq(
            IERC20(destToken).balanceOf(deployer) - initialTokenBalance,
            boundedBorrow,
            "Should receive correct amount of borrowed tokens"
        );

        vm.stopPrank();
    }

    function test_that_a_user_can_only_borrow_up_to_their_allowed_capacity(
        uint256 amountToSupply,
        uint256 amountToBorrow
    ) public {
        // Bound amount between 1e18 and 1e30 to ensure reasonable test values
        amountToSupply = bound(amountToSupply, 1e18, 1e30);

        // Fund Router A with ETH for LayerZero fees
        vm.deal(address(routerA), 1 ether);

        // First supply tokens as collateral on Chain A
        (address tokenA, address lTokenA) = _supplyA(amountToSupply);

        // Then supply tokens as borrowable on Chain B
        // @note - Has to be enough tokens to cover the borrow on the destination chain...
        _supplyB(amountToSupply * 2);

        // Calculate maximum allowed borrow (using actual collateral factor)
        uint256 maxBorrow = lendStorageA.getMaxBorrowAmount(deployer, tokenA);

        uint256 boundedBorrow = bound(amountToBorrow, maxBorrow + 0.1e18, 1e30);

        // Verify token mappings
        address destToken = lendStorageA.underlyingToDestUnderlying(tokenA, CHAIN_B_ID);

        require(destToken != address(0), "Token mapping not set up correctly");

        vm.startPrank(deployer);

        // Expect Revert as amount > max borrow
        vm.expectRevert();

        // Call borrowCrossChain with token address
        routerA.borrowCrossChain(boundedBorrow, tokenA, CHAIN_B_ID);

        vm.stopPrank();
    }

    /**
     * @dev - Previous vulnerability where attacker could borrow against another user's collateral.
     */
    function test_security_vulnerability_borrowing_against_others_collateral(
        uint256 amountToSupply,
        uint256 amountToBorrow
    ) public {
        amountToSupply = bound(amountToSupply, 1e18, 1e30);

        // Setup attacker address
        address attacker = makeAddr("attacker");
        vm.deal(attacker, 1 ether);

        // First have deployer supply collateral
        (address tokenA,) = _supplyA(amountToSupply);
        _supplyB(amountToSupply * 2); // Supply tokens on chain B for borrowing

        // Bounded to any number this should revert
        amountToBorrow = bound(amountToBorrow, 1, 1e30);

        // Now have attacker try to borrow against deployer's collateral
        vm.startPrank(attacker);
        vm.deal(address(routerA), 1 ether); // Fund router for LayerZero fees

        vm.expectRevert();

        // This should revert - attacker can borrow against deployer's collateral!
        routerA.borrowCrossChain(amountToBorrow, tokenA, CHAIN_B_ID);

        vm.stopPrank();
    }

    function test_that_cross_chain_borrowing_updates_account_liquidity(uint256 amountToSupply, uint256 amountToBorrow)
        public
    {
        amountToSupply = bound(amountToSupply, 1e18, 1e30);

        vm.deal(address(routerA), 1 ether);

        (address tokenA, address lTokenA) = _supplyA(amountToSupply);
        _supplyB(amountToSupply * 2);

        // Calculate maximum allowed borrow (using actual collateral factor) --> scale down for precision loss
        uint256 maxBorrow = (lendStorageA.getMaxBorrowAmount(deployer, tokenA) * 0.9e18) / 1e18;

        uint256 boundedBorrow = bound(amountToBorrow, 0.1e18, maxBorrow);

        // Get initial collateral
        (, uint256 initialCollateral) =
            lendStorageA.getHypotheticalAccountLiquidityCollateral(deployer, LToken(lTokenA), 0, 0);

        assertGt(initialCollateral, 0, "Initial collateral should be greater than 0");

        vm.startPrank(deployer);

        // Execute borrow
        routerA.borrowCrossChain(boundedBorrow, tokenA, CHAIN_B_ID);

        // Get final collateral
        (, uint256 finalCollateral) =
            lendStorageA.getHypotheticalAccountLiquidityCollateral(deployer, LToken(lTokenA), 0, 0);

        // Verify collateral remains unchanged
        assertEq(finalCollateral, initialCollateral, "Collateral should not change");

        // Get the destination chain borrow details using the test contract address
        LendStorage.Borrow[] memory userBorrows = lendStorageA.getCrossChainBorrows(deployer, tokenA);

        // Update the expected chain ID to match the actual chain ID used by the mock
        assertEq(userBorrows[0].srcEid, block.chainid, "Source chain ID should match");
        assertEq(userBorrows[0].principle, boundedBorrow, "Borrow principle should match");
        assertEq(userBorrows[0].srcToken, tokenA, "Source token should match");

        vm.stopPrank();
    }

    /// @dev - Passes for more runs, but takes long time with each fuzz run.
    function test_that_multiple_cross_chain_borrows_work(uint256[] memory amountsToBorrow) public {
        // Bound array length
        vm.assume(amountsToBorrow.length > 0 && amountsToBorrow.length <= 5);

        vm.deal(address(routerA), 1 ether);

        // Supply large amount of collateral on Chain A
        uint256 largeAmount = 1e30;
        (address tokenA, address lTokenA) = _supplyA(largeAmount);

        // Supply tokens on Chain B
        _supplyB(largeAmount * 2);

        // Calculate maximum allowed borrow (using actual collateral factor) --> scale down for precision loss
        uint256 maxTotalBorrow = (lendStorageA.getMaxBorrowAmount(deployer, tokenA) * 0.9e18) / 1e18;

        uint256 totalBorrowed = 0;

        vm.startPrank(deployer);

        // Execute multiple borrows
        for (uint256 i = 0; i < amountsToBorrow.length; i++) {
            // Bound each amount between 1e18 and maxTotalBorrow/amountsToBorrow.length
            uint256 boundedAmount = bound(amountsToBorrow[i], 0.1e18, maxTotalBorrow / amountsToBorrow.length);

            // Skip if this would exceed max borrow
            if (totalBorrowed + boundedAmount > maxTotalBorrow) continue;

            routerA.borrowCrossChain(boundedAmount, tokenA, CHAIN_B_ID);
            totalBorrowed += boundedAmount;
        }

        // Verify final borrowed amount
        uint256 finalBorrowed = lendStorageA.borrowWithInterest(deployer, lTokenA);
        assertEq(finalBorrowed, totalBorrowed, "Total borrowed amount should match sum of individual borrows");

        vm.stopPrank();
    }

    function test_cross_chain_borrow_fails_with_insufficient_liquidity(uint256 amountToSupply, uint256 amountToBorrow)
        public
    {
        vm.deal(address(routerA), 1 ether);

        // Supply small amount as collateral
        amountToSupply = bound(amountToSupply, 1e18, 1e30);

        (address tokenA,) = _supplyA(amountToSupply);

        // No matter what is inputted, it should revert
        amountToBorrow = bound(amountToBorrow, 1, 1e30);

        vm.startPrank(deployer);

        vm.expectRevert();
        routerA.borrowCrossChain(amountToBorrow, tokenA, CHAIN_B_ID);

        vm.stopPrank();
    }

    function test_borrow_index_updates_correctly(uint256 amountToSupply, uint256 amountToBorrow) public {
        amountToSupply = bound(amountToSupply, 1e18, 1e30);

        vm.deal(address(routerA), 1 ether);

        (address tokenA, address lTokenA) = _supplyA(amountToSupply);
        _supplyB(amountToSupply * 2);

        // Calculate maximum allowed borrow (using actual collateral factor) --> scale down for precision loss
        uint256 maxBorrow = (lendStorageA.getMaxBorrowAmount(deployer, tokenA) * 0.9e18) / 1e18;

        uint256 borrowAmount = bound(amountToBorrow, 0.1e18, maxBorrow);

        // Get initial borrow index
        uint256 initialBorrowIndex = LToken(lTokenA).borrowIndex();

        vm.startPrank(deployer);

        // Execute borrow
        routerA.borrowCrossChain(borrowAmount, tokenA, CHAIN_B_ID);

        // Advance some blocks to accrue interest
        vm.warp(block.timestamp + 1000);
        vm.roll(block.number + 1000);

        // Call accrue interest to trigger borrow index update
        LToken(lTokenA).accrueInterest();

        // Get updated borrow index
        uint256 newBorrowIndex = LToken(lTokenA).borrowIndex();

        // Verify borrow index increased
        assertGt(newBorrowIndex, initialBorrowIndex, "Borrow index should increase");

        vm.stopPrank();
    }

    function test_cross_chain_borrow_reverts_on_zero_amount() public {
        vm.deal(address(routerA), 1 ether);

        (address tokenA,) = _supplyA(1e18);
        _supplyB(1e18 * 2);

        vm.startPrank(deployer);

        vm.expectRevert();
        routerA.borrowCrossChain(0, tokenA, CHAIN_B_ID);

        vm.stopPrank();
    }

    function test_cross_chain_borrow_reverts_on_invalid_token() public {
        vm.deal(address(routerA), 1 ether);

        address invalidToken = address(0x123);

        vm.startPrank(deployer);

        vm.expectRevert();
        routerA.borrowCrossChain(1e18, invalidToken, CHAIN_B_ID);

        vm.stopPrank();
    }

    function test_cross_chain_borrow_updates_details_in_storage(uint256 amountToSupply, uint256 amountToBorrow)
        public
    {
        amountToSupply = bound(amountToSupply, 1e18, 1e30);

        vm.deal(address(routerA), 1 ether);

        (address tokenA,) = _supplyA(amountToSupply);
        _supplyB(amountToSupply * 2);

        uint256 maxBorrow = (lendStorageA.getMaxBorrowAmount(deployer, tokenA) * 0.9e18) / 1e18;

        uint256 borrowAmount = bound(amountToBorrow, 0.1e18, maxBorrow);

        vm.startPrank(deployer);

        // Execute borrow
        routerA.borrowCrossChain(borrowAmount, tokenA, CHAIN_B_ID);

        // Check destination borrow details
        LendStorage.Borrow[] memory userBorrows = lendStorageA.getCrossChainBorrows(deployer, tokenA);

        assertEq(userBorrows[0].srcEid, block.chainid, "Source chain ID should match");
        assertEq(userBorrows[0].principle, borrowAmount, "Borrow principle should match");
        assertEq(userBorrows[0].srcToken, tokenA, "Source token should match");

        vm.stopPrank();
    }

    function test_borrowing_from_b_to_a_works(uint256 amountToSupply, uint256 amountToBorrow) public {
        // Bound amount between 1e18 and 1e30 to ensure reasonable test values
        amountToSupply = bound(amountToSupply, 1e18, 1e30);

        // Fund Router A with ETH for LayerZero fees
        vm.deal(address(routerB), 1 ether);

        // First supply tokens as collateral on Chain A
        (address tokenB,) = _supplyB(amountToSupply);

        // Then supply tokens as borrowable on Chain B
        // @note - Has to be enough tokens to cover the borrow on the destination chain...
        _supplyA(amountToSupply * 2);

        // Calculate maximum allowed borrow (using actual collateral factor) --> scale down for precision loss
        uint256 maxBorrow = (lendStorageB.getMaxBorrowAmount(deployer, tokenB) * 0.9e18) / 1e18;

        uint256 boundedBorrow = bound(amountToBorrow, 0.1e18, maxBorrow);

        // Verify token mappings
        address destToken = lendStorageB.underlyingToDestUnderlying(tokenB, CHAIN_A_ID);

        require(destToken != address(0), "Token mapping not set up correctly");

        // Get initial balances
        uint256 initialTokenBalance = IERC20(destToken).balanceOf(deployer);

        vm.startPrank(deployer);

        // Expect BorrowSuccess event
        vm.expectEmit(true, true, true, true);
        emit BorrowSuccess(deployer, tokenB, boundedBorrow);

        // Call borrowCrossChain with token address
        routerB.borrowCrossChain(boundedBorrow, tokenB, CHAIN_A_ID);

        // Verify the borrow was successful
        assertEq(
            IERC20(destToken).balanceOf(deployer) - initialTokenBalance,
            boundedBorrow,
            "Should receive correct amount of borrowed tokens"
        );

        vm.stopPrank();
    }
}
