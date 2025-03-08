## [时间戳](https://so.csdn.net/so/search?q=时间戳&spm=1001.2101.3001.7020)依赖（Timestamp Dependence）

 **注意，在权益证明合并后，此漏洞不再影响以太坊主网。**

PoW -> PoS

 当使用时间戳执行合约中的关键功能，特别是当操作涉及资金转移时，有三个主要考虑的因素。

#### 

#### 1、时间戳操纵（Timestamp Manipulation）

 区块的时间戳可以被矿工操纵,考虑下面的合约：

```solidity
    uint256 constant private salt = block.timestamp;
 
    function random(uint Max) constant private returns (uint256 result) {
        //get the best seed for randomness
        uint256 x = salt * 100/Max;
        uint256 y = salt * block.number/(salt % 5);
        uint256 seed = block.number/3 + (salt % 300 ) + Last_Payout + y;
        uint256 h = uint256(block.blockhash(seed));
 
        return uint256((h / x)) % Max + 1;//random number between 1 and Max
    }
```

 如果使用时间戳试图[生成随机数](https://so.csdn.net/so/search?q=生成随机数&spm=1001.2101.3001.7020)，矿工可以在区块验证后15秒内发布时间戳，使他们能够将时间戳设置为一个值，从而增加他们从该函数中获益的几率。例如，彩票应用程序可以使用块时间戳从一组人选中随机挑选竞标者。矿工可以进入彩票程序，然后将时间戳修改为一个值，使他们更有可能赢得彩票。因此时间戳不应该被用于创造随机性。

#### 2、15秒规则（The 15-second Rule）

 [以太坊](https://so.csdn.net/so/search?q=以太坊&spm=1001.2101.3001.7020)的参考规范“黄皮书”(the Yellow Paper)并没有规定区块随时间变化的限制，它只需要比父节点的时间戳大。也就是说，流行的协议将来会拒绝时间戳大于15秒的区块，因此只要您的时间相关事件可以安全地变化15秒以上，那么使用块时间戳是安全的。



#### 3、不要使用block.number作为时间戳

 可以使用block.number来估计事件之间的时间差和平均区块时间（average block time），但是区块时间可能会改变并破坏函数功能，因此最好避免使用这种方法。