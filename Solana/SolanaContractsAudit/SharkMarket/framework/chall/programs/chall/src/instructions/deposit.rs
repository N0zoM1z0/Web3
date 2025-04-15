use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, TransferChecked};

use crate::{
    error::MarketError,
    math::U128,
    states::{SharkMarket, User, COINS_PER_GEM, USER_SEED, VAULTS_AUTHORITY_SEED},
};

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,

    /// CHECK: Global
    #[account(
        seeds = [VAULTS_AUTHORITY_SEED],
        bump
    )]
    pub vaults_authority: AccountInfo<'info>,

    pub market: Account<'info, SharkMarket>,

    #[account(
        mut,
        seeds = [USER_SEED, market.key().as_ref(), owner.key().as_ref()],
        bump,
    )]
    pub shark_user: Account<'info, User>,

    #[account(
        mut,
        token::authority = owner,
        token::mint = mint,
    )]
    pub owner_source_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        token::authority = vaults_authority,
        token::mint = mint,
    )]
    pub destination_token_account: Account<'info, TokenAccount>,

    pub mint: Account<'info, Mint>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct DepositArgs {
    pub deposit_amount: u64,
}

pub fn handler(ctx: Context<Deposit>, args: DepositArgs) -> Result<()> {
    let source_mint = ctx.accounts.mint.key();
    let user = &mut ctx.accounts.shark_user;
    let deposit_amount = args.deposit_amount;

    let deposited_coins = if source_mint == ctx.accounts.market.coin_mint {
        require!(
            ctx.accounts.destination_token_account.key() == ctx.accounts.market.coin_vault,
            MarketError::MissMatchedMint
        );
        U128::from(deposit_amount)
    } else if source_mint == ctx.accounts.market.gem_mint {
        require!(
            ctx.accounts.destination_token_account.key() == ctx.accounts.market.gem_vault,
            MarketError::MissMatchedMint
        );
        U128::from(deposit_amount)
            .checked_mul(U128::from(COINS_PER_GEM))
            .unwrap()
    } else {
        return err!(MarketError::MissMatchedMint);
    };

    let fee = deposited_coins
        .checked_mul(U128::from(ctx.accounts.market.transfer_fee_bps))
        .unwrap()
        .checked_div(U128::from(10000))
        .unwrap();

    let amount = deposited_coins.saturating_sub(fee).as_u128();
    user.total_balance = user.total_balance.checked_add(amount).unwrap();

    let cpi_accounts = TransferChecked {
        from: ctx.accounts.owner_source_token_account.to_account_info(),
        to: ctx.accounts.destination_token_account.to_account_info(),
        authority: ctx.accounts.owner.to_account_info(),
        mint: ctx.accounts.mint.to_account_info(),
    };
    let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
    token::transfer_checked(cpi_ctx, args.deposit_amount, ctx.accounts.mint.decimals)?;

    Ok(())
}
