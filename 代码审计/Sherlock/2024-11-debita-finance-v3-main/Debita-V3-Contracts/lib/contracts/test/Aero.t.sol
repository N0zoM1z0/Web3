// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract AeroTest is BaseTest {
    Aero token;

    function _setUp() public override {
        token = new Aero();
    }

    function testCannotSetMinterIfNotMinter() public {
        vm.prank(address(owner2));
        vm.expectRevert(IAero.NotMinter.selector);
        token.setMinter(address(owner3));
    }

    function testSetMinter() public {
        token.setMinter(address(owner3));

        assertEq(token.minter(), address(owner3));
    }

    function testCannotMintIfNotMinter() public {
        vm.prank(address(owner2));
        vm.expectRevert(IAero.NotMinter.selector);
        token.mint(address(owner2), TOKEN_1);
    }
}
