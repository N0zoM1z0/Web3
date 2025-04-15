use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token, TokenAccount};

use crate::states::{SharkMarket, SHARK_MARKET_SEED, VAULTS_AUTHORITY_SEED};

#[derive(Accounts)]
pub struct InitializeMarket<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        seeds = [SHARK_MARKET_SEED, authority.key().as_ref()],
        bump,
        space = 8 + core::mem::size_of::<SharkMarket>(),
    )]
    pub market: Account<'info, SharkMarket>,

    #[account(
        mint::token_program = token_program,
    )]
    coin_mint: Account<'info, Mint>,

    #[account(
        mint::token_program = token_program,
    )]
    gem_mint: Account<'info, Mint>,

    /// CHECK: Global
    #[account(
        seeds = [VAULTS_AUTHORITY_SEED],
        bump
    )]
    pub vaults_authority: AccountInfo<'info>,

    #[account(
        init_if_needed,
        payer = authority,
        seeds = [coin_mint.key().as_ref()],
        bump,
        token::mint = coin_mint,
        token::authority = vaults_authority,
    )]
    pub coin_vault: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        payer = authority,
        seeds = [gem_mint.key().as_ref()],
        bump,
        token::mint = gem_mint,
        token::authority = vaults_authority,
    )]
    pub gem_vault: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct InitializeMarketArgs {
    pub transfer_fee_bps: u64,
}

pub fn handler(ctx: Context<InitializeMarket>, args: InitializeMarketArgs) -> Result<()> {
    let market = &mut ctx.accounts.market;
    market.authority = *ctx.accounts.authority.key;
    market.coin_mint = ctx.accounts.coin_mint.key();
    market.gem_mint = ctx.accounts.gem_mint.key();
    market.coin_vault = *ctx.accounts.coin_vault.to_account_info().key;
    market.gem_vault = *ctx.accounts.gem_vault.to_account_info().key;

    market.transfer_fee_bps = args.transfer_fee_bps;
    market.vaults_authority_bump = ctx.bumps.vaults_authority;
    Ok(())
}
