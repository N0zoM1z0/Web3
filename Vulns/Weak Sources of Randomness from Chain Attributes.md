## 链属性的弱随机性来源(Weak Sources of Randomness from Chain Attributes)

 在[以太坊](https://so.csdn.net/so/search?q=以太坊&spm=1001.2101.3001.7020)中，某些应用程序依赖随机数生成来保证公平性。 然而，以太坊中[随机数](https://so.csdn.net/so/search?q=随机数&spm=1001.2101.3001.7020)的生成非常困难，有几个陷阱值得考虑。使用 block.timestamp、blockhash 和 block.difficulty 等链属性似乎是个好主意，因为它们通常会产生伪随机值。然而，以太坊是完全确定的，所有可用的链上数据都是公开的。链属性既可以预测也可以操纵，因此不能用于随机数生成。