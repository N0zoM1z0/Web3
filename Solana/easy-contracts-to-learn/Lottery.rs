use anchor_lang::prelude::*;

declare_id!("YourProgramIdHere");

#[program]
pub mod lottery {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let lottery = &mut ctx.accounts.lottery;
        lottery.participants = Vec::new();
        lottery.winner = None;
        Ok(())
    }

    pub fn enter(ctx: Context<Enter>, ticket_price: u64) -> Result<()> {
        let lottery = &mut ctx.accounts.lottery;
        **ctx.accounts.user.try_borrow_mut_lamports()? -= ticket_price;
        **ctx.accounts.lottery.try_borrow_mut_lamports()? += ticket_price;
        lottery.participants.push(*ctx.accounts.user.key);
        Ok(())
    }

    pub fn pick_winner(ctx: Context<PickWinner>) -> Result<()> {
        /*
        未做权限控制
        且未锁定奖池
        还有奖池解封时间锁
        */
        let lottery = &mut ctx.accounts.lottery;
        let clock = Clock::get()?;
        let winner_index = (clock.unix_timestamp as usize) % lottery.participants.len();
        lottery.winner = Some(lottery.participants[winner_index]);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = user, space = 8 + 1024)]
    pub lottery: Account<'info, Lottery>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Enter<'info> {
    #[account(mut)]
    pub lottery: Account<'info, Lottery>,
    #[account(mut)]
    pub user: Signer<'info>,
}

#[derive(Accounts)]
pub struct PickWinner<'info> {
    #[account(mut)]
    pub lottery: Account<'info, Lottery>,
    pub authority: Signer<'info>,
}

#[account]
pub struct Lottery {
    pub participants: Vec<Pubkey>,
    pub winner: Option<Pubkey>,
}