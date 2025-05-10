// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/RockPaperScissors.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the Rock Paper Scissors contract
        RockPaperScissors game = new RockPaperScissors();
        
        console.log("Rock Paper Scissors contract deployed at:", address(game));
        console.log("WinningToken deployed at:", address(game.winningToken()));
        
        vm.stopBroadcast();
    }
}