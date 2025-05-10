// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright 2023 Itos Inc.
pragma solidity ^0.8.17;

import { console2 } from "forge-std/console2.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { RFTLib, RFTPayer, IRFTPayer, IERC165 } from "src/Util/RFT.sol";
import { MintableERC20 } from "src/ERC/ERC20.u.sol";
import { ContractLib } from "src/Util/Contract.sol";
import { Auto165 } from "src/ERC/Auto165.sol";

contract MockRFTPayer is RFTPayer, Auto165 {
    function tokenRequestCB(
        address[] calldata tokens,
        int256[] calldata requests,
        bytes calldata
    ) external returns (bytes memory cbData) {
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (requests[i] > 0) {
                MintableERC20(tokens[i]).mint(msg.sender, uint256(requests[i]));
            }
        }
    }
}

contract MockRFTDataPayer is RFTPayer, Auto165 {
    bytes _cbData;
    constructor(bytes memory data) {
        _cbData = data;
    }

    function tokenRequestCB(
        address[] calldata tokens,
        int256[] calldata requests,
        bytes calldata
    ) external returns (bytes memory) {
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (requests[i] > 0) {
                MintableERC20(tokens[i]).mint(msg.sender, uint256(requests[i]));
            }
        }

        return _cbData;
    }
}

contract RFTNonPayer is RFTPayer, Auto165 {
    function tokenRequestCB(
        address[] calldata tokens,
        int256[] calldata requests,
        bytes calldata
    ) external returns (bytes memory cbData) {}
}

contract RFTMultiplePayer is RFTPayer, Auto165 {
    RFTTestHelper public helper;

    constructor(address _helper) {
        helper = RFTTestHelper(_helper);
    }

    function tokenRequestCB(
        address[] calldata tokens,
        int256[] calldata,
        bytes calldata data
    ) external returns (bytes memory cbData) {
        (uint256 pay, int256 nextRequest, bytes memory nextData) = abi.decode(data, (uint256, int256, bytes));
        if (pay > 0) {
            MintableERC20(tokens[0]).mint(msg.sender, pay);
        }
        if (nextRequest != 0) {
            helper.reentrantSettle(address(this), nextRequest, nextData);
        }
    }
}

contract RFTSettlePayer is RFTPayer, Auto165 {
    RFTTestHelper public helper;

    constructor(address _helper) {
        helper = RFTTestHelper(_helper);
    }

    function tokenRequestCB(
        address[] calldata,
        int256[] calldata request,
        bytes calldata data
    ) external returns (bytes memory cbData) {
        bool reentrant = abi.decode(data, (bool));
        if (reentrant) {
            helper.reentrantSettle(address(this), request[0], abi.encode(false));
        } else {
            helper.settle(address(this), request[0]);
        }
    }
}

/// @dev We need this contract to run the revert calls due to a Foundry bug
/// where if the testing contract reverts the test prematurely stops.
contract RFTTestHelper {
    address public token;

    constructor(address _token) {
        token = _token;
    }

    function request(address payer, int256 amount) external returns (bytes memory data) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory amounts = new int256[](1);
        amounts[0] = amount;
        bytes memory nulldata;
        return RFTLib.request(payer, tokens, amounts, nulldata);
    }

    function requestOrTransfer(address payer, int256 amount) external returns (bytes memory data) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory amounts = new int256[](1);
        amounts[0] = amount;
        bytes memory nulldata;
        return RFTLib.requestOrTransfer(payer, tokens, amounts, nulldata);
    }

    function settle(address payer, int256 amount) external returns (int256[] memory actualDeltas, bytes memory data) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory amounts = new int256[](1);
        amounts[0] = amount;
        bytes memory nulldata;
        return RFTLib.settle(payer, tokens, amounts, nulldata);
    }

    function settle(
        address payer,
        int256 amount,
        bytes calldata data
    ) external returns (int256[] memory actualDeltas, bytes memory cbData) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory amounts = new int256[](1);
        amounts[0] = amount;
        return RFTLib.settle(payer, tokens, amounts, data);
    }

    function reentrantSettle(address payer, int256 amount, bytes memory insts) external returns (bytes memory data) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        int256[] memory amounts = new int256[](1);
        amounts[0] = amount;
        return RFTLib.reentrantSettle(payer, tokens, amounts, insts);
    }
}

contract RFTTest is PRBTest, StdCheats {
    MintableERC20 public token;
    address public human;
    address public payer;
    address public nonPayer;
    RFTTestHelper public helper;
    address public multiplePayer;
    address public settlePayer;
    address public dataPayer;

    function setUp() public {
        token = new MintableERC20("eth", "ETH");
        human = address(0x1337133713371337);
        payer = address(new MockRFTPayer());
        nonPayer = address(new RFTNonPayer());
        helper = new RFTTestHelper(address(token));
        multiplePayer = address(new RFTMultiplePayer(address(helper)));
        settlePayer = address(new RFTSettlePayer(address(helper)));
        dataPayer = address(new MockRFTDataPayer(abi.encode(uint256(7))));
    }

    function testRequests() public {
        token.mint(human, 1 ether);

        // Request
        // request from human fails
        vm.expectRevert(ContractLib.NotAContract.selector);
        helper.request(human, 1);
        // But contract succeeds
        helper.request(payer, 1);
        // This contract fails with EVM Error
        vm.expectRevert();
        helper.request(address(this), 1);

        // Request or Transfer
        // Give approval
        vm.prank(human);
        token.approve(address(helper), 1 ether);
        helper.requestOrTransfer(human, 1 gwei);
        // payer still works
        helper.requestOrTransfer(payer, 1 gwei);
        // This contract fails.
        vm.expectRevert();
        helper.requestOrTransfer(address(this), 1 gwei);

        // Request or fail
        assertFalse(RFTLib.isSupported(human));
        // Non payer doesn't pay but still supports interface.
        assertTrue(RFTLib.isSupported(nonPayer));
        assertTrue(RFTLib.isSupported(payer));
        // This contract doesnt have ERC165, but doesn't error when checking support.
        assertFalse(RFTLib.isSupported(address(this)));
    }

    function testSettle() public {
        token.mint(human, 1 ether);
        vm.prank(human);
        token.approve(address(helper), 1 ether);

        token.mint(payer, 1 ether);
        token.mint(address(helper), 1 ether);

        helper.settle(human, -1 gwei);
        helper.settle(human, 1 gwei);

        helper.settle(payer, -1 gwei);
        helper.settle(payer, 1 gwei);

        helper.settle(nonPayer, -1 gwei);
        vm.expectRevert(abi.encodeWithSelector(RFTLib.InsufficientReceive.selector, address(token), 1 gwei, 0));
        helper.settle(nonPayer, 1 gwei);

        // Test reentrancy
        vm.expectRevert(RFTLib.ReentrancyLocked.selector);
        helper.settle(settlePayer, 1 gwei, abi.encode(false));

        vm.expectRevert(RFTLib.ReentrancyLocked.selector);
        helper.settle(settlePayer, 1 gwei, abi.encode(true));
    }

    function testReentrantSettle() public {
        token.mint(human, 1 ether);
        vm.prank(human);
        token.approve(address(helper), 1 ether);

        token.mint(payer, 1 ether);
        token.mint(address(helper), 1 ether);

        bytes memory nulldata;

        // Test multiple receives. Starting balance is 0.
        bytes memory first = abi.encode(uint256(10 gwei), int256(0), nulldata);
        bytes memory second = abi.encode(uint256(0), int256(1 gwei), first);
        helper.reentrantSettle(multiplePayer, 1 gwei, second);

        first = abi.encode(uint256(1 gwei), int256(0), nulldata);
        second = abi.encode(uint256(0), int256(1 gwei), first);
        vm.expectRevert(abi.encodeWithSelector(RFTLib.InsufficientReceive.selector, address(token), 2 gwei, 1 gwei));
        helper.reentrantSettle(multiplePayer, 1 gwei, second);

        // Test multiple sends.
        first = abi.encode(uint256(0), int256(0), nulldata);
        second = abi.encode(uint256(0), -1 gwei, first);
        helper.reentrantSettle(multiplePayer, -1 gwei, second);

        // Test receive and send.
        first = abi.encode(uint256(2 gwei), int256(0), nulldata);
        second = abi.encode(uint256(0), -1 gwei, first);
        helper.reentrantSettle(multiplePayer, 2 gwei, second);

        // oversend
        first = abi.encode(uint256(3 gwei), int256(0), nulldata);
        second = abi.encode(uint256(0), -1 gwei, first);
        helper.reentrantSettle(multiplePayer, 2 gwei, second);

        // undersend
        first = abi.encode(uint256(1 gwei), int256(0), nulldata);
        second = abi.encode(uint256(0), -1 gwei, first);
        vm.expectRevert(abi.encodeWithSelector(RFTLib.InsufficientReceive.selector, address(token), 1 gwei, 0));
        helper.reentrantSettle(multiplePayer, 2 gwei, second);

        // Receive and send back.
        token.mint(address(helper), 10 ether);
        first = abi.encode(uint256(5 ether), int256(0), nulldata);
        second = abi.encode(uint256(0), int256(5 ether), first);
        helper.reentrantSettle(multiplePayer, -10 ether, second);

        // Test receive and send that settles to zero.
        first = abi.encode(uint256(1 gwei), int256(0), nulldata);
        second = abi.encode(uint256(0), int256(1 gwei), first);
        helper.reentrantSettle(multiplePayer, -1 gwei, second);

        first = abi.encode(uint256(0), int256(0), nulldata);
        second = abi.encode(uint256(0), int256(1 gwei), first);
        vm.expectRevert(abi.encodeWithSelector(RFTLib.InsufficientReceive.selector, address(token), 0, -1 gwei));
        helper.reentrantSettle(multiplePayer, -1 gwei, second);

        // Test reentrancy with settle.
        vm.expectRevert(RFTLib.ReentrancyLocked.selector);
        helper.reentrantSettle(settlePayer, 1 gwei, abi.encode(false));
    }

    function testReentrantSettleHuman() public {
        token.mint(human, 1 ether);
        vm.prank(human);
        token.approve(address(helper), 2 ether);

        token.mint(address(helper), 1 ether);

        bytes memory nulldata;
        bytes memory first = abi.encode(uint256(10 gwei), int256(0), nulldata);

        // The data doesn't matter
        helper.reentrantSettle(human, 1 ether, first);
        helper.reentrantSettle(human, -1 ether, first);
        helper.reentrantSettle(human, 1 ether, first);
    }

    function testHandleTokenRequestCBData() public {
        (, bytes memory data) = helper.settle(dataPayer, 1 gwei);
        uint256 result = abi.decode(data, (uint256));
        assertEq(result, uint256(7));

        data = helper.request(dataPayer, 1 gwei);
        result = abi.decode(data, (uint256));
        assertEq(result, uint256(7));

        data = helper.requestOrTransfer(dataPayer, 1 gwei);
        result = abi.decode(data, (uint256));
        assertEq(result, uint256(7));

        bytes memory nulldata;
        data = helper.reentrantSettle(dataPayer, 1 gwei, nulldata);
        result = abi.decode(data, (uint256));
        assertEq(result, uint256(7));
    }
}
