// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../contracts/libraries/SafeMath.sol";

contract SafeMathTest is Test {
    using SafeMath for uint;

    function testAdd() public pure {
        uint a = 1e18;
        uint b = 2e18;
        uint c = a.add(b);
        assertEq(c, 3e18);
    }

    function testSub() public pure {
        uint a = 5e18;
        uint b = 2e18;
        uint c = a.sub(b);
        assertEq(c, 3e18);
    }

    function testMul() public pure {
        uint a = 2e18;
        uint b = 3;
        uint c = a.mul(b);
        assertEq(c, 6e18);
    }

    function testMulByZero() public pure{
        uint a = 123456789;
        uint b = 0;
        uint c = a.mul(b);
        assertEq(c, 0);
    }
}
