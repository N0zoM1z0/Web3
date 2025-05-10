// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {AdminLib} from "Commons/Util/Admin.sol";

import {IBGTExchanger} from "../../../src/integrations/BGTExchange/IBGTExchanger.sol";
import {BGTExchanger} from "../../../src/integrations/BGTExchange/BGTExchanger.sol";
import {TransferHelper} from "../../../src/TransferHelper.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

/// Exposes methods to manipulate internal state of the BGT Exchanger for testing purposes.
contract ExposedBGTExchanger is BGTExchanger {
    constructor(address _bgtToken) BGTExchanger(_bgtToken) {}

    function setOwed(address caller, uint256 amount) external {
        owed[caller] = amount;
    }

    function setWithdrawn(address caller, uint256 amount) external {
        withdrawn[caller] = amount;
    }
}

contract BGTExchangerTest is Test {
    BGTExchanger bgtExchanger;
    address owner;
    address alice;
    MockERC20 ibgt;
    MockERC20 usdc;
    MockERC20 eth;

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");

        ibgt = new MockERC20("ibgt", "ibgt", 18);
        usdc = new MockERC20("usdc", "usdc", 6);
        eth = new MockERC20("eth", "eth", 18);

        vm.startPrank(owner);
        bgtExchanger = new BGTExchanger(address(ibgt));
        vm.stopPrank();
    }

    // -- constructor tests ----

    function testCreate() public view {
        assertEq(bgtExchanger.bgtToken(), address(ibgt));
    }

    // -- exchange tests ----

    function testExchangeBGTBalanceIsMoreThanExchangedBGTAmount() public {
        // add alice as exchanger
        vm.startPrank(owner);
        bgtExchanger.addExchanger(alice);
        vm.stopPrank();

        // set USDC exchange rate
        vm.startPrank(owner);
        bgtExchanger.setRate(address(usdc), (2 << 128)); // 1:2
        vm.stopPrank();

        // fund 100e18 iBGT
        deal(address(ibgt), address(this), 100e18);
        ibgt.approve(address(bgtExchanger), 100e18);
        bgtExchanger.fund(100e18);

        // exchange USDC for iBGT
        vm.startPrank(alice);

        deal(address(usdc), alice, 1100);
        usdc.approve(address(bgtExchanger), 1000);

        (uint256 bgtAmount, uint256 spendAmount) = bgtExchanger.exchange(
            address(usdc),
            1000
        );

        vm.stopPrank();

        // check returned amounts
        assertEq(bgtAmount, 2000, "bgtAmount");
        assertEq(spendAmount, 1000, "spendAmount");

        // check state
        assertEq(bgtExchanger.bgtBalance(), 100e18 - 2000, "bgtBalance");
        assertEq(bgtExchanger.owed(alice), 2000, "owed");

        // check balances
        assertEq(usdc.balanceOf(alice), 100, "alice USDC");
        assertEq(usdc.balanceOf(address(bgtExchanger)), 1000, "exchanger USDC");
    }

    function testExchangeBGTBalanceIsLessThanExchangedBGTAmount() public {
        // add alice as exchanger
        vm.startPrank(owner);
        bgtExchanger.addExchanger(alice);
        vm.stopPrank();

        // set USDC exchange rate
        vm.startPrank(owner);
        bgtExchanger.setRate(address(usdc), (2 << 128)); // 1:2
        vm.stopPrank();

        // fund 100e18 iBGT
        deal(address(ibgt), address(this), 1000);
        ibgt.approve(address(bgtExchanger), 1000);
        bgtExchanger.fund(1000);

        // exchange USDC for iBGT
        vm.startPrank(alice);

        deal(address(usdc), alice, 1100);
        usdc.approve(address(bgtExchanger), 1000);

        (uint256 bgtAmount, uint256 spendAmount) = bgtExchanger.exchange(
            address(usdc),
            1000
        );

        vm.stopPrank();

        // check returned amounts
        assertEq(bgtAmount, 1000, "bgtAmount");
        assertEq(spendAmount, 500, "spendAmount");

        // check state
        assertEq(bgtExchanger.bgtBalance(), 0, "bgtBalance");
        assertEq(bgtExchanger.owed(alice), 1000, "owed");

        // check balances
        assertEq(usdc.balanceOf(alice), 600, "alice USDC");
        assertEq(usdc.balanceOf(address(bgtExchanger)), 500, "exchanger USDC");
    }

    function testExchangeBGTBalanceIsMoreThanExchangedBGTAmountCheckingRateRounding()
        public
    {
        // add alice as exchanger
        vm.startPrank(owner);
        bgtExchanger.addExchanger(alice);
        vm.stopPrank();

        // set USDC exchange rate
        vm.startPrank(owner);
        bgtExchanger.setRate(
            address(usdc),
            113427455640312814857969558651062452224
        ); // 3:1
        vm.stopPrank();

        // fund 100e18 iBGT
        deal(address(ibgt), address(this), 100e18);
        ibgt.approve(address(bgtExchanger), 100e18);
        bgtExchanger.fund(100e18);

        // exchange USDC for iBGT
        vm.startPrank(alice);

        deal(address(usdc), alice, 1100);
        usdc.approve(address(bgtExchanger), 1000);

        (uint256 bgtAmount, uint256 spendAmount) = bgtExchanger.exchange(
            address(usdc),
            1000
        );

        vm.stopPrank();

        // check returned amounts
        assertEq(bgtAmount, 333, "bgtAmount"); // confirms rounding down
        assertEq(spendAmount, 1000, "spendAmount");

        // check state
        assertEq(bgtExchanger.bgtBalance(), 100e18 - 333, "bgtBalance");
        assertEq(bgtExchanger.owed(alice), 333);

        // check balances
        assertEq(usdc.balanceOf(alice), 100, "alice USDC");
        assertEq(usdc.balanceOf(address(bgtExchanger)), 1000, "exchanger USDC");
    }

    function testExchangeBGTBalanceIsLessThanExchangedBGTAmountCheckingRateRounding()
        public
    {
        // add alice as exchanger
        vm.startPrank(owner);
        bgtExchanger.addExchanger(alice);
        vm.stopPrank();

        // set USDC exchange rate
        vm.startPrank(owner);
        bgtExchanger.setRate(
            address(usdc),
            113427455640312814857969558651062452224
        ); // 3:1
        vm.stopPrank();

        // fund 100e18 iBGT
        deal(address(ibgt), address(this), 200);
        ibgt.approve(address(bgtExchanger), 200);
        bgtExchanger.fund(200);

        // exchange USDC for iBGT
        vm.startPrank(alice);

        deal(address(usdc), alice, 1100);
        usdc.approve(address(bgtExchanger), 1000);

        (uint256 bgtAmount, uint256 spendAmount) = bgtExchanger.exchange(
            address(usdc),
            1000
        );

        vm.stopPrank();

        // check returned amounts
        assertEq(bgtAmount, 200, "bgtAmount");
        assertEq(spendAmount, 601, "spendAmount"); // confirms rounding up

        // check state
        assertEq(bgtExchanger.bgtBalance(), 0, "bgtBalance");
        assertEq(bgtExchanger.owed(alice), 200, "owed");

        // check balances
        assertEq(usdc.balanceOf(alice), 499, "alice USDC");
        assertEq(usdc.balanceOf(address(bgtExchanger)), 601, "exchanger USDC");
    }

    function testExchangeRateIsZero() public {
        // add alice as exchanger
        vm.startPrank(owner);
        bgtExchanger.addExchanger(alice);
        vm.stopPrank();

        // check rate is zero
        assertEq(bgtExchanger.rate(address(usdc)), 0);

        // exchange USDC for iBGT
        vm.startPrank(alice);
        (uint256 bgtAmount, uint256 spendAmount) = bgtExchanger.exchange(
            address(usdc),
            200e6
        );
        vm.stopPrank();

        // check returned amounts
        assertEq(bgtAmount, 0);
        assertEq(spendAmount, 0);
    }

    function testExchangeAmountIsZero() public {
        // add alice as exchanger
        vm.startPrank(owner);
        bgtExchanger.addExchanger(alice);
        vm.stopPrank();

        // set USDC exchange rate
        vm.startPrank(owner);
        bgtExchanger.setRate(address(usdc), (2 << 128)); // 1:2
        vm.stopPrank();

        // fund 100e18 iBGT
        deal(address(ibgt), address(this), 100e18);
        ibgt.approve(address(bgtExchanger), 100e18);
        bgtExchanger.fund(100e18);

        // exchange USDC for iBGT
        vm.startPrank(alice);

        (uint256 bgtAmount, uint256 spendAmount) = bgtExchanger.exchange(
            address(usdc),
            0
        );

        vm.stopPrank();

        // check returned amounts
        assertEq(bgtAmount, 0);
        assertEq(spendAmount, 0);

        // check state
        assertEq(bgtExchanger.bgtBalance(), 100e18);
        assertEq(bgtExchanger.owed(alice), 0);
    }

    function testRevertExchangeNoExchangePermissions() public {
        vm.expectRevert(BGTExchanger.NoExchangePermissions.selector);
        bgtExchanger.exchange(address(usdc), 1e18);
    }

    // -- getOwed tests ----

    function testGetOwedZero() public {
        assertEq(bgtExchanger.owed(alice), 0);
        assertEq(bgtExchanger.getOwed(alice), 0);

        assertEq(bgtExchanger.owed(owner), 0);
        assertEq(bgtExchanger.getOwed(owner), 0);
    }

    function testGetOwedBackupOnly() public {
        // set backup
        vm.startPrank(owner);
        address backup = makeAddr("backup");
        bgtExchanger.setBackup(backup);
        vm.stopPrank();

        // alice is owed 10e18
        vm.mockCall(
            address(backup),
            abi.encodeWithSelector(IBGTExchanger.getOwed.selector, alice),
            abi.encode(10e18)
        );
        assertEq(bgtExchanger.owed(alice), 0);
        assertEq(bgtExchanger.getOwed(alice), 10e18);

        // owner is owed 4e18
        vm.mockCall(
            address(backup),
            abi.encodeWithSelector(IBGTExchanger.getOwed.selector, owner),
            abi.encode(4e18)
        );
        assertEq(bgtExchanger.owed(owner), 0);
        assertEq(bgtExchanger.getOwed(owner), 4e18);
    }

    function testGetOwedNoBackup() public {
        ExposedBGTExchanger exposedBgtExchanger = new ExposedBGTExchanger(
            address(ibgt)
        );

        // check alice
        exposedBgtExchanger.setOwed(alice, 10e18);
        assertEq(exposedBgtExchanger.getOwed(alice), 10e18);

        // check owner
        exposedBgtExchanger.setOwed(owner, 4e18);
        assertEq(exposedBgtExchanger.getOwed(owner), 4e18);
    }

    function testGetOwedWithBackup() public {
        ExposedBGTExchanger exposedBgtExchanger = new ExposedBGTExchanger(
            address(ibgt)
        );

        // set backup
        address backup = makeAddr("backup");
        exposedBgtExchanger.setBackup(backup);

        // alice is owed 10e18 by Backup
        vm.mockCall(
            address(backup),
            abi.encodeWithSelector(IBGTExchanger.getOwed.selector, alice),
            abi.encode(10e18)
        );

        // owner is owed 4e18 by Backup
        vm.mockCall(
            address(backup),
            abi.encodeWithSelector(IBGTExchanger.getOwed.selector, owner),
            abi.encode(4e18)
        );

        // check alice
        exposedBgtExchanger.setOwed(alice, 2e18);
        assertEq(exposedBgtExchanger.getOwed(alice), 12e18);

        // check owner
        exposedBgtExchanger.setOwed(owner, 7e18);
        assertEq(exposedBgtExchanger.getOwed(owner), 11e18);
    }

    function testGetOwedNoBackupDiscountedByWithdrawnAmount() public {
        ExposedBGTExchanger exposedBgtExchanger = new ExposedBGTExchanger(
            address(ibgt)
        );

        // check alice
        exposedBgtExchanger.setOwed(alice, 10e18);
        exposedBgtExchanger.setWithdrawn(alice, 8e18);
        assertEq(exposedBgtExchanger.getOwed(alice), 2e18);

        // check owner
        exposedBgtExchanger.setOwed(owner, 4e18);
        exposedBgtExchanger.setWithdrawn(owner, 4e18);
        assertEq(exposedBgtExchanger.getOwed(owner), 0);
    }

    function testGetOwedWithBackupDiscountedByWithdrawnAmount() public {
        ExposedBGTExchanger exposedBgtExchanger = new ExposedBGTExchanger(
            address(ibgt)
        );

        // set backup
        address backup = makeAddr("backup");
        exposedBgtExchanger.setBackup(backup);

        // alice is owed 10e18 by Backup
        vm.mockCall(
            address(backup),
            abi.encodeWithSelector(IBGTExchanger.getOwed.selector, alice),
            abi.encode(10e18)
        );

        // owner is owed 4e18 by Backup
        vm.mockCall(
            address(backup),
            abi.encodeWithSelector(IBGTExchanger.getOwed.selector, owner),
            abi.encode(4e18)
        );

        // check alice
        exposedBgtExchanger.setOwed(alice, 2e18);
        exposedBgtExchanger.setWithdrawn(alice, 8e18);
        assertEq(exposedBgtExchanger.getOwed(alice), 4e18);

        // check owner
        exposedBgtExchanger.setOwed(owner, 7e18);
        exposedBgtExchanger.setWithdrawn(owner, 11e18);
        assertEq(exposedBgtExchanger.getOwed(owner), 0);
    }

    // -- withdraw tests ----

    function testWithdraw() public {
        // simulate funding
        deal(address(ibgt), address(bgtExchanger), 20e18);

        // set backup
        vm.startPrank(owner);
        address backup = makeAddr("backup");
        bgtExchanger.setBackup(backup);
        vm.stopPrank();

        // alice is owed 10e18 by Backup
        vm.mockCall(
            address(backup),
            abi.encodeWithSelector(IBGTExchanger.getOwed.selector, alice),
            abi.encode(10e18)
        );

        // alice withdraws 7e18
        vm.startPrank(alice);
        bgtExchanger.withdraw(owner, 7e18);
        vm.stopPrank();

        // check withdraw amounts
        assertEq(ibgt.balanceOf(owner), 7e18);
        assertEq(ibgt.balanceOf(address(bgtExchanger)), 13e18);
        assertEq(bgtExchanger.withdrawn(alice), 7e18);
    }

    function testRevertWithdrawMoreThanOwed() public {
        vm.expectRevert(BGTExchanger.InsufficientOwed.selector);
        bgtExchanger.withdraw(address(alice), 1e18);
    }

    // -- addExchanger tests ----

    function testAddExchanger() public {
        vm.startPrank(owner);

        bgtExchanger.addExchanger(alice);
        assertTrue(bgtExchanger.isExchanger(alice));

        assertFalse(bgtExchanger.isExchanger(owner));

        vm.stopPrank();
    }

    function testRevertAddExchangerNotOwner() public {
        vm.expectRevert(AdminLib.NotOwner.selector);
        bgtExchanger.addExchanger(address(this));
    }

    // -- removeExchanger tests ----

    function testRemoveExchanger() public {
        vm.startPrank(owner);

        bgtExchanger.addExchanger(alice);
        assertTrue(bgtExchanger.isExchanger(alice));

        bgtExchanger.removeExchanger(alice);
        assertFalse(bgtExchanger.isExchanger(alice));

        vm.stopPrank();
    }

    function testRevertRemoveExchangerNotOwner() public {
        vm.expectRevert(AdminLib.NotOwner.selector);
        bgtExchanger.removeExchanger(address(this));
    }

    // -- setRate tests ----

    function testSetRate() public {
        vm.startPrank(owner);

        // set USDC rate
        bgtExchanger.setRate(address(usdc), (2 << 128));
        assertEq(bgtExchanger.rate(address(usdc)), (2 << 128));

        // set USDC rate to zero
        bgtExchanger.setRate(address(usdc), 0);
        assertEq(bgtExchanger.rate(address(usdc)), 0);

        // set ETH rate
        bgtExchanger.setRate(address(eth), (4 << 128));
        assertEq(bgtExchanger.rate(address(eth)), (4 << 128));

        vm.stopPrank();
    }

    function testRevertSetRateNotOwner() public {
        vm.expectRevert(AdminLib.NotOwner.selector);
        bgtExchanger.setRate(address(usdc), (2 << 128));
    }

    // -- sendBalance tests ----

    function testSendBalanceRecoverTrackedBGT() public {
        // fund exchanger
        deal(address(ibgt), address(this), 2e18);
        ibgt.approve(address(bgtExchanger), 2e18);
        bgtExchanger.fund(2e18);

        vm.startPrank(owner);

        // verfiy iBGT balance
        assertEq(bgtExchanger.bgtBalance(), 2e18);

        // send iBGT to alice
        uint256 recipientBalance = ibgt.balanceOf(alice);
        bgtExchanger.sendBalance(address(ibgt), alice, 2e18);
        assertEq(ibgt.balanceOf(alice), recipientBalance + 2e18);

        // verfiy iBGT balance is unchanged
        assertEq(bgtExchanger.bgtBalance(), 2e18);

        vm.stopPrank();
    }

    function testSendBalanceRecoverUntrackedBGT() public {
        // simulate sending iBGT to exchanger
        deal(address(ibgt), address(bgtExchanger), 10e18);

        vm.startPrank(owner);

        // verfiy iBGT balance
        assertEq(bgtExchanger.bgtBalance(), 0);

        // send iBGT to alice
        uint256 recipientBalance = ibgt.balanceOf(alice);
        bgtExchanger.sendBalance(address(ibgt), alice, 10e18);
        assertEq(ibgt.balanceOf(alice), recipientBalance + 10e18);

        // verfiy iBGT balance is unchanged
        assertEq(bgtExchanger.bgtBalance(), 0);

        vm.stopPrank();
    }

    function testSendBalanceRecoverNonBGT() public {
        // simulate sending USDC to exchanger
        deal(address(usdc), address(bgtExchanger), 10e18);

        vm.startPrank(owner);

        // send USDC to alice
        uint256 recipientBalance = usdc.balanceOf(alice);
        bgtExchanger.sendBalance(address(usdc), alice, 10e18);
        assertEq(usdc.balanceOf(alice), recipientBalance + 10e18);

        vm.stopPrank();
    }

    function testRevertSendBalanceNotOwner() public {
        vm.expectRevert(AdminLib.NotOwner.selector);
        bgtExchanger.sendBalance(address(ibgt), address(this), 10e18);
    }

    // -- fund tests ----

    function testFund() public {
        // deal test contract BGT
        deal(address(ibgt), address(this), 10e18);
        ibgt.approve(address(bgtExchanger), 10e18);

        // transfer 1e18
        uint256 balanceSender = ibgt.balanceOf(address(this));
        uint256 balanceExchanger = ibgt.balanceOf(address(bgtExchanger));
        bgtExchanger.fund(1e18);

        assertEq(bgtExchanger.bgtBalance(), 1e18);
        assertEq(ibgt.balanceOf(address(this)), balanceSender - 1e18);
        assertEq(
            ibgt.balanceOf(address(bgtExchanger)),
            balanceExchanger + 1e18
        );

        // transfer 9e18
        balanceSender = ibgt.balanceOf(address(this));
        balanceExchanger = ibgt.balanceOf(address(bgtExchanger));
        bgtExchanger.fund(9e18);

        assertEq(bgtExchanger.bgtBalance(), 10e18);
        assertEq(ibgt.balanceOf(address(this)), balanceSender - 9e18);
        assertEq(
            ibgt.balanceOf(address(bgtExchanger)),
            balanceExchanger + 9e18
        );
    }

    // -- setBackup tests ----

    function testSetBackup() public {
        vm.startPrank(owner);

        address backup = makeAddr("backup");
        bgtExchanger.setBackup(backup);
        assertEq(address(bgtExchanger.backupEx()), backup);

        vm.stopPrank();
    }

    function testRevertSetBackupNotOwner() public {
        vm.expectRevert(AdminLib.NotOwner.selector);
        bgtExchanger.setBackup(address(0x0));
    }
}
