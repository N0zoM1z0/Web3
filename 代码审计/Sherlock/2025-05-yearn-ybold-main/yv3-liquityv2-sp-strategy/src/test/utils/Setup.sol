// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {LiquityV2SPStrategy as Strategy, ERC20} from "../../Strategy.sol";
import {StrategyFactory} from "../../StrategyFactory.sol";
import {IStrategyInterface} from "../../interfaces/IStrategyInterface.sol";
import {AggregatorV3Interface} from "../../interfaces/AggregatorV3Interface.sol";
import {IStabilityPool} from "../../interfaces/IStabilityPool.sol";
import {IActivePool} from "../../interfaces/IActivePool.sol";

// Inherit the events so they can be checked if desired.
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

interface IFactory {

    function governance() external view returns (address);

    function set_protocol_fee_bps(
        uint16
    ) external;

    function set_protocol_fee_recipient(
        address
    ) external;

}

contract Setup is ExtendedTest, IEvents {

    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public strategy;

    StrategyFactory public strategyFactory;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);
    address public emergencyAdmin = address(5);

    // Contract addresses.
    address public multiTroveGetter = address(0xFA61dB085510C64B83056Db3A7Acf3b6f631D235);
    address public collateralRegistry = address(0xf949982B91C8c61e952B3bA942cbbfaef5386684);
    address public addressesRegistry = address(0x20F7C9ad66983F6523a0881d0f82406541417526); // WETH Address Registry
    address public stabilityPool = address(0x5721cbbd64fc7Ae3Ef44A0A3F9a790A9264Cf9BF); // WETH Stability Pool
    address public collateralPriceOracle = address(0xCC5F8102eb670c89a4a3c567C13851260303c24F); // Liquity WETH Price Oracle
    address public priceOracle = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // Chainlink ETH/USD

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    // Fuzz from $0.1 of 1e18 stable coins up to 10 billion of a 1e18 coin
    uint256 public maxFuzzAmount = 10_000_000_000 ether;
    uint256 public minFuzzAmount = 0.1 ether;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    function setUp() public virtual {
        uint256 _blockNumber = 22_518_294; // Caching for faster tests
        vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), _blockNumber));

        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["BOLD"]);

        // Set decimals
        decimals = asset.decimals();

        strategyFactory = new StrategyFactory(management, performanceFeeRecipient, keeper, emergencyAdmin);

        // Deploy strategy and set variables
        strategy = IStrategyInterface(setUpStrategy());

        factory = strategy.FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(address(asset), "asset");
        vm.label(management, "management");
        vm.label(address(strategy), "strategy");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
    }

    function setUpStrategy() public returns (address) {
        // we save the strategy as a IStrategyInterface to give it the needed interface
        vm.prank(management);
        IStrategyInterface _strategy = IStrategyInterface(
            address(strategyFactory.newStrategy(addressesRegistry, address(asset), "Tokenized Strategy"))
        );

        vm.prank(management);
        _strategy.acceptManagement();

        return address(_strategy);
    }

    function depositIntoStaker(
        IStrategyInterface _asset,
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        vm.prank(_user);
        _asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function depositIntoStrategy(IStrategyInterface _strategy, address _user, uint256 _amount) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(IStrategyInterface _strategy, address _user, uint256 _amount) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public {
        uint256 _assets = _strategy.totalAssets();
        uint256 _balance = ERC20(_strategy.asset()).balanceOf(address(_strategy));
        uint256 _idle = _balance > _assets ? _assets : _balance;
        uint256 _debt = _assets - _idle;
        assertEq(_assets, _totalAssets, "!totalAssets");
        assertEq(_debt, _totalDebt, "!totalDebt");
        assertEq(_idle, _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(ERC20 _asset, address _to, uint256 _amount) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function simulateYieldGain(
        uint256 _amount
    ) public {
        airdrop(ERC20(tokenAddrs["BOLD"]), stabilityPool, _amount);
        IStabilityPool _stabilityPool = IStabilityPool(stabilityPool);
        vm.prank(_stabilityPool.activePool());
        _stabilityPool.triggerBoldRewards(_amount);
        strategy.claim();
    }

    function simulateCollateralGain() public {
        IStabilityPool _stabilityPool = IStabilityPool(stabilityPool);
        uint256 _availableCollateral = IActivePool(_stabilityPool.activePool()).getCollBalance();
        uint256 _collToAdd = _availableCollateral / 10;
        require(_collToAdd >= 1 ether, "simulateCollateralGain: Not enough collateral!");
        uint256 _debtToOffset = _collToAdd * ethPrice() / 1e18;
        uint256 _totalBoldDeposits = _stabilityPool.getTotalBoldDeposits();
        if (_debtToOffset > _totalBoldDeposits) {
            uint256 _amountToDeposit = _debtToOffset - _totalBoldDeposits;
            address _shrimp = address(420);
            airdrop(ERC20(tokenAddrs["BOLD"]), _shrimp, _amountToDeposit);
            vm.prank(_shrimp);
            _stabilityPool.provideToSP(_amountToDeposit, true);
        }
        vm.prank(address(_stabilityPool.troveManager()));
        _stabilityPool.offset(_debtToOffset, _collToAdd);
    }

    function ethPrice() public view returns (uint256) {
        (, int256 price,,,) = AggregatorV3Interface(priceOracle).latestRoundData();
        return uint256(price);
    }

    function setFees(uint16 _protocolFee, uint16 _performanceFee) public {
        address gov = IFactory(factory).governance();

        // Need to make sure there is a protocol fee recipient to set the fee.
        vm.prank(gov);
        IFactory(factory).set_protocol_fee_recipient(gov);

        vm.prank(gov);
        IFactory(factory).set_protocol_fee_bps(_protocolFee);

        vm.prank(management);
        strategy.setPerformanceFee(_performanceFee);
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokenAddrs["BOLD"] = 0x6440f144b7e50D6a8439336510312d2F54beB01D;
    }

}
