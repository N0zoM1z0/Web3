// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Deploy} from "../../script/Deploy.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CrossChainRouterMock} from "./CrossChainRouterMock.sol";
import {CoreRouter} from "../../src/LayerZero/CoreRouter.sol";
import {LendStorage} from "../../src/LayerZero/LendStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {Lendtroller} from "../../src/Lendtroller.sol";
import {InterestRateModel} from "../../src/InterestRateModel.sol";
import {SimplePriceOracle} from "../../src/SimplePriceOracle.sol";
import {LTokenInterface} from "../../src/LTokenInterfaces.sol";
import {LToken} from "../../src/LToken.sol";
import "@layerzerolabs/lz-evm-oapp-v2/test/TestHelper.sol";
import "@layerzerolabs/lz-evm-protocol-v2/test/utils/LayerZeroTest.sol";

contract TestLendAccrual is LayerZeroTest {
    CoreRouter public coreRouter;
    LendStorage public lendStorage;
    Lendtroller public lendtroller;
    SimplePriceOracle public priceOracle;
    address[] public lTokens;
    address[] public supportedTokens;
    address public deployer;
    address public user1;
    address public user2;

    function setUp() public override {
        super.setUp();

        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        vm.deal(deployer, 1000 ether);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);

        // Deploy protocol
        Deploy deploy = new Deploy();
        (
            address priceOracleAddress,
            address lendtrollerAddress,
            ,
            address[] memory lTokenAddresses,
            ,
            address payable coreRouterAddress,
            address lendStorageAddress,
            ,
            address[] memory _supportedTokens
        ) = deploy.run(address(endpoint));

        // Store contract references
        coreRouter = CoreRouter(coreRouterAddress);
        lendStorage = LendStorage(lendStorageAddress);
        lendtroller = Lendtroller(lendtrollerAddress);
        priceOracle = SimplePriceOracle(priceOracleAddress);
        lTokens = lTokenAddresses;
        supportedTokens = _supportedTokens;

        // Set up initial prices
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            priceOracle.setDirectPrice(supportedTokens[i], 1e18);
        }
    }

    function test_lend_accrues_over_time() public {
        // Supply tokens to start accruing LEND
        uint256 supplyAmount = 1000e18;
        (, address lToken) = _supply(supplyAmount, user1);

        // Get initial LEND accrued
        uint256 initialLendAccrued = lendStorage.lendAccrued(user1);

        // Advance time and blocks
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1000);

        // Trigger LEND distribution
        vm.prank(user1);
        address[] memory holders = new address[](1);
        holders[0] = user1;
        LToken[] memory lTokenArray = new LToken[](1);
        lTokenArray[0] = LToken(lToken);
        coreRouter.claimLend(holders, lTokenArray, false, true);

        // Get final LEND accrued
        uint256 finalLendAccrued = lendStorage.lendAccrued(user1);

        // Verify LEND accrued increased
        assertGt(finalLendAccrued, initialLendAccrued, "LEND should accrue over time");
    }

    function test_claimed_lend_matches_lend_accrued() public {
        // Supply tokens with two users
        uint256 supplyAmount = 1000e18;
        (, address lToken) = _supply(supplyAmount, user1);
        _supply(supplyAmount, user2);

        // Advance time
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1000);

        // Get initial LEND token balance
        address lendToken = lendtroller.getLendAddress();
        uint256 initialBalance = IERC20(lendToken).balanceOf(user1);

        // Record accrued LEND before claiming
        vm.prank(user1);
        address[] memory holders = new address[](1);
        holders[0] = user1;
        LToken[] memory lTokenArray = new LToken[](1);
        lTokenArray[0] = LToken(lToken);
        coreRouter.claimLend(holders, lTokenArray, false, true);

        uint256 lendAccrued = lendStorage.lendAccrued(user1);
        uint256 finalBalance = IERC20(lendToken).balanceOf(user1);

        // Verify claimed amount matches accrued amount
        assertEq(finalBalance - initialBalance, lendAccrued, "Claimed LEND should match accrued amount");
    }

    function test_multiple_users_accrue_proportionally() public {
        // Supply different amounts with two users
        uint256 user1Supply = 1000e18;
        uint256 user2Supply = 500e18;
        (, address lToken) = _supply(user1Supply, user1);
        _supply(user2Supply, user2);

        // Advance time
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1000);

        // Claim for both users
        address[] memory holders = new address[](2);
        holders[0] = user1;
        holders[1] = user2;
        LToken[] memory lTokenArray = new LToken[](1);
        lTokenArray[0] = LToken(lToken);

        vm.prank(user1);
        coreRouter.claimLend(holders, lTokenArray, false, true);

        // Get accrued amounts
        uint256 user1Accrued = lendStorage.lendAccrued(user1);
        uint256 user2Accrued = lendStorage.lendAccrued(user2);

        // Verify user1 accrued proportionally more (roughly 2x)
        assertApproxEqRel(
            user1Accrued,
            user2Accrued * 2,
            0.01e18, // 1% tolerance
            "Users should accrue proportionally to their supply"
        );
    }

    function test_borrower_lend_accrual() public {
        // First supply tokens
        uint256 supplyAmount = 2000e18;
        (address token, address lToken) = _supply(supplyAmount, user2);

        // Then have user1 borrow
        uint256 borrowAmount = 100e18;
        _borrow(user1, token, borrowAmount);

        // Get initial accrued LEND
        uint256 initialLendAccrued = lendStorage.lendAccrued(user1);

        // Advance time
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1000);

        // Claim LEND
        address[] memory holders = new address[](1);
        holders[0] = user1;
        LToken[] memory lTokenArray = new LToken[](1);
        lTokenArray[0] = LToken(lToken);

        vm.prank(user1);
        coreRouter.claimLend(holders, lTokenArray, true, false);

        // Verify borrower accrued LEND
        uint256 finalLendAccrued = lendStorage.lendAccrued(user1);
        assertGt(finalLendAccrued, initialLendAccrued, "Borrower should accrue LEND");
    }

    function test_lend_accrual_stops_after_redeem() public {
        // Supply tokens
        uint256 supplyAmount = 1000e18;
        (, address lToken) = _supply(supplyAmount, user1);

        // Advance time and get initial accrual
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1000);

        // Redeem all tokens
        vm.startPrank(user1);
        uint256 lTokenBalance = lendStorage.totalInvestment(user1, lToken);
        coreRouter.redeem(lTokenBalance, payable(lToken));
        vm.stopPrank();

        // Record LEND accrued
        uint256 lendAccruedAfterRedeem = lendStorage.lendAccrued(user1);

        // Advance more time
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1000);

        // Verify no additional LEND accrued
        assertEq(lendStorage.lendAccrued(user1), lendAccruedAfterRedeem, "Should not accrue LEND after full redeem");
    }

    // Helper Functions

    function _supply(uint256 amount, address user) internal returns (address token, address lToken) {
        token = supportedTokens[0];
        lToken = lendStorage.underlyingTolToken(token);

        vm.startPrank(user);
        ERC20Mock(token).mint(user, amount);
        IERC20(token).approve(address(coreRouter), amount);
        coreRouter.supply(amount, token);
        vm.stopPrank();
    }

    function _borrow(address user, address token, uint256 amount) internal {
        vm.startPrank(user);
        ERC20Mock(token).mint(user, amount * 2); // Extra collateral
        IERC20(token).approve(address(coreRouter), amount * 2);
        coreRouter.supply(amount * 2, token); // Supply collateral first
        coreRouter.borrow(amount, token);
        vm.stopPrank();
    }
}
