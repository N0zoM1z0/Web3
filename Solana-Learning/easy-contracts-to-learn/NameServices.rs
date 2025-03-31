use anchor_lang::prelude::*;

declare_id!("YourProgramIdHere");

#[program]
pub mod name_service {
    use super::*;

    pub fn register(ctx: Context<Register>, name: String) -> Result<()> {
        let name_record = &mut ctx.accounts.name_record;
        name_record.owner = *ctx.accounts.user.key;
        name_record.name = name;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Register<'info> {
    #[account(init, payer = user, space = 8 + 32 + 32)]
    pub name_record: Account<'info, NameRecord>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct NameRecord {
    pub owner: Pubkey,
    pub name: String,
}