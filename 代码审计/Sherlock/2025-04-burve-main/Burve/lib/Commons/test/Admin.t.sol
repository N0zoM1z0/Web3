// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {AdminLib} from "../src/Util/Admin.sol";

contract AdminTest is PRBTest, StdCheats {
    // solhint-disable

    AdminTestHelper public helper;

    function setUp() public {
        AdminLib.initOwner(msg.sender);
        helper = new AdminTestHelper(this);
    }

    function requireValidation(uint256 right) external view {
        AdminLib.validateRights(right);
    }

    function testOwner() public {
        assertEq(AdminLib.getOwner(), msg.sender);
        AdminLib.validateOwner();

        // But the owner doesn't start with any rights.
        uint256 testRights = 8;
        vm.expectRevert(abi.encodeWithSelector(AdminLib.InsufficientCredentials.selector, msg.sender, testRights, 0));
        AdminLib.validateRights(testRights);

        // But once we give it rights it's okay.
        AdminLib.register(msg.sender, testRights);
        AdminLib.validateRights(testRights);

        // But using a different right will fail.
        uint256 testRights2 = 4;
        vm.expectRevert(
            abi.encodeWithSelector(AdminLib.InsufficientCredentials.selector, msg.sender, testRights2, testRights)
        );
        AdminLib.validateRights(testRights2);

        // And if we deregister even the orgiinal will fail.
        AdminLib.deregister(msg.sender, testRights);
        vm.expectRevert(abi.encodeWithSelector(AdminLib.InsufficientCredentials.selector, msg.sender, testRights, 0));
        AdminLib.validateRights(testRights);

        // We can't reinitialize
        vm.expectRevert(abi.encodeWithSelector(AdminLib.CannotReinitializeOwner.selector, msg.sender));
        AdminLib.initOwner(address(this));

        // But we can reassign
        AdminLib.reassignOwner(address(this));

        // Verify we're still the owner because no one has accepted it yet.
        AdminLib.validateOwner();

        // But once this contract accepts the reassignment.
        vm.prank(address(this));
        AdminLib.acceptOwnership();

        // Verify we're not the owner anymore
        vm.expectRevert(AdminLib.InsufficientCredentials.selector);
        AdminLib.validateOwner();

        assertEq(AdminLib.getOwner(), address(this));
    }

    // Call into this contract using an external contract to see that it gets
    // validated properly.
    function testRegistration() public {
        assertEq(AdminLib.getAdminRights(address(helper)), 0);

        AdminLib.register(address(helper), 2);
        assertEq(AdminLib.getAdminRights(address(helper)), 2);
        helper.validateAs(2);

        vm.expectRevert(abi.encodeWithSelector(AdminLib.InsufficientCredentials.selector, address(helper), 1, 2));

        helper.validateAs(1);

        // We can add more rights.
        AdminLib.register(address(helper), 1);
        assertEq(AdminLib.getAdminRights(address(helper)), 3);
        helper.validateAs(3);
        helper.validateAs(2);
        helper.validateAs(1);

        AdminLib.deregister(address(helper), 2);
        helper.validateAs(1);
        vm.expectRevert(abi.encodeWithSelector(AdminLib.InsufficientCredentials.selector, address(helper), 2, 1));
        helper.validateAs(2);
        vm.expectRevert(abi.encodeWithSelector(AdminLib.InsufficientCredentials.selector, address(helper), 3, 1));
        helper.validateAs(3);

        assertEq(AdminLib.getAdminRights(address(helper)), 1);
    }

    // solhint-enable
}

contract AdminTestHelper {
    AdminTest public tester;

    constructor(AdminTest _tester) {
        tester = _tester;
    }

    function validateAs(uint8 num) public view {
        tester.requireValidation(num);
    }
}
