use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, TransferChecked};

use crate::error::MarketError;
use crate::states::{SharkMarket, VAULTS_AUTHORITY_SEED};

#[derive(Accounts)]
pub struct Swap<'info> {
    #[account(mut)]
    pub owner: Signer<'info>,

    #[account(
        mut,
        token::authority = owner,
    )]
    pub owner_source_token_account: Account<'info, TokenAccount>,

    #[account(
        mut,
        token::authority = owner,
    )]
    pub owner_destination_token_account: Account<'info, TokenAccount>,

    /// CHECK: Global
    #[account(
        seeds = [VAULTS_AUTHORITY_SEED],
        bump
    )]
    pub vaults_authority: AccountInfo<'info>,

    #[account(
        has_one = coin_mint,
        has_one = gem_mint,
        has_one = coin_vault,
        has_one = gem_vault,
    )]
    pub market: Account<'info, SharkMarket>,

    pub coin_mint: Account<'info, Mint>,
    pub gem_mint: Account<'info, Mint>,

    #[account(mut)]
    pub coin_vault: Account<'info, TokenAccount>,

    #[account(mut)]
    pub gem_vault: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct SwapArgs {
    pub swap_amount: u64,
}

pub fn handler(ctx: Context<Swap>, args: SwapArgs) -> Result<()> {
    let input_amount = args.swap_amount;

    if ctx.accounts.owner_source_token_account.mint == ctx.accounts.market.coin_mint {
        // swap coin to gem
        let gem_amount = input_amount / crate::states::COINS_PER_GEM; // 整除截断损失精度
        let gem_amount = gem_amount - (gem_amount * ctx.accounts.market.transfer_fee_bps / 1000); // bps 通常指基点 (Basis Points, 万分之一)。 潜在问题2: 手续费计算精度。代码中除以 1000，这意味着 transfer_fee_bps 存储的可能是 千分点 (per mille) 或者 扩大了 10 倍的基点 (例如存 50 代表 0.5%)。如果是标准的基点，应该除以 10000。这需要检查 transfer_fee_bps 的定义和初始化逻辑。
        let output_amount = gem_amount as u64;

        let cpi_accounts = TransferChecked {
            from: ctx.accounts.owner_source_token_account.to_account_info(),
            to: ctx.accounts.coin_vault.to_account_info(),
            authority: ctx.accounts.owner.to_account_info(),
            mint: ctx.accounts.coin_mint.to_account_info(),
        };

        let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
        token::transfer_checked(cpi_ctx, input_amount, ctx.accounts.coin_mint.decimals)?;

        let vault_seed = &[VAULTS_AUTHORITY_SEED, &[ctx.bumps.vaults_authority]];
        let signer_seeds = &[&vault_seed[..]];
        let cpi_accounts = TransferChecked {
            from: ctx.accounts.gem_vault.to_account_info(),
            to: ctx
                .accounts
                .owner_destination_token_account
                .to_account_info(),
            authority: ctx.accounts.vaults_authority.to_account_info(),
            mint: ctx.accounts.gem_mint.to_account_info(),
        };
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer_seeds,
        );
        token::transfer_checked(cpi_ctx, output_amount, ctx.accounts.gem_mint.decimals)?;
    } else if ctx.accounts.owner_source_token_account.mint == ctx.accounts.market.gem_mint {
        // swap gem to coin
        let coin_amount = input_amount * crate::states::COINS_PER_GEM;
        let coin_amount = coin_amount - (coin_amount * ctx.accounts.market.transfer_fee_bps / 1000);
        let output_amount = coin_amount as u64;

        let cpi_accounts = TransferChecked {
            from: ctx.accounts.owner_source_token_account.to_account_info(),
            to: ctx.accounts.gem_vault.to_account_info(),
            authority: ctx.accounts.owner.to_account_info(),
            mint: ctx.accounts.gem_mint.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts);
        token::transfer_checked(cpi_ctx, input_amount, ctx.accounts.gem_mint.decimals)?;

        let vault_seed = &[VAULTS_AUTHORITY_SEED, &[ctx.bumps.vaults_authority]];
        let signer_seeds = &[&vault_seed[..]];
        let cpi_accounts = TransferChecked {
            from: ctx.accounts.coin_vault.to_account_info(),
            to: ctx
                .accounts
                .owner_destination_token_account
                .to_account_info(),
            authority: ctx.accounts.vaults_authority.to_account_info(),
            mint: ctx.accounts.coin_mint.to_account_info(),
        };
        let cpi_ctx = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            signer_seeds,
        );
        token::transfer_checked(cpi_ctx, output_amount, ctx.accounts.coin_mint.decimals)?;
    } else {
        return err!(MarketError::MissMatchedMint);
    }
    Ok(())
}
