use anchor_lang::prelude::*;

// seeds = ["shark_item", market, uuid]
#[account]
#[derive(InitSpace)]
pub struct Item {
    pub uuid: [u8; 16],
    pub market: Pubkey,
    pub issuer: Pubkey,
    pub price: u128,
    pub status: ItemStatus,
    #[max_len(50)]
    pub discribtion: String,
}

#[repr(u8)]
#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace, PartialEq, Default, Debug)]
pub enum ItemStatus {
    #[default]
    Uninitialized,
    Listed,
    Sold(Pubkey),
}
