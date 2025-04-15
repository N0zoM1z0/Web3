use anchor_lang::prelude::*;

use crate::{
    error::MarketError,
    states::{Item, ItemStatus, SharkMarket, User, ITEM_SEED, USER_SEED},
};

#[derive(Accounts)]
pub struct BuyItem<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    pub market: Account<'info, SharkMarket>,

    #[account(
        mut,
        seeds = [ITEM_SEED, market.key().as_ref(), &shark_item.uuid],
        bump,
        has_one = market
    )]
    pub shark_item: Account<'info, Item>,

    #[account(
        mut,
        seeds = [USER_SEED, market.key().as_ref(), authority.key().as_ref()],
        bump,
        has_one = market,
        has_one = authority,
    )]
    pub buyer: Account<'info, User>,

    #[account(
        mut,
        seeds = [USER_SEED, market.key().as_ref(), shark_item.issuer.key().as_ref()],
        bump,
        has_one = market,
    )]
    pub seller: Account<'info, User>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<BuyItem>) -> Result<()> {
    let item = &mut ctx.accounts.shark_item;
    let buyer = &mut ctx.accounts.buyer;
    let seller = &mut ctx.accounts.seller;

    require!(
        buyer.total_balance >= item.price,
        MarketError::NoEnoughBalance
    );

    require!(
        item.status == ItemStatus::Listed,
        MarketError::ItemAlreadySold
    );

    item.status = ItemStatus::Sold(ctx.accounts.authority.key());

    buyer.total_balance -= item.price;
    seller.total_balance += item.price;

    Ok(())
}
