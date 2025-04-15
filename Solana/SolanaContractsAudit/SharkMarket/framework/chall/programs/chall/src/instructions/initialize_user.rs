use anchor_lang::prelude::*;

use crate::states::{SharkMarket, User, USER_SEED};

#[derive(Accounts)]
pub struct InitializeUser<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,

    pub market: Account<'info, SharkMarket>,

    #[account(
        init, // 1. 初始化账户
        payer = owner, // 2. 指定租金支付者
        seeds = [USER_SEED, market.key().as_ref(), owner.key().as_ref()], // 3. 定义PDA种子
        bump, // 4. 使用规范的Bump Seed
        space = 8 + core::mem::size_of::<User>(), // 5. 指定账户空间大小
    )]
    pub shark_user: Account<'info, User>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeUser>) -> Result<()> {
    let shark_user = &mut ctx.accounts.shark_user;

    shark_user.authority = *ctx.accounts.owner.key;
    shark_user.market = ctx.accounts.market.key();

    Ok(())
}
