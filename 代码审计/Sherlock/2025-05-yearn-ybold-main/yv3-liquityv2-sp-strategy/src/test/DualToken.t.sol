pragma solidity ^0.8.18;

import {IVault} from "@yearn-vaults/interfaces/IVault.sol";
import {Registry} from "@vault-periphery/registry/Registry.sol";
import {RoleManager} from "@vault-periphery/managers/RoleManager.sol";

import {Accountant, AccountantFactory} from "../periphery/AccountantFactory.sol";

import {LV2SPStakerStrategy as Staker} from "../Staker.sol";
import {StakerFactory} from "../StakerFactory.sol";

import {IAuction} from "../interfaces/IAuction.sol";

import "forge-std/console2.sol";
import {IStabilityPool, IStrategyInterface, ERC20, Setup} from "./utils/Setup.sol";

contract DualTokenTest is Setup {

    IVault public vault; // yBOLD
    Accountant public accountant;
    AccountantFactory public accountantFactory;
    StakerFactory public stakerFactory;
    IStrategyInterface public staker;

    RoleManager public constant ROLE_MANAGER = RoleManager(0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41);
    Registry public constant VAULT_REGISTRY = Registry(0xd40ecF29e001c76Dcc4cC0D9cd50520CE845B038);

    function setUp() public override {
        super.setUp();

        // Deploy staker factory
        stakerFactory = new StakerFactory(management, performanceFeeRecipient, keeper, emergencyAdmin);

        // Deploy allocator vault
        vm.prank(VAULT_REGISTRY.governance());
        vault = IVault(
            VAULT_REGISTRY.newEndorsedVault(
                address(asset),
                "Yearn BOLD",
                "yBOLD",
                management,
                0 // profitMaxUnlockTime
            )
        );

        // Deploy accountant factory
        accountantFactory = new AccountantFactory();

        // Deploy accountant
        accountant = Accountant(
            accountantFactory.newAccountant(
                management, // feeManager
                management, // feeRecipient
                0, // max gain (disabled)
                uint16(MAX_BPS) // max loss (disabled)
            )
        );

        // Set up the vault
        vm.startPrank(management);
        vault.set_role(management, 16383); // ADD_STRATEGY_MANAGER/DEPOSIT_LIMIT_MANAGER/MAX_DEBT_MANAGER/DEBT_MANAGER
        vault.set_role(keeper, 32); // REPORTING_MANAGER
        vault.set_auto_allocate(true);
        vault.set_deposit_limit(type(uint256).max);
        vault.add_strategy(address(strategy));
        vault.update_max_debt_for_strategy(address(strategy), type(uint256).max);
        vault.set_accountant(address(accountant));
        vault.transfer_role_manager(address(ROLE_MANAGER));
        vm.stopPrank();

        // Deploy staker
        staker = IStrategyInterface(stakerFactory.newStrategy(address(vault), "Staked yBOLD Strategy"));

        vm.prank(ROLE_MANAGER.chad());
        ROLE_MANAGER.addNewVault(
            address(vault),
            2 // multi strategy
        );

        vm.startPrank(management);
        accountant.addVault(address(vault));
        accountant.setFeeRecipient(address(staker));
        vm.stopPrank();

        // Make sure no fees on the strategy
        setFees(0, 0);

        // Remove profitMaxUnlockTime
        vm.prank(management);
        strategy.setProfitMaxUnlockTime(0);

        // Allow deposits from the vault
        vm.prank(management);
        strategy.setAllowed(address(vault));
    }

    function test_boldProfit(uint256 _amount, uint16 _profitFactor) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS / 10));

        // Deposit into strategy
        mintAndDepositIntoStrategy(IStrategyInterface(address(vault)), user, _amount);

        assertEq(vault.totalAssets(), _amount, "!totalAssets vault");
        assertEq(vault.totalSupply(), _amount, "!totalSupply vault");
        assertEq(strategy.totalAssets(), _amount, "!totalAssets strategy");
        assertEq(strategy.totalSupply(), _amount, "!totalSupply strategy");

        uint256 pricePerShare = vault.pricePerShare();
        assertEq(pricePerShare, 1 ether, "!pricePerShare vault");

        pricePerShare = strategy.convertToAssets(1 ether);
        assertEq(pricePerShare, 1 ether, "!pricePerShare strategy");

        // Earn Interest
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        simulateYieldGain(toAirdrop);

        // Report profit on strategy
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        assertEq(strategy.totalAssets(), _amount + profit, "!totalAssets strategy after");
        assertEq(strategy.totalSupply(), _amount, "!totalSupply strategy after");

        pricePerShare = strategy.convertToAssets(1 ether);
        assertGt(pricePerShare, 1 ether, "!pricePerShare strategy after");

        // Report profit on vault
        vm.prank(keeper);
        (profit, loss) = vault.process_report(address(strategy));

        // Check return Values
        assertGt(profit, 0, "!profit vault after");
        assertEq(loss, 0, "!loss vault after");

        assertEq(vault.totalAssets(), _amount + profit, "!totalAssets vault after");
        assertEq(vault.totalSupply(), _amount + profit, "!totalSupply vault after");

        pricePerShare = vault.pricePerShare();
        assertEq(pricePerShare, 1 ether, "!pricePerShare vault after");

        skip(1 days); // Skip some time for tapir

        assertEq(vault.totalAssets(), _amount + profit, "!totalAssets vault after - tapir");
        assertEq(vault.totalSupply(), _amount + profit, "!totalSupply vault after - tapir");

        pricePerShare = vault.pricePerShare();
        assertEq(pricePerShare, 1 ether, "!pricePerShare vault after - tapir");

        // Deposit into staker
        depositIntoStaker(IStrategyInterface(address(vault)), staker, user, _amount);

        // Report profit and claim rewards on staker
        vm.prank(keeper);
        (profit, loss) = staker.report();

        // Check return Values
        assertGt(profit, 0, "!profit staker");
        assertEq(loss, 0, "!loss staker");

        // Check staker got the rewards
        assertEq(vault.balanceOf(address(staker)), _amount + profit, "!staker balance");
        assertEq(vault.balanceOf(address(accountant)), 0, "!accountant balance");
    }

    function test_boldLoss(
        uint256 _amount
    ) public {
        vm.assume(_amount > minFuzzAmount * 10 && _amount < maxFuzzAmount);

        // Deposit into strategy
        mintAndDepositIntoStrategy(IStrategyInterface(address(vault)), user, _amount);

        assertEq(vault.totalAssets(), _amount, "!totalAssets vault");
        assertEq(vault.totalSupply(), _amount, "!totalSupply vault");
        assertEq(strategy.totalAssets(), _amount, "!totalAssets strategy");
        assertEq(strategy.totalSupply(), _amount, "!totalSupply strategy");

        uint256 pricePerShare = vault.pricePerShare();
        assertEq(pricePerShare, 1 ether, "!pricePerShare vault");

        pricePerShare = strategy.convertToAssets(1 ether);
        assertEq(pricePerShare, 1 ether, "!pricePerShare strategy");

        // Earn collateral rewards, but report as a loss
        simulateCollateralGain();

        // Allow the strategy to report a loss
        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Report loss on strategy
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertEq(profit, 0, "!profit strategy");
        assertGt(loss, 0, "!loss strategy");

        assertEq(strategy.totalAssets(), _amount - loss, "!totalAssets strategy after");
        assertEq(strategy.totalSupply(), _amount, "!totalSupply strategy after");

        pricePerShare = strategy.convertToAssets(1 ether);
        assertLt(pricePerShare, 1 ether, "!pricePerShare strategy after");

        // Report loss on vault
        vm.prank(keeper);
        (profit, loss) = vault.process_report(address(strategy));

        // Check return Values
        assertEq(profit, 0, "!profit vault");
        assertGt(loss, 0, "!loss vault");

        assertEq(vault.totalAssets(), _amount - loss, "!totalAssets vault after");
        assertEq(vault.totalSupply(), _amount, "!totalSupply vault after");

        pricePerShare = vault.pricePerShare();
        assertLt(pricePerShare, 1 ether, "!pricePerShare vault after");

        IStabilityPool _stabilityPool = IStabilityPool(strategy.SP());
        uint256 _expectedCollateralGain = _stabilityPool.getDepositorCollGain(address(strategy));
        vm.assume(_expectedCollateralGain > strategy.dustThreshold());
        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), 0);

        // Claim collateral gain and kick auction
        vm.prank(keeper);
        strategy.tend();

        assertEq(ERC20(strategy.COLL()).balanceOf(address(strategy)), 0);
        assertEq(_stabilityPool.getDepositorCollGain(address(strategy)), 0);
        assertEq(ERC20(strategy.COLL()).balanceOf(strategy.AUCTION()), _expectedCollateralGain);

        // Simulate swap collateral gain
        vm.prank(keeper);
        uint256 _availableToAuction = IAuction(strategy.AUCTION()).available(strategy.COLL());
        assertEq(_availableToAuction, _expectedCollateralGain);

        // Add 5% bonus
        uint256 _expectedAssetGain = (_expectedCollateralGain * ethPrice() / 1e18) * 105 / 100;
        airdrop(asset, address(strategy), _expectedAssetGain);

        // Report profit on strategy
        vm.prank(keeper);
        (profit, loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit strategy after");
        assertEq(loss, 0, "!loss strategy after");

        assertGt(strategy.totalAssets(), _amount, "!totalAssets strategy after2");
        assertEq(strategy.totalSupply(), _amount, "!totalSupply strategy after2");

        pricePerShare = strategy.convertToAssets(1 ether);
        assertGt(pricePerShare, 1 ether, "!pricePerShare strategy after2");

        // Report profit on vault
        vm.prank(keeper);
        (profit, loss) = vault.process_report(address(strategy));

        // Check return Values
        assertGt(profit, 0, "!profit vault after");
        assertEq(loss, 0, "!loss vault after");

        assertGt(vault.totalAssets(), _amount, "!totalAssets vault after2");
        assertGt(vault.totalSupply(), _amount, "!totalSupply vault after2");

        pricePerShare = vault.pricePerShare();
        assertApproxEq(pricePerShare, 1 ether, 1, "!pricePerShare vault after2");

        // Deposit into staker
        depositIntoStaker(IStrategyInterface(address(vault)), staker, user, _amount);

        // Report profit and claim rewards on staker
        vm.prank(keeper);
        (profit, loss) = staker.report();

        // Check return Values
        assertGt(profit, 0, "!profit staker");
        assertEq(loss, 0, "!loss staker");

        // Check staker got the rewards
        assertGt(vault.balanceOf(address(staker)), _amount, "!staker balance");
        assertEq(vault.balanceOf(address(accountant)), 0, "!accountant balance");
    }

    function test_notAllowedCantDeposit(uint256 _amount, address _user) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        vm.assume(_user != address(0) && _user != address(vault));

        airdrop(asset, _user, _amount);

        vm.prank(_user);
        asset.approve(address(strategy), _amount);

        vm.expectRevert("ERC4626: deposit more than max");
        vm.prank(_user);
        strategy.deposit(_amount, _user);

        vm.prank(management);
        strategy.setAllowed(_user);

        vm.prank(_user);
        strategy.deposit(_amount, _user);
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");
    }

}
