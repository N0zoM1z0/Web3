// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Setup, ERC20} from "./utils/Setup.sol";

contract SettersTest is Setup {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_AllowDeposits() public {
        vm.expectRevert("!management");
        strategy.allowDeposits();

        assertFalse(strategy.openDeposits());
        vm.prank(management);
        strategy.allowDeposits();
        assertTrue(strategy.openDeposits());
    }

    function test_SetMaxGasPriceToTend(
        uint256 _maxGasPriceToTend
    ) public {
        vm.expectRevert("!management");
        strategy.setMaxGasPriceToTend(_maxGasPriceToTend);

        vm.prank(management);
        strategy.setMaxGasPriceToTend(_maxGasPriceToTend);
        assertEq(strategy.maxGasPriceToTend(), _maxGasPriceToTend);
    }

    function test_SetBufferPercentage(
        uint256 _bufferPercentage
    ) public {
        vm.assume(_bufferPercentage >= strategy.MIN_BUFFER_PERCENTAGE());

        vm.expectRevert("!management");
        strategy.setBufferPercentage(_bufferPercentage);

        vm.prank(management);
        strategy.setBufferPercentage(_bufferPercentage);
        assertEq(strategy.bufferPercentage(), _bufferPercentage);
    }

    function test_SetBufferPercentage_TooLow(
        uint256 _bufferPercentage
    ) public {
        vm.assume(_bufferPercentage < strategy.MIN_BUFFER_PERCENTAGE());

        vm.expectRevert("!minBuffer");
        vm.prank(management);
        strategy.setBufferPercentage(_bufferPercentage);
    }

    function test_SetDustThreshold(
        uint256 _dustThreshold
    ) public {
        vm.assume(_dustThreshold >= strategy.MIN_DUST_THRESHOLD());

        vm.expectRevert("!management");
        strategy.setDustThreshold(_dustThreshold);

        vm.prank(management);
        strategy.setDustThreshold(_dustThreshold);
        assertEq(strategy.dustThreshold(), _dustThreshold);
    }

    function test_SetDustThreshold_TooLow(
        uint256 _dustThreshold
    ) public {
        vm.assume(_dustThreshold < strategy.MIN_DUST_THRESHOLD());

        vm.expectRevert("!minDust");
        vm.prank(management);
        strategy.setDustThreshold(_dustThreshold);
    }

    function test_SetAllowed(
        address _address
    ) public {
        vm.expectRevert("!management");
        strategy.setAllowed(_address);

        assertFalse(strategy.allowed(_address));
        vm.prank(management);
        strategy.setAllowed(_address);
        assertTrue(strategy.allowed(_address));
    }

    function test_Sweep(
        uint256 _amount
    ) public {
        vm.assume(_amount > 0);

        ERC20 _token = ERC20(tokenAddrs["YFI"]);
        vm.expectRevert("!management");
        strategy.sweep(_token);

        vm.startPrank(management);

        ERC20 _asset = ERC20(strategy.asset());
        vm.expectRevert("!token");
        strategy.sweep(_asset);

        ERC20 _coll = ERC20(strategy.COLL());
        vm.expectRevert("!token");
        strategy.sweep(_coll);

        vm.expectRevert("!balance");
        strategy.sweep(ERC20(tokenAddrs["LINK"]));

        uint256 _balanceBefore = _token.balanceOf(management);
        airdrop(_token, address(strategy), _amount);
        strategy.sweep(_token);
        assertEq(_token.balanceOf(management), _balanceBefore + _amount);
        assertEq(_token.balanceOf(address(strategy)), 0);

        vm.stopPrank();
    }

}
