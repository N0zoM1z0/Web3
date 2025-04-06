use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token, TokenAccount};

declare_id!("YourProgramIdHere");

#[program]
pub mod nft_mint {
    use super::*;

    pub fn mint_nft(ctx: Context<MintNFT>) -> Result<()> {
        let nft_account = &mut ctx.accounts.nft_account;
        nft_account.owner = *ctx.accounts.user.key;
        token::mint_to(CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            token::MintTo {
                mint: ctx.accounts.mint.to_account_info(),
                to: ctx.accounts.token_account.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        ), 1)?;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct MintNFT<'info> {
    #[account(init, payer = user, space = 8 + 32)]
    pub nft_account: Account<'info, NFTAccount>,
    #[account(mut)]
    pub mint: Account<'info, Mint>,
    #[account(mut)]
    pub token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct NFTAccount {
    pub owner: Pubkey,
}