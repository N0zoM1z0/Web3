use anchor_lang::prelude::*;

pub const COINS_PER_GEM: u64 = 1000;

// seeds = ["shark_market", authority]
#[account]
pub struct SharkMarket {
    pub authority: Pubkey,
    pub coin_mint: Pubkey,
    pub gem_mint: Pubkey,
    pub coin_vault: Pubkey, // global vault for shark_market
    pub gem_vault: Pubkey,  // global vault for shark_market
    pub transfer_fee_bps: u64,
    pub vaults_authority_bump: u8,
}
