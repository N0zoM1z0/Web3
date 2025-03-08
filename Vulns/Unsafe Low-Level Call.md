## 不安全的低级调用（Unsafe Low-Level Call）

 在solidity中，你可以使用低级调用如：address.call()，address.callcode()，address.delegatecall()和address.send()。或者你可以使用合约调用如：ExternalContract.doSomething()。

  低级调用是有效地或任意地进行合约调用地好方法，但也要注意到它潜在的风险。



#### 1、不检查调用的返回值（Unchecked call return value）

 低级调用永远不会抛出异常，相反，如果遇到异常，将会返回'false'，而合约调用将会自动抛出。因此，如果没有检查低级调用的返回值，即使[函数调用](https://so.csdn.net/so/search?q=函数调用&spm=1001.2101.3001.7020)抛出错误也可以继续执行。这可能导致意外行为并破坏程序的逻辑。调用失败甚至可能是由攻击者故意造成的，攻击者可以进一步利用该程序。

 在低级调用的情况下，一定要检查返回值以处理可能失败的调用。

```solidity
// Simple transfer of 1 ether
(bool success, ) = to.call{value: 1 ether}("");
// Revert if unsucessful
require(success);
```

#### 2、成功调用不存在的合约（Successful call to non-existent contract）

 正如solidity文档中所说：由于EVM认为可以对不存在的合约的调用总是成功的，因此solidity语言层面里会使用'extcodesize'操作码来检查要调用的合约是否确实存在（包含代码），如果不存在该合约，则[抛出异常](https://so.csdn.net/so/search?q=抛出异常&spm=1001.2101.3001.7020)。如果返回数据在调用后被解码，则跳过这个检查，因此ABI解码器将捕捉到不存在的合约的情况。

 值得注意的是，这个检查在低级调用时不被执行，这些调用是对地址而不是合约实例进行操作。

 所以不能简单假设通过低级调用调用的合约是存在的，因为如果合约不存在，即使外部调用失败了，逻辑也会继续执行。这可能导致资产的损失或者无效的合约状态。因此，我们必须验证被调用合约是否存在，在被调用之前使用'extcodesize'检查，或者在合约部署期间进行验证和使用常量/不可变值（如果合约可以完全信任）。

```solidity
// Verify address is a contract
require(to.code.length > 0);
// Simple transfer of 1 ether
(bool success,) = to.call{value: 1 ether}("");
// Revert if unsuccessful
require(success);
```

