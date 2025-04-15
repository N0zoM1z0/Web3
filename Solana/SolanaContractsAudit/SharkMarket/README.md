# SharkMarket

## 题目描述

请在 market 中寻找漏洞，使用少量的 coin 来成功购买 flag 吧！

## 题目环境说明

### 题目环境框架

- framework: 题目公共远程服务端，负责接收选手的攻击载荷，并对每次请求创建一个 Solana 环境进行验证，其中会对整个环境进行一些初始化设置。
  - chall: 题目合约程序，需要进行代码审计的部分。
- framework-solve: 选手进行攻击使用的框架，为了简化交互难度，选手只需要在指定位置编写 instructions，框架会将所有 instructions 发送给服务端进行执行。

为了简化交互难度，为 instruction 编写提供了一些辅助函数，可以在 `ixs_utils.rs` 中查看使用。

### 对于 rust 环境

1. 在离线环境下，对 rust 依赖进行了 vendor 处理，因此如果本地有 rust 环境 + ra 插件，使用 vscode 打开便能够获得良好的代码提示支持。
2. 若本机没有 rust 环境，提供了一个带有 rust, anchor 的 docker 镜像 (`sharkmarket-dev.tar`)，选手可以导入 (`docker load --input xxx.tar`) 并在容器中进行验证。

### 如何进行本地测试

1. 进入 `framework/chall` 目录，执行 `anchor build` 编译合约。
2. 进入 `framework` 目录，执行 `cargo run` 运行服务端。
3. 在 `framework-solve` 目录中编写好攻击指令后，执行 `cargo run`。
