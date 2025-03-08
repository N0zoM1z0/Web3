>  Insufficient Gas Griefing也被叫做gas不足攻击或者gas不足悲剧。主要影响执行外部调用而不检查成功的返回值的智能合约。在这种攻击中，对手可能仅提供足够的gas来确保顶层函数执行成功，同时确保外部调用由于gas耗尽而失败。这些问题在执行一般的调用的智能合约中尤其普遍，包括[中继器](https://so.csdn.net/so/search?q=中继器&spm=1001.2101.3001.7020)和多签名钱包。

下面的示例为简化的中继器合约，说明了不充分gas攻击的可能性：

```solidity
/*
这是一个中继合约（Relayer contract），它允许消息从一个账户被“中继”到另一个账户，并包含一些基本的重放保护措施。
允许用户支付gas费用以外的币种或者其他方式，或者帮助用户在没有直接一台当的情况下进行交易。
*/
contract Relayer {
    //如果某个数据字节串已经被执行，则其对应的值为true。这可以防止同一个操作被多次执行，即重放攻击
    mapping (bytes => bool) executed;
    
    //中继的消息将被发送到哪个合约或账户
    address target;
 
    function forward(bytes memory _data) public {
        //检查提供的数据是否已经执行过。如果执行过就抛出异常
        require(!executed[_data], "Replay protection");
        
        //more code signature validation in between
        //如果数据没有被执行过，就将其标记为已执行
         executed[_data] = true;
        
        //使用低级call方法来调用目标合约的execute函数，并传入数据
        target.call(abi.encodeWithSignature("execute(bytes)", _data));
    }
}
```



>  在[forward函数](https://so.csdn.net/so/search?q=forward函数&spm=1001.2101.3001.7020)内的外部调用失败时，合约可以选择恢复整个交易或继续执行。示例中的合约不检查外部调用是否成功，而是继续执行。因此，一旦完成forward函数的执行，提交的数据在已执行的映射中被标记为已执行，从而防止任何人再次提交相同的数据。
>
>  任何第三方forwarder都可以调用forward函数来代表他们执行一个用户的交易。假设forwarder以最小的gas调用forward，仅允许Relayer合约成功但由于gas费耗尽错误导致外部调用revert（gas足够交易执行但不够调用成功）。在这种情况下，用户的交易不会被执行且用户的签名是无效的。因此，目标合约的预期状态改变将不会发生。恶意的forwarders将使用这项技术永久的地审查Replayer合约中地用户交易。即使攻击者不从悲伤攻击中获利，他们仍然可以破坏智能合约地运行，给受害者带来不便。



也就是说：可以进入这个forward，但是无法调用 `target.call`，使得先被标记executed，再target.call失效，实现一种DoS攻击。