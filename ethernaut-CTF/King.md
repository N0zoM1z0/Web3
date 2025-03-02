The contract below represents a very simple game: whoever sends it an amount of ether that is larger than the current prize becomes the new king. On such an event, the overthrown king gets paid the new prize, making a bit of ether in the process! As ponzi as it gets xD

Such a fun game. Your goal is to break it.

When you submit the instance back to the level, the level is going to reclaim kingship. You will beat the level if you can avoid such a self proclamation.



```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract King {
    address king;
    uint256 public prize;
    address public owner;

    constructor() payable {
        owner = msg.sender;
        king = msg.sender;
        prize = msg.value;
    }

    receive() external payable {
        require(msg.value >= prize || msg.sender == owner);
        payable(king).transfer(msg.value);
        king = msg.sender;
        prize = msg.value;
    }

    function _king() public view returns (address) {
        return king;
    }
}
```





在 Solidity 中，向地址发送 ETH 的常用方法包括 `transfer()`、`send()` 和 `call()`。当接收方为**普通地址（EOA）时，这些方法通常能正常执行；但当接收方为智能合约地址**时，若合约未定义 `receive()` 或 `fallback()` 函数，转账将失败并回滚交易！！！！！



另一个点在于 send ether的gas limit 问题：

>### Sending and Receiving Ether
>
>- Neither contracts nor “external accounts” are currently able to prevent that someone sends them Ether. Contracts can react on and reject a regular transfer, but there are ways to move Ether without creating a message call. One way is to simply “mine to” the contract address and the second way is using `selfdestruct(x)`.
>
>- If a contract receives Ether (without a function being called), either the [receive Ether](https://docs.soliditylang.org/en/v0.8.1/contracts.html#receive-ether-function) or the [fallback](https://docs.soliditylang.org/en/v0.8.1/contracts.html#fallback-function) function is executed. If it does not have a receive nor a fallback function, the Ether will be rejected (by throwing an exception). During the execution of one of these functions, the contract can only rely on the “gas stipend” it is passed (2300 gas) being available to it at that time. This stipend is not enough to modify storage (do not take this for granted though, the stipend might change with future hard forks). To be sure that your contract can receive Ether in that way, check the gas requirements of the receive and fallback functions (for example in the “details” section in Remix).
>
>- There is a way to forward more gas to the receiving contract using `addr.call{value: x}("")`. This is essentially the same as `addr.transfer(x)`, only that it forwards all remaining gas and opens up the ability for the recipient to perform more expensive actions (and it returns a failure code instead of automatically propagating the error). This might include calling back into the sending contract or other state changes you might not have thought of. So it allows for great flexibility for honest users but also for malicious actors.
>
>- Use the most precise units to represent the wei amount as possible, as you lose any that is rounded due to a lack of precision.
>
>- If you want to send Ether using
>
>   
>
>  ```
>  address.transfer
>  ```
>
>  , there are certain details to be aware of:
>
>  1. If the recipient is a contract, it causes its receive or fallback function to be executed which can, in turn, call back the sending contract.
>  2. Sending Ether can fail due to the call depth going above 1024. Since the caller is in total control of the call depth, they can force the transfer to fail; take this possibility into account or use `send` and make sure to always check its return value. Better yet, write your contract using a pattern where the recipient can withdraw Ether instead.
>  3. Sending Ether can also fail because the execution of the recipient contract requires more than the allotted amount of gas (explicitly by using [require](https://docs.soliditylang.org/en/v0.8.1/control-structures.html#assert-and-require), [assert](https://docs.soliditylang.org/en/v0.8.1/control-structures.html#assert-and-require), [revert](https://docs.soliditylang.org/en/v0.8.1/control-structures.html#assert-and-require) or because the operation is too expensive) - it “runs out of gas” (OOG). If you use `transfer` or `send` with a return value check, this might provide a means for the recipient to block progress in the sending contract. Again, the best practice here is to use a [“withdraw” pattern instead of a “send” pattern](https://docs.soliditylang.org/en/v0.8.1/common-patterns.html#withdrawal-pattern).

所以这里我们要用  call

需注意兩點的是︰

- Value 需大於或等於1 ether (關卡合約要求)
- 需要手動調高Gas limit，一次調到100000就可以了(不然呼叫關卡合約的fallback時會因Out of gas 失敗)

为什么是 1 ether呢？

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract King {
    address levelInstance;

    constructor(address _levelInstance) {
        levelInstance = _levelInstance;
    }

    function give() public payable {
        levelInstance.call{value: msg.value}("");
    }
}
```



实操没有成功。。。 后面再来试吧。