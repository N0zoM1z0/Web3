use anchor_lang::prelude::*;

declare_id!("DH2StKvowopFuomLGkQmMnEG8jAa4ooxcH8wbaubsAgt");

pub mod error;
pub mod instructions;
pub mod math;
pub mod states;

pub use anchor_lang;

pub use instructions::*;

#[program]
pub mod chall {
    use super::*;

    pub fn initialize_market(
        ctx: Context<InitializeMarket>,
        args: InitializeMarketArgs,
    ) -> Result<()> {
        instructions::initialize_market::handler(ctx, args)?;
        Ok(())
    }

    pub fn initialize_user(ctx: Context<InitializeUser>) -> Result<()> {
        instructions::initialize_user::handler(ctx)?;
        Ok(())
    }

    pub fn list_item(ctx: Context<ListItem>, args: ListItemArgs) -> Result<()> {
        instructions::list_item::handler(ctx, args)?;
        Ok(())
    }

    pub fn buy_item(ctx: Context<BuyItem>) -> Result<()> {
        instructions::buy_item::handler(ctx)?;
        Ok(())
    }

    pub fn swap(ctx: Context<Swap>, args: SwapArgs) -> Result<()> {
        instructions::swap::handler(ctx, args)?;
        Ok(())
    }

    pub fn deposit(ctx: Context<Deposit>, args: DepositArgs) -> Result<()> {
        instructions::deposit::handler(ctx, args)?;
        Ok(())
    }
}
