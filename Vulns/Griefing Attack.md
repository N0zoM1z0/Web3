Learning from

```
https://blog.csdn.net/peijiapao/article/details/142032961
```

---

这类攻击通常与业务逻辑有关，旨在破环智能合约系统的运行，尽管攻击者无法直接获利，但会给智能合约的运行带来负面影响。以下是典型的悲伤攻击场景：

```solidity
//这是一个简单的延迟取款合约，它允许用户存入资金，并且只有在指定的延迟时间过后才能取出这些资金
contract DelayedWithdrawal {
    address beneficiary;   //受益人地址
    uint256 delay;   //延迟时间
    uint256 lastDeposit;   //上次的存款时间
 
    constructor(uint256 _delay) {
        beneficiary = msg.sender;   
        lastDeposit = block.timestamp;   //当前区块的时间戳
        delay = _delay;   //设置延迟时间为传入参数
    }
 
    modifier checkDelay() {
        require(block.timestamp >= lastDeposit + delay, "Keep waiting");   //确保当前时间已经超过了上次存款时间加上延迟时间
        _;
    }
 
    //允许任何人向合约存入ETH，并更新最后存款的时间戳
    function deposit() public payable {
        require(msg.value != 0);
        lastDeposit = block.timestamp;
    }
 
    //允许受益人提取合约中的所有ETH，但是必须经过延迟时间
    function withdraw() public checkDelay {
        //尝试将合约中的所有ETH发送给受益者
        (bool success, ) = beneficiary.call{value: address(this).balance}("");
        require(success, "Transfer failed");   //如果转账失败，抛出异常
    }
}
```



所以攻击者可以卡一个时间差，在结束前的一小段时间存入，然后更新最后能取款的时间戳，导致正常用户无法withdraw。

> 上述代码中，在构造函数中，beneficiary被设置为合约部署者的地址以及自定义延迟时间，例如24小时。任何人都可以存入资金，这些资金可以在延迟时间过后提取转移给beneficiary，但是每次存款必须将非零的ETH转移到[智能合约](https://so.csdn.net/so/search?q=智能合约&spm=1001.2101.3001.7020)中。这里潜在的悲伤攻击是任何人都可以调用deposit函数和重置lastDeposit时间戳，这样会导致greifing攻击者往合约中存入很小的数额（1wei），这样会重置lastDeposit时间戳。这样，这个新的lastDeposit时间戳阻止了受益人提取他们的资金。
>
>  攻击者可以在延迟期结束之前提交交易来重置时间戳实现悲伤攻击，或者攻击者可以抢先、预测和抢占受益人对withdraw函数的调用，从而创建一个更具效益的拒绝服务攻击。