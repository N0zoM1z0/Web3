use anchor_lang::prelude::*;

declare_id!("YourProgramIdHere");
/*
use anchor_lang::prelude::*; - 导入 Anchor 框架的核心模块，包括常用的宏和类型
declare_id! - 宏用于声明程序的唯一ID（部署后需要替换为实际ID）
*/

#[program]
pub mod hello_world {
    use super::*;
/*
#[program] - 属性宏，标记这是一个 Solana 程序模块
pub mod hello_world - 定义程序模块，名称可自定义
use super::*; - 导入父模块的所有内容
*/
    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.count = 0;
        Ok(())
    }
/*
initialize - 函数名，用于初始化程序状态
ctx: Context<Initialize> - 上下文参数，包含账户信息和权限验证
&mut ctx.accounts.counter - 获取可变的计数器账户引用
counter.count = 0; - 初始化计数器为0
Ok(()) - 返回成功结果
*/
    pub fn say_hello(ctx: Context<SayHello>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.count += 1;
        msg!("Hello, you've called this {} time(s)!", counter.count);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = user, space = 8 + 8)]
    pub counter: Account<'info, Counter>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}
/*
#[derive(Accounts)] - 派生宏，表示这是一个账户验证结构
'info - 生命周期参数
#[account(init, payer = user, space = 8 + 8)] - 账户属性：
init - 表示要初始化这个账户
payer = user - 指定支付账户
space = 8 + 8 - 分配空间（8字节discriminator + 8字节u64） 8 字节用于 Anchor 的鉴别符，8 字节存 u64
Account<'info, Counter> - 类型表示这是一个Counter类型的账户
#[account(mut)] - 表示user账户需要可变访问
Signer<'info> - 表示user必须是交易签名者
Program<'info, System> - 系统程序引用
*/

#[derive(Accounts)]
pub struct SayHello<'info> {
    #[account(mut)]
    pub counter: Account<'info, Counter>,
}
/*
更简单的账户结构，只需要一个可变的Counter账户
*/

#[account]
pub struct Counter {
    pub count: u64,
}
/*
#[account] - 宏表示这是一个Solana账户类型
pub count: u64 - 账户数据字段，64位无符号整数
*/