use anchor_lang::prelude::*;
use anchor_lang::system_program;

declare_id!("6vxyM2QFNg3njwCQksy4K8azF5NwKxiUkEEG2hxqz15h");

// Written by: @nem0thefinder

#[program]
pub mod rustfund {
    use super::*;

    pub fn fund_create(ctx: Context<FundCreate>, name: String, description: String, goal: u64) -> Result<()> {
        let fund = &mut ctx.accounts.fund;
        fund.name = name;
        fund.description = description;
        fund.goal = goal;
        fund.deadline = 0;
        fund.creator = ctx.accounts.creator.key();
        fund.amount_raised = 0;
        fund.dealine_set = false;
        Ok(())
    }


    pub fn contribute(ctx: Context<FundContribute>, amount: u64) -> Result<()> {
        let fund = &mut ctx.accounts.fund;
        let contribution = &mut ctx.accounts.contribution;
        
        if fund.deadline != 0 && fund.deadline < Clock::get().unwrap().unix_timestamp.try_into().unwrap() {
            return Err(ErrorCode::DeadlineReached.into());
        }
    
        // Initialize or update contribution record
        if contribution.contributor == Pubkey::default() {
            contribution.contributor = ctx.accounts.contributor.key();
            contribution.fund = fund.key();
            contribution.amount = 0;
        }
        
        // Transfer SOL from contributor to fund account
        let cpi_context = CpiContext::new(
            ctx.accounts.system_program.to_account_info(),
            system_program::Transfer {
                from: ctx.accounts.contributor.to_account_info(),
                to: fund.to_account_info(),
            },
        );
        system_program::transfer(cpi_context, amount)?;
        
        fund.amount_raised += amount;
        Ok(())
    }
    

    pub fn set_deadline(ctx: Context<FundSetDeadline>, deadline: u64) -> Result<()> {
        let fund = &mut ctx.accounts.fund;
        if fund.dealine_set {
            return Err(ErrorCode::DeadlineAlreadySet.into());
        }
        
        fund.deadline = deadline;
        Ok(())
    }


    pub fn refund(ctx: Context<FundRefund>) -> Result<()> {
  
        let amount = ctx.accounts.contribution.amount;
        if ctx.accounts.fund.deadline != 0 && ctx.accounts.fund.deadline > Clock::get().unwrap().unix_timestamp.try_into().unwrap() {
            return Err(ErrorCode::DeadlineNotReached.into());  
        }
    
        **ctx.accounts.fund.to_account_info().try_borrow_mut_lamports()? = 
        ctx.accounts.fund.to_account_info().lamports()
        .checked_sub(amount)
        .ok_or(ProgramError::InsufficientFunds)?;
        
        **ctx.accounts.contributor.to_account_info().try_borrow_mut_lamports()? = 
        ctx.accounts.contributor.to_account_info().lamports()
        .checked_add(amount)
        .ok_or(ErrorCode::CalculationOverflow)?;


        // Reset contribution amount after refund
        ctx.accounts.contribution.amount = 0;
        
        Ok(())
    }

    pub fn withdraw(ctx: Context<FundWithdraw>) -> Result<()> {
    /*
    Missing check of GOAL and DEADLINE!!!
    */
        let amount = ctx.accounts.fund.amount_raised;
        
        **ctx.accounts.fund.to_account_info().try_borrow_mut_lamports()? = 
            ctx.accounts.fund.to_account_info().lamports()
            .checked_sub(amount)
            .ok_or(ProgramError::InsufficientFunds)?;
            
        **ctx.accounts.creator.to_account_info().try_borrow_mut_lamports()? = 
            ctx.accounts.creator.to_account_info().lamports()
            .checked_add(amount)
            .ok_or(ErrorCode::CalculationOverflow)?;
            
    
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(name: String)]
pub struct FundCreate<'info> {
    #[account(init, payer = creator, space = 8 + Fund::INIT_SPACE,seeds = [name.as_bytes(),creator.key().as_ref()], bump)]
    pub fund: Account<'info, Fund>,
    #[account(mut)]
    pub creator: Signer<'info>,
    pub system_program: Program<'info, System>,
}


#[derive(Accounts)]
pub struct FundContribute<'info> {
    #[account(mut)]
    pub fund: Account<'info, Fund>,
    #[account(mut)]
    pub contributor: Signer<'info>,
    #[account(
        init_if_needed,
        payer = contributor,
        space = 8 + Contribution::INIT_SPACE,
        seeds = [fund.key().as_ref(), contributor.key().as_ref()],
        bump
    )]
    pub contribution: Account<'info, Contribution>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct FundSetDeadline<'info> {
    #[account(mut,has_one = creator)]
    pub fund: Account<'info, Fund>,
    #[account(mut)]
    pub creator: Signer<'info>,
}

#[derive(Accounts)]
pub struct FundRefund<'info> {
    #[account(mut)]
    pub fund: Account<'info, Fund>,
    #[account(
        mut,
        seeds = [fund.key().as_ref(), contributor.key().as_ref()],
        bump,
        has_one=contributor,
        has_one=fund
    )]
    pub contribution: Account<'info, Contribution>,
    #[account(mut)]
    pub contributor: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct FundWithdraw<'info> {
    #[account(mut, seeds = [fund.name.as_bytes(), creator.key().as_ref()], bump,has_one = creator)]
    pub fund: Account<'info, Fund>,
    #[account(mut)]
    pub creator: Signer<'info>,
    pub system_program: Program<'info, System>,
}


#[account]
#[derive(InitSpace)]
pub struct Contribution {
    pub contributor: Pubkey,
    pub fund: Pubkey,
    pub amount: u64,
}

#[account]
#[derive(InitSpace)]
pub struct Fund {
    #[max_len(200)]
    pub name: String,
    #[max_len(5000)]
    pub description: String,
    pub goal: u64,
    pub deadline: u64,
    pub creator: Pubkey,
    pub amount_raised: u64,
    pub dealine_set: bool,
}



#[error_code]
pub enum ErrorCode {
    #[msg("Deadline already set")]
    DeadlineAlreadySet,
    #[msg("Deadline reached")]
    DeadlineReached,
    #[msg("Deadline not reached")]
    DeadlineNotReached,
    #[msg("Unauthorized access")]
    UnauthorizedAccess,
    #[msg("Calculation overflow occurred")]
    CalculationOverflow,
}

