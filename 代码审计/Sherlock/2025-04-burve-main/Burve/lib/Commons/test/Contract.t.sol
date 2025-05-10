// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {PRBTest} from "@prb/test/PRBTest.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {ContractLib} from "../src/Util/Contract.sol";
import {MockFactory, MockPool} from "CommonsTestLib/MockPool.u.sol";

contract ContractLibTest is PRBTest, StdCheats {
    function testIsContract() public {
        assertTrue(ContractLib.isContract(address(this)));
        assertTrue(!ContractLib.isContract(address(0)));

        ContractLib.assertContract(address(this));
        vm.expectRevert(ContractLib.NotAContract.selector);
        ContractLib.assertContract(address(0));
    }

    function testGetCreate2Address() public {
        MockFactory factory = new MockFactory();
        bytes32 salt = bytes32(uint256(0));
        address pool = factory.createPool(salt);
        bytes32 initCodeHash = keccak256(type(MockPool).creationCode);
        address createAddr = ContractLib.getCreate2Address(address(factory), salt, initCodeHash);
        assertEq(pool, createAddr);
    }
}
