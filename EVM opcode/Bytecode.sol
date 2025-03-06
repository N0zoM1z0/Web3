// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BytecodeTest{
    address levelInstance;
    constructor(address _levelInstance) {
        levelInstance = _levelInstance;
    }

    function simpleAdd(uint256 _a,uint256 _b) public pure returns (uint256){
        return _a+_b;
    }
}