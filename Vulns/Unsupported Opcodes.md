## 不支持操作码（Unsupported Opcodes）

 像一些[区块链](https://so.csdn.net/so/search?q=区块链&spm=1001.2101.3001.7020)zkSync Era，BNB Chain，Polygon，Optimism和Arbitrum兼容EVM和它的操作码。操作码支持在这些链中可能会有所不同。如果在智能合约开发和部署期间没有考虑到这一点，可能会导致错误和问题。



#### 1、PUSH0操作码兼容性（PUSH0 Opcode Compatibility）

 PUSH0操作码是在上海升级期间引入的（Solidity v0.8.20），在某些[EVM](https://so.csdn.net/so/search?q=EVM&spm=1001.2101.3001.7020)兼容链中可用。但是至今不是所有的链都支持PUSH0这个操作码。诸如Ethereum、Arbitrum One、Optimism等链是支持的。



#### 2、zkSync Era中的CREATE和CREATE2

 在zkSync Era中，合约的部署使用字节码的哈希值和EIP712交易的'factoryDeps'字段包含的字节码。实际上的部署是通过向'ContractDeployer'系统合约提供合约的哈希值实现的。

 为了确保'CREATE'和'CREATE2'函数操作正确，编译器MUST提前了解被部署合约的字节码。编译器将calldata参数解释为'ContractDeployer'的不完整输入，其余部分由编译器内部填充。YUL指令'datasize'和'dataoffset'被调整为返回常量大小和字节码哈希值而不是字节码本身。

 下面的代码将不能正确运行，因为编译器事先不知道字节码，但可以正常工作在以太坊主网：

```solidity
function myFactory(bytes memory bytecode) public {
   assembly {
      addr := create(0, add(bytecode, 0x20), mload(bytecode))
   }
}
```

#### 3、zkSync Era的.transfer()

 .transfer()在solidity中被限制为2300gas，但如果收到函数的fallback或者收到函数调用更多复杂的逻辑，gas费是不太够的。如果超出了gas限制，就有可能导致交易回滚。

 正是由于这个原因，zkSync Era上的Gemholic项目锁定了在Gemholic代币销售期间筹集的921个ETH，使资金无法访问。这是因为合约部署者没有考虑到zkSync Era对'.transfer()'函数的处理。