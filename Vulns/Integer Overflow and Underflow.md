## 整数上溢和下溢（Integer Overflow and Underflow）

 在solidity中，[整数类型](https://so.csdn.net/so/search?q=整数类型&spm=1001.2101.3001.7020)有最大值和最小值。当整型变量的值超过可存储在该变量类型的最大值时，就会发生整数溢出。类似地，当整型变量的最小值低于该变量类型的最小值时，就会发生整数下溢。例如，uint8类型的最大值为255，当将256存入uint8类型时，会发生上溢，值被设置为0。当存储的值为257时，值被设置为1，以此类推。同样地，如果将-1存储在uint8类型变量中时，这个变量的值将被设置为255，这样会发生下溢。

 一些整型变量和它们的最大最小值如下所示：

![img](https://i-blog.csdnimg.cn/direct/dbd638835bce4196b31a6145cc59040e.png)

 由于uint8、uint16等具有较小的[最大值](https://so.csdn.net/so/search?q=最大值&spm=1001.2101.3001.7020)，因此更容易导致移除，应谨慎使用。

 为了防止上溢/下溢。solidity在0.8及以上版本通过内置安全数学函数来阻止整数上溢和下溢。但需要注意的是，无论是哪种SafeMath逻辑，如内置或者在旧合约中手动使用，上溢/下溢仍然会触发reverts，这有可能导致重要功能出现问题或者其他意想不到的影响。甚至在solidity0.8版本以后，在没有交易回退（reverting）的情况下仍然有可能发生整数的上溢和下溢。



#### 1、类型转换（Type Casting）

 最容易导致整数上溢/下溢的方式是当一个大的uint数据类型向小的uint数据类型转换:

```solidity
uint256 public a = 258;
uint8 public b = uint8(a);
```

 上述代码片段会产生上溢，变量b的值会被存储为2。



#### 2、使用移位运算符（Using Shift Operators）

 移位操作不像其他算数运算那样执行上溢和下溢的检查，因此，有可能发生上溢/下溢。

 左移运算符'<<'就是将一个二进制位的操作数按照指定位数整体向左移，右边的空位补0。如uint8类型的变量a值为10，转换成二进制就使00001010，左移一位后为00010100，转换为十进制后就使20。可以简单概括为将操作数左移一位相当于乘以2，移动两位相当于乘以4，移动三位相当于乘以8。

```solidity
uint8 public a = 100;
uint8 public b = 2;
 
uint8 public c = a << b;   //overflow as 100 * 4 > 255
```



#### 3、内联汇编的使用（Use of Inline Assembly）

 内联汇编在solidity中使用是YUL语言。YUL是一种可以编译到各种不同后端的中间语言。在YUL程序语言中，整数的上溢和下溢是可能的因为编译器不会自动检查它，因为YUL是一种低级的语言，主要用于优化代码，这是通过省略许多操作码来实现的。

```solidity
uint8 public c = 255;
 
function addition() public returns (uint8 result) {
    assembly {
        result := add(sload(c.slot), 1) // adding 1 will overflow and reset to 0
        // using inline assembly
    }
 
    return result;
}
```

 在上述代码中，我们通过内联汇编给变量加1然后返回结果。这个变量结果将会发生溢出，然后返回0，但合约不会报错或者revert。



#### 4、未检查代码块的使用(Use of unchecked code block)

 在未检查的块内执行算术运算节省了大量的gas，因为它省略了几个检查和操作码。但是，其中一些操作码在0.8版本的默认算术运算中用于检查下溢/溢出。

```solidity
uint8 public a = 255;
 
function uncheck() public{
 
  unchecked {
      a++;  // overflow and reset to 0 without reverting
  }
 
}
```

 只有在确定算法不会溢出或下溢的情况下，才建议使用未检查的代码块。