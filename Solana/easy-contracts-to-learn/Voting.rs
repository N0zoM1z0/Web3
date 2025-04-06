use anchor_lang::prelude::*;

declare_id!("YourProgramIdHere");

#[program]
pub mod voting {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let vote_account = &mut ctx.accounts.vote_account;
        vote_account.yes = 0;
        vote_account.no = 0;
        Ok(())
    }

    pub fn vote(ctx: Context<Vote>, in_favor: bool) -> Result<()> {
        let vote_account = &mut ctx.accounts.vote_account;
        if in_favor {
            vote_account.yes += 1;
        } else {
            vote_account.no += 1;
        }
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = user, space = 8 + 16)]
    pub vote_account: Account<'info, VoteAccount>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}
/*
vote_account: 新创建的投票账户
init: 表示要初始化
payer = user: 由user支付创建账户的费用
space = 8 + 16: 8字节discriminator + 16字节数据(两个u64)
user: 必须签名且支付费用的账户
system_program: 必需的系统程序引用
*/

#[derive(Accounts)]
pub struct Vote<'info> {
    #[account(mut)]
    pub vote_account: Account<'info, VoteAccount>,
    pub voter: Signer<'info>,
}
/*
vote_account: 需要修改的投票账户
voter: 投票人(需要签名验证身份)
*/

#[account]
pub struct VoteAccount {
    pub yes: u64,
    pub no: u64,
}

/*
没有防止重复投票
*/