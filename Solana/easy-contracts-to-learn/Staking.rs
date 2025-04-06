use anchor_lang::prelude::*;

declare_id!("YourProgramIdHere");

#[program]
pub mod staking {
    use super::*;

    pub fn stake(ctx: Context<Stake>, amount: u64) -> Result<()> {
        let stake_account = &mut ctx.accounts.stake_account;
        **ctx.accounts.user.try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.stake_account.try_borrow_mut_lamports()? += amount;
        stake_account.amount = amount;
        stake_account.timestamp = Clock::get()?.unix_timestamp;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Stake<'info> {
    #[account(init, payer = user, space = 8 + 16)]
    pub stake_account: Account<'info, StakeAccount>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct StakeAccount {
    pub amount: u64,
    pub timestamp: i64,
}