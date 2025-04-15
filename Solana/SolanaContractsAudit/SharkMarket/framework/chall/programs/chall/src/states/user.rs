use anchor_lang::prelude::*;

// seeds = ["shark_user", market, authority]
#[account]
pub struct User {
    pub authority: Pubkey,
    pub market: Pubkey,
    pub total_balance: u128,
}
