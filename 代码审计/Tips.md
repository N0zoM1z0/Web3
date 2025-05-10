1. 虽然 >=0.8.0有溢出检测，但是出现溢出会导致revert，是DoS的漏洞！！！

1. 不同于web2，web3合约的return这些都要重点关注，是否影响了正常的逻辑！！！

1. 注意一些编程代码错误：如token0和token1打混。。。

1. 合约整体conform的规范，通过 https://solodit.cyfrin.io/ 等搜索已有的相关的漏洞，进行快速熟悉

1. 看到 transfer的使用，都可以写进报告！！！

   一个生动的例子：https://solodit.cyfrin.io/issues/m-13-withdrawfacets-withdraw-calls-native-payabletransfer-which-can-be-unusable-for-diamondstorage-owner-contract-code4rena-lifi-lifi-git

   risk照这篇写：https://diligence.consensys.io/blog/2019/09/stop-using-soliditys-transfer-now/

1. function的**权限**！！！Access Control！！！

1. 关注**不一致性**！！！有些可能是开发者的“喜好”，但是如果对于同样的功能/数据 前后处理不一致，那就很大可能是安全问题了！！！