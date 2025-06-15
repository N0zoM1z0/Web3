// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../contracts/libraries/TransferHelper.sol";
import "../contracts/mocks/ERC20Mock.sol";

contract TransferHelperTest is Test {
    ERC20Mock token;
    address user;
    address receiver;

    function setUp() public {
        token = new ERC20Mock("Mock Token", "MKT", 18);
        user = address(0x123);
        receiver = address(0x456);
        token.mint(address(this), 1000 ether);
        token.mint(user, 1000 ether);
    }

    function testSafeApprove() public {
        TransferHelper.safeApprove(address(token), receiver, 500 ether);
        assertEq(token.allowance(address(this), receiver), 500 ether);
    }

    function testSafeTransfer() public {
        uint256 before = token.balanceOf(receiver);
        TransferHelper.safeTransfer(address(token), receiver, 200 ether);
        assertEq(token.balanceOf(receiver), before + 200 ether);
    }

    function testSafeTransferFrom() public {
        vm.prank(user);
        token.approve(address(this), 300 ether);
        uint256 before = token.balanceOf(receiver);
        TransferHelper.safeTransferFrom(address(token), user, receiver, 300 ether);
        assertEq(token.balanceOf(receiver), before + 300 ether);
    }

    function testSafeTransferETH() public {
        address payable recipient = payable(receiver);
        vm.deal(address(this), 1 ether);
        uint256 before = recipient.balance;
        TransferHelper.safeTransferETH(recipient, 0.5 ether);
        assertEq(recipient.balance, before + 0.5 ether);
    }

}
