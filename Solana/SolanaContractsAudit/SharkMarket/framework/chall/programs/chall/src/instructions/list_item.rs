use anchor_lang::prelude::*;

use crate::{
    error::MarketError,
    states::{Item, ItemStatus, SharkMarket, ITEM_SEED},
};

#[derive(Accounts)]
#[instruction(args: ListItemArgs)]
pub struct ListItem<'info> {
    #[account(mut)]
    pub issuer: Signer<'info>,

    pub market: Account<'info, SharkMarket>,

    #[account(
        init_if_needed,
        payer = issuer,
        seeds = [ITEM_SEED, market.key().as_ref(), &args.item_uuid],
        bump,
        space = 8 + Item::INIT_SPACE,
    )]
    pub shark_item: Account<'info, Item>,

    pub system_program: Program<'info, System>,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct ListItemArgs {
    pub item_uuid: [u8; 16],
    pub price: u128,
    pub discribtion: String,
}

pub fn handler(ctx: Context<ListItem>, args: ListItemArgs) -> Result<()> {
    let item = &mut ctx.accounts.shark_item;
    let mut const_uuid = args.item_uuid;
    let mut const_discribtion = args.discribtion;

    if let ItemStatus::Listed = item.status {
        return Err(MarketError::ItemAlreadyListed.into());
    }

    // re list, keep uuid and discribtion
    if let ItemStatus::Sold(holder) = item.status {
        require!(
            holder == ctx.accounts.issuer.key(),
            MarketError::MissAuthority
        );
        const_uuid = item.uuid;
        const_discribtion = item.discribtion.clone();
    }

    item.set_inner(Item {
        issuer: ctx.accounts.issuer.key(),
        market: ctx.accounts.market.key(),
        uuid: const_uuid,
        price: args.price,
        status: ItemStatus::Listed,
        discribtion: const_discribtion,
    });

    Ok(())
}
