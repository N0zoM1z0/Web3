pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup} from "./utils/Setup.sol";

import {StrategyAprOracle} from "../periphery/StrategyAprOracle.sol";

contract OracleTest is Setup {

    StrategyAprOracle public oracle;

    function setUp() public override {
        super.setUp();

        oracle = new StrategyAprOracle(management, multiTroveGetter, collateralRegistry);

        vm.prank(management);
        strategy.allowDeposits();
    }

    function checkOracle(address _strategy, uint256 _delta) public {
        // Check set up
        vm.expectRevert("!governance");
        oracle.setCollateralBias(0, 1e18);

        vm.expectRevert("!_bias");
        vm.prank(management);
        oracle.setCollateralBias(0, 1e18 - 1);

        vm.prank(management);
        oracle.setCollateralBias(0, 1e18);

        assertEq(oracle.collateralBias(0), 1e18);
        assertEq(address(oracle.MULTI_TROVE_GETTER()), multiTroveGetter);
        assertEq(address(oracle.COLLATERAL_REGISTRY()), collateralRegistry);

        uint256 currentApr = oracle.aprAfterDebtChange(_strategy, 0);
        console2.log("currentApr", currentApr);

        // Should be greater than 0 but likely less than 100%
        assertGt(currentApr, 0, "ZERO");
        assertLt(currentApr, 1e18, "+100%");

        uint256 negativeDebtChangeApr = oracle.aprAfterDebtChange(_strategy, -int256(_delta));

        // The apr should go up if deposits go down
        assertLt(currentApr, negativeDebtChangeApr, "negative change");

        uint256 positiveDebtChangeApr = oracle.aprAfterDebtChange(_strategy, int256(_delta));
        assertGt(currentApr, positiveDebtChangeApr, "positive change");

        // Set bias to 20% increase
        vm.prank(management);
        oracle.setCollateralBias(0, 1.2e18);

        // Reported APR should increase by 20% of bias is 1.2e18
        uint256 biasApr = oracle.aprAfterDebtChange(_strategy, 0); // TODO -- get the collateral index dynamically
        assertEq(biasApr, currentApr * 120 / 100);
    }

    function test_oracle(uint256 _amount, uint16 _percentChange) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _percentChange = uint16(bound(uint256(_percentChange), 10, MAX_BPS));

        mintAndDepositIntoStrategy(strategy, user, _amount);

        uint256 _delta = (_amount * _percentChange) / MAX_BPS;

        checkOracle(address(strategy), _delta);
    }

    // TODO: Deploy multiple strategies with different tokens as `asset` to test against the oracle.

}
