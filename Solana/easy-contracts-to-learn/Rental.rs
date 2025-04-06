use anchor_lang::prelude::*;

declare_id!("YourProgramIdHere");

#[program]
pub mod rental {
    use super::*;

    pub fn create_rental(ctx: Context<CreateRental>, rent: u64) -> Result<()> {
        let rental = &mut ctx.accounts.rental;
        rental.owner = *ctx.accounts.owner.key;
        rental.rent = rent;
        rental.paid = false;
        Ok(())
    }

    pub fn pay_rent(ctx: Context<PayRent>) -> Result<()> {
        let rental = &mut ctx.accounts.rental;
        **ctx.accounts.renter.try_borrow_mut_lamports()? -= rental.rent;
        **ctx.accounts.owner.try_borrow_mut_lamports()? += rental.rent;
        rental.paid = true;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct CreateRental<'info> {
    #[account(init, payer = owner, space = 8 + 32 + 8 + 1)]
    pub rental: Account<'info, Rental>,
    #[account(mut)]
    pub owner: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct PayRent<'info> {
    #[account(mut)]
    pub rental: Account<'info, Rental>,
    #[account(mut)]
    pub renter: Signer<'info>,
    #[account(mut)]
    pub owner: AccountInfo<'info>,
}

#[account]
pub struct Rental {
    pub owner: Pubkey,
    pub rent: u64,
    pub paid: bool,
}