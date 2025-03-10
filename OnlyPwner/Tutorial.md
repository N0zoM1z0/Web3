主要是学习forge使用，环境的配置，怎么用给的rpc进行交互。



> This is a dummy challenge with the purpose of demonstrating how to interact with and solve challenges. If you are new, make sure to read the **DOCUMENTATION** linked to at the top of the page before getting started.
>
> 
>
> Interacting with challenges on ONLYPWNER is very similar to interacting with deployed smart contracts on-chain, just that we are connecting to a sandbox environment instead of a real blockchain. The documentation lists a variety of tools you can use to do so. In this tutorial, we will use *Forge Scripts*.
>
> 
>
> ### 1. FINDING THE VULNERABILITY
>
> 
>
> Looking at the code listing at the bottom of this page, we can see that the `Deploy.sol` script sets up the `Tutorial` contract with an initial balance of 10 ether. The winning condition, which can be found in `IsSolved.sol`, is to remove all funds from the `Tutorial` contract.
>
> 
>
> The `Tutorial` contract itself has a function `callMe` that simply transfers all funds to the caller. So, to solve this challenge, we simply need to invoke `callMe` on the `Tutorial` contract.
>
> 
>
> ### 2. SETTING UP THE FORGE ENVIRONMENT
>
> 
>
> On your local machine, run `forge init` in an empty directory to create a new project. Forge will initialize a default folder and file structure. We can ignore most of it, the only important directory for us is `script`. In there, you will find a default script called `Counter.s.sol`. You can safely delete this file.
>
> 
>
> ### 3. CREATING THE SOLUTION SCRIPT
>
> 
>
> Next, we create our solution document in our local `script` directory. You can call it whatever you like, for example `script/SolveTutorial.sol`. In there, we simply call the `callMe` method of `Tutorial`:
>
> 
>
> ```solidity
> pragma solidity ^0.8.13;
> 
> import {Script} from "forge-std/Script.sol";
> 
> interface ITutorial {
>     function callMe() external;
> }
> 
> contract SolveTutorial is Script {
>     function run() public {
>         vm.startBroadcast();
>         ITutorial tutorial = ITutorial(/* TODO */);
>         tutorial.callMe();
>     }
> }
> ```
>
> 
>
> ### 4. LAUNCHING THE CHALLENGE
>
> 
>
> Now that we are ready to call the `Tutorial` contract, we need its address and a RPC we can communicate with. Click the yellow **LAUNCH** button, and you will receive an RPC URL, the contract address, and a user private key and address. Insert the contract address into the `SolveTutorial` script to replace the `/* TODO */` comment.
>
> 
>
> ### 5. RUNNING THE SOLUTION SCRIPT
>
> 
>
> We are ready to execute the script. Insert your values into the command below and run it. **DO NOT** use your real private key. Instead, use the one you received when you launched the challenge. This private key is also not expected to ever change, and is constant across challenges.
>
> 
>
> ```bash
> forge script \
>     --broadcast \ # To actually send the transactions
>     --rpc-url <YOUR RPC URL HERE> \ # The RPC to communicate with
>     --private-key be0a5d9f38057fa406c987fd1926f7bfc49f094dc4e138fc740665d179e6a56a \ # The generated private key
>     --with-gas-price 0 \ # Do not pay for gas
>     --priority-gas-price 0 \ # Do not pay for gas
>     SolveTutorial # Execute our solution script
> ```
>
> 
>
> ### 6. CHECKING FOR SUCCESS
>
> 
>
> Finally, we can now press the **CHECK** button. If all went well, it turns green, and you have solved the challenge!



setup步骤参考：
```
https://bznsix.github.io/post/ji-lu-xia-pei-zhi-ONLYPWNER%20CTF-huan-jing-de-bu-zou.html
```



跟着教程走。用 

```
https://github.com/psucodervn/onlypwner-foundry
```

模板

```
git clone --recursive https://github.com/psucodervn/onlypwner-foundry.git
```

新建.env，填写配置项.

在 script下建  Solve.sol

```solidity
pragma solidity ^0.8.0;

import { Script } from "lib/forge-std/src/Script.sol";
import { ITutorial } from "../src/interfaces/ITutorial.sol";
contract Solve is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address tutorialAdd = vm.envAddress("TUTORIAL");
        ITutorial tutorial = ITutorial(tutorialAdd);
        tutorial.callMe();
    }
}
```





```
forge script challenges/Tutorial/script/Solve.sol --broadcast --with-gas-price=0 --priority-gas-price 0
```

​	



```bash
web@web-virtual-machine:~/Desktop/Web3/Web3-Project/onlypwner-foundry$ forge script challenges/Tutorial/script/Solve.sol --broadcast --with-gas-price=0 --priority-gas-price 0
[⠊] Compiling...
[⠊] Compiling 17 files with Solc 0.8.19
[⠒] Solc 0.8.19 finished in 1.91s
Compiler run successful!
Script ran successfully.

## Setting up 1 EVM.

==========================

Chain 31337

Estimated gas price: 0 gwei

Estimated total gas used for script: 41103

Estimated amount required: 0. ETH

==========================

##### anvil-hardhat
✅  [Success] Hash: 0x33b5ad95eac1ab7a7370e64f23df81c43be22e5ee4a75c3f8719d5f7b5c20696
Block: 515
Gas Used: 28105

✅ Sequence #1 on anvil-hardhat | Total Paid: 0. ETH (28105 gas * avg 0 gwei)
                                                                                

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.

Transactions saved to: /home/web/Desktop/Web3/Web3-Project/onlypwner-foundry/broadcast/Solve.sol/31337/run-latest.json

Sensitive values saved to: /home/web/Desktop/Web3/Web3-Project/onlypwner-foundry/cache/Solve.sol/31337/run-latest.json

web@web-virtual-machine:~/Desktop/Web3/Web3-Project/onlypwner-foundry$ 

```

