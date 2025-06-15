// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {LendStorage} from "../../src/LayerZero/LendStorage.sol";
import {LToken} from "../../src/LToken.sol";
import {CoreRouter} from "../../src/LayerZero/CoreRouter.sol";
import {console2} from "forge-std/console2.sol";

contract TestLiquidation is Test {
    // Add lend storage address here

    CoreRouter public coreRouter = CoreRouter(payable(0x55b330049d46380BF08890EC21b88406eBFd20B0));

    address account = 0x1D1ba5b91Cdbfa2BB0B66330B619E300e3CD8bF4;

    address borrower = 0x96e2A74E07eb350FfD2875FE908CdB733aB649ff;

    uint256 repayAmount = 100225100000000000000;

    address lTokenCollateral = 0xaa7dfbDf90418A9DA24DEe346436590991dCCEec;

    address lTokenBorrow = 0xF98f8f2CB30558dc03aD9146D06820411Ab5009b;

    uint256 forkId;

    uint256 blockNumber = 21685252;

    function setUp() public {
        string memory rpcUrl = vm.envString("BASE_SEPOLIA_RPC_URL");
        console2.log("rpcUrl", rpcUrl);
        forkId = vm.createSelectFork(rpcUrl, blockNumber);
    }

    function test_liquidate_borrow_on_base_sepolia() public {
        vm.startPrank(account);
        coreRouter.liquidateBorrow(borrower, repayAmount, lTokenCollateral, lTokenBorrow);
        vm.stopPrank();
    }
}
