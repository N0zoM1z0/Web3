1. 虽然 >=0.8.0有溢出检测，但是出现溢出会导致revert，是DoS的漏洞！！！
1. 不同于web2，web3合约的return这些都要重点关注，是否影响了正常的逻辑！！！
1. 注意一些编程代码错误：如token0和token1打混。。。