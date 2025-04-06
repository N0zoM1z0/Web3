use anchor_lang::prelude::*;

declare_id!("YourProgramIdHere");

#[program]
pub mod transfer_sol {
    use super::*;

    pub fn transfer(ctx: Context<Transfer>, amount: u64) -> Result<()> {
        /*
        ctx: Context<Transfer> - 包含账户信息的上下文
        amount: u64 - 转账金额（以 lamports 为单位，1 SOL = 10^9 lamports）
        */
        let from = &ctx.accounts.from;
        let to = &ctx.accounts.to;
        **from.try_borrow_mut_lamports()? -= amount;
        **to.try_borrow_mut_lamports()? += amount;
        /*
        try_borrow_mut_lamports() - 获取账户 lamports 的可变引用
        双解引用 ** - 因为返回的是双重引用
        ? - 错误处理，操作失败时提前返回错误
        */
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Transfer<'info> {
    #[account(mut)]
    pub from: Signer<'info>,
    #[account(mut)]
    pub to: AccountInfo<'info>,
    pub system_program: Program<'info, System>,
}
/*
from：
#[account(mut)] - 需要可变访问（因为要修改余额）
Signer<'info> - 必须是交易签名者（授权转账）

to：
#[account(mut)] - 需要可变访问（因为要接收资金）
AccountInfo<'info> - 通用账户类型（不需要特定结构）

system_program：
系统程序引用（虽然代码中未直接使用，但 lamports 操作需要）
*/

/*
lamports 操作
try_borrow_mut_lamports() 是 Anchor 提供的便捷方法
直接操作 lamports 是 Solana 上资金转移的低级方式
相当于直接修改账户的底层余额


安全性考虑
签名验证：

from 必须是 Signer，确保只有账户所有者能发起转账
溢出检查：

使用 try_borrow_mut_lamports 确保账户余额足够，避免溢出。

直接 lamports 操作相对安全，不像以太坊那样容易受重入攻击
*/