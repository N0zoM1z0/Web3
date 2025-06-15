// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStabilityPool} from "./utils/Setup.sol";
import {IAuction} from "../interfaces/IAuction.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

contract OperationTest is Setup {

    function setUp() public virtual override {
        super.setUp();

        vm.prank(management);
        strategy.allowDeposits();
    }

    function test_setupStrategyOK() public {
        console2.log("address of strategy", address(strategy));
        assertEq(strategyFactory.deployments(address(asset), stabilityPool), address(strategy));
        assertTrue(strategyFactory.isDeployedStrategy(address(strategy)));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertTrue(strategy.openDeposits());
        assertEq(strategy.maxGasPriceToTend(), 200 * 1e9);
        assertEq(strategy.bufferPercentage(), 1.1e18);
        assertTrue(strategy.AUCTION() != address(0));
        assertEq(strategy.COLL(), tokenAddrs["WETH"]);
        assertEq(strategy.SP(), stabilityPool);
        assertEq(strategy.COLL_PRICE_ORACLE(), collateralPriceOracle);
    }

    function test_operation(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_profitableReport(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS / 10));

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        simulateYieldGain(toAirdrop);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");
    }

    function test_profitableReport_withFees(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount * 1e4 && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS / 10));

        // Set protocol fee to 0 and perf fee to 10%
        setFees(0, 1000);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        simulateYieldGain(toAirdrop);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        // Get the expected fee
        uint256 expectedShares = (profit * 1000) / MAX_BPS;

        assertEq(strategy.balanceOf(performanceFeeRecipient), expectedShares);

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(asset.balanceOf(user), balanceBefore + _amount, "!final balance");

        vm.prank(performanceFeeRecipient);
        strategy.redeem(expectedShares, performanceFeeRecipient, performanceFeeRecipient);

        checkStrategyTotals(strategy, 0, 0, 0);

        assertGe(asset.balanceOf(performanceFeeRecipient), expectedShares, "!perf fee out");
    }

    function test_tendTrigger(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Skip some time
        skip(1 days);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        vm.prank(keeper);
        strategy.report();

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Unlock Profits
        skip(strategy.profitMaxUnlockTime());

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        vm.prank(user);
        strategy.redeem(_amount, user, user);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendTrigger_collateralToSell(uint256 _amount, uint256 _airdropAmount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        vm.assume(_airdropAmount > strategy.dustThreshold() && _airdropAmount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        airdrop(ERC20(strategy.COLL()), address(strategy), _airdropAmount);
        (bool trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendTrigger_notEnoughCollateralToSell(uint256 _amount, uint256 _airdropAmount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        vm.assume(_airdropAmount <= strategy.dustThreshold());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        airdrop(ERC20(strategy.COLL()), address(strategy), _airdropAmount);
        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendTrigger_collateralToSell_basefeeTooHigh(uint256 _amount, uint256 _airdropAmount) public {
        test_tendTrigger_collateralToSell(_amount, _airdropAmount);

        vm.prank(management);
        strategy.setMaxGasPriceToTend(0);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendTrigger_collateralGainToClaim(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
        assertFalse(strategy.isCollateralGainToClaim());

        // Earn Collateral, lose principal
        simulateCollateralGain();

        IStabilityPool _stabilityPool = IStabilityPool(strategy.SP());
        uint256 _expectedCollateralGain = _stabilityPool.getDepositorCollGain(address(strategy));
        vm.assume(_expectedCollateralGain > strategy.dustThreshold());

        assertTrue(strategy.isCollateralGainToClaim());

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendTrigger_collateralGainToClaim_basefeeTooHigh(
        uint256 _amount
    ) public {
        test_tendTrigger_collateralGainToClaim(_amount);

        vm.prank(management);
        strategy.setMaxGasPriceToTend(0);

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
    }

    function test_tendTrigger_activeAuction(
        uint256 _amount
    ) public {
        test_tendTrigger_collateralGainToClaim(_amount);

        (bool trigger,) = strategy.tendTrigger();
        assertTrue(trigger);

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Kick auction
        airdrop(ERC20(coll), strategy.AUCTION(), 1);
        auction.kick(coll);

        assertTrue(auction.isActive(coll));
        assertTrue(auction.available(coll) > 0);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        skip(auction.auctionLength() + 1);
        assertFalse(auction.isActive(coll));
        assertEq(auction.available(coll), 0);

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);
    }

    function test_tendAfterCollateralGain(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        uint256 _estimatedTotalAssetsBefore = strategy.estimatedTotalAssets();

        (bool trigger,) = strategy.tendTrigger();
        assertFalse(trigger);
        assertFalse(strategy.isCollateralGainToClaim());

        // Earn Collateral, lose principal
        simulateCollateralGain();

        IStabilityPool _stabilityPool = IStabilityPool(strategy.SP());
        uint256 _expectedCollateralGain = _stabilityPool.getDepositorCollGain(address(strategy));
        vm.assume(_expectedCollateralGain > strategy.dustThreshold());
        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), 0);

        assertLt(strategy.estimatedTotalAssets(), _estimatedTotalAssetsBefore);
        assertTrue(strategy.isCollateralGainToClaim());

        (trigger,) = strategy.tendTrigger();
        assertTrue(trigger);

        // Reporting should fail until we swap the collateral gain
        vm.prank(keeper);
        vm.expectRevert("healthCheck");
        strategy.report();

        // Claim collateral gain and kick auction
        vm.prank(keeper);
        strategy.tend();

        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), 0);
        assertEq(_stabilityPool.getDepositorCollGain(address(strategy)), 0);
        assertEq(ERC20(strategy.COLL()).balanceOf(strategy.AUCTION()), _expectedCollateralGain);

        (trigger,) = strategy.tendTrigger();
        assertFalse(trigger);

        // Simulate swap collateral gain
        vm.prank(keeper);
        uint256 _availableToAuction = IAuction(strategy.AUCTION()).available(strategy.COLL());
        assertEq(_availableToAuction, _expectedCollateralGain);

        // Check auction starting price
        (uint256 _price,) = IPriceFeed(strategy.COLL_PRICE_ORACLE()).fetchPrice();
        uint256 _toAuctionPrice = _availableToAuction * _price / 1e18;
        uint256 _expectedStartingPrice = _toAuctionPrice * 110 / 100 / 1e18;
        assertEq(IAuction(strategy.AUCTION()).startingPrice(), _expectedStartingPrice);

        // Check auction price
        uint256 _expectedPrice = _expectedStartingPrice * 1e36 / _availableToAuction;
        assertApproxEq(IAuction(strategy.AUCTION()).price(strategy.COLL()), _expectedPrice, 1);

        // Add 5% bonus
        uint256 _expectedAssetGain = (_expectedCollateralGain * ethPrice() / 1e18) * 105 / 100;
        airdrop(asset, address(strategy), _expectedAssetGain);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        assertGt(profit, 0);
        assertEq(loss, 0);
        assertGt(strategy.estimatedTotalAssets(), _estimatedTotalAssetsBefore);
    }

    function test_tendSettleAuction(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Kick auction
        airdrop(ERC20(coll), strategy.AUCTION(), 1);
        auction.kick(coll);

        assertTrue(auction.isActive(coll));
        assertTrue(auction.available(coll) > 0);

        // Take auction
        vm.prank(address(auction));
        ERC20(coll).transfer(address(420), 1);

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), 0);

        // Settle auction without kicking a new one
        vm.prank(keeper);
        strategy.tend();

        assertFalse(auction.isActive(coll));
        assertEq(auction.available(coll), 0);
    }

    function test_tendSettleAuctionAndKickNewOne(uint256 _amount, uint256 _airdropAmount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        vm.assume(_airdropAmount > strategy.dustThreshold() && _airdropAmount < maxFuzzAmount);

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Kick auction
        airdrop(ERC20(coll), strategy.AUCTION(), 1);
        auction.kick(coll);

        assertTrue(auction.isActive(coll));
        assertTrue(auction.available(coll) > 0);

        // Take auction
        vm.prank(address(auction));
        ERC20(coll).transfer(address(420), 1);

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), 0);

        // Airdrop enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), address(strategy), _airdropAmount);

        // Settle auction without kicking a new one
        vm.prank(keeper);
        strategy.tend();

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), _airdropAmount);
    }

    function test_tendSettleAuctionAndTooLowToKickNewOne(uint256 _amount, uint256 _airdropAmount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        vm.assume(_airdropAmount <= strategy.dustThreshold());

        address coll = strategy.COLL();
        IAuction auction = IAuction(strategy.AUCTION());

        // Kick auction
        airdrop(ERC20(coll), strategy.AUCTION(), 1);
        auction.kick(coll);

        assertTrue(auction.isActive(coll));
        assertTrue(auction.available(coll) > 0);

        // Take auction
        vm.prank(address(auction));
        ERC20(coll).transfer(address(420), 1);

        assertTrue(auction.isActive(coll));
        assertEq(auction.available(coll), 0);

        // Airdrop not enough collateral rewards to kick a new auction
        airdrop(ERC20(coll), address(strategy), _airdropAmount);

        // Settle auction without kicking a new one
        vm.prank(keeper);
        strategy.tend();

        assertFalse(auction.isActive(coll));
        assertEq(auction.available(coll), 0);
    }

    function test_kickAuction_oracleDown(
        uint256 _airdropAmount
    ) public {
        vm.assume(_airdropAmount > strategy.dustThreshold() && _airdropAmount < maxFuzzAmount);

        // Break the oracle
        skip(10 days);
        (uint256 _price, bool _isOracleDown) = IPriceFeed(strategy.COLL_PRICE_ORACLE()).fetchPrice();
        assertTrue(_isOracleDown);

        // Make sure there's something to kick
        airdrop(ERC20(strategy.COLL()), address(strategy), _airdropAmount);

        // Kick auction
        vm.prank(keeper);
        strategy.tend();

        // Check auction starting price
        uint256 _toAuctionPrice = _airdropAmount * _price / 1e18;
        uint256 _expectedStartingPrice = (_toAuctionPrice * (110 * 1000) / 100) / 1e18;
        assertEq(IAuction(strategy.AUCTION()).startingPrice(), _expectedStartingPrice);

        // Check auction price
        uint256 _availableToAuction = IAuction(strategy.AUCTION()).available(strategy.COLL());
        uint256 _expectedPrice = _expectedStartingPrice * 1e36 / _availableToAuction;
        assertApproxEq(IAuction(strategy.AUCTION()).price(strategy.COLL()), _expectedPrice, 1);
    }

}
