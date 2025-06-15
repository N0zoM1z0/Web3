// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {LendStorage} from "../../src/LayerZero/LendStorage.sol";
import {LToken} from "../../src/LToken.sol";
import {console2} from "forge-std/console2.sol";

contract TestHypotheticalFunction is Test {
    // Add lend storage address here
    LendStorage public lendStorage = LendStorage(0x3B4116990720C34F0DB3Ac85574121DA045C7f8E);
    LToken public lToken = LToken(0xf00b8BC45feB966caA8ad85a23E42BB792646290);

    address account = 0x96e2A74E07eb350FfD2875FE908CdB733aB649ff;

    uint256 forkId;

    uint256 blockNumber = 7678151;

    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        console2.log("rpcUrl", rpcUrl);
        forkId = vm.createSelectFork(rpcUrl, blockNumber);
    }

    function test_get_borrow_with_interest() public view {
        uint256 borrowWithInterest = lendStorage.borrowWithInterest(account, address(lToken));
        console2.log("borrowWithInterest", borrowWithInterest);
    }

    function test_get_hypothetical_account_liquidity_collateral() public view {
        (uint256 borrow, uint256 collateral) =
            lendStorage.getHypotheticalAccountLiquidityCollateral(account, lToken, 0, 0);

        console2.log("borrow", borrow);
        console2.log("collateral", collateral);
    }

    function test_get_max_withdrawable() public {
        uint256 maxWithdrawable = lendStorage.getMaxWithdrawable(account, address(lToken));
        console2.log("maxWithdrawable", maxWithdrawable);
    }
}
