use anchor_lang::prelude::*;

declare_id!("YourProgramIdHere");

#[program]
pub mod crowdfunding {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, goal: u64) -> Result<()> {
        let campaign = &mut ctx.accounts.campaign;
        campaign.goal = goal; // 众筹目标
        campaign.raised = 0; // 已募捐的
        /*
        还需考虑 deadline 和 withDraw的实现
        */
        Ok(())
    }

    pub fn donate(ctx: Context<Donate>, amount: u64) -> Result<()> {
        let campaign = &mut ctx.accounts.campaign;
        **ctx.accounts.donor.try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.campaign.try_borrow_mut_lamports()? += amount;
        campaign.raised += amount;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = user, space = 8 + 16)]
    pub campaign: Account<'info, Campaign>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Donate<'info> {
    #[account(mut)]
    pub campaign: Account<'info, Campaign>,
    #[account(mut)]
    pub donor: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct Campaign {
    pub goal: u64,
    pub raised: u64,
}