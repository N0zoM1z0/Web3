use anchor_lang::prelude::*;

#[error_code]
pub enum MarketError {
    MissMatchedMint,
    NoEnoughBalance,
    ItemAlreadySold,
    ItemAlreadyListed,
    MissAuthority,
}
