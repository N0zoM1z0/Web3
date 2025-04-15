pub mod item;
pub mod shark_market;
pub mod user;

pub const SHARK_MARKET_SEED: &[u8] = b"shark_market";
pub const USER_SEED: &[u8] = b"shark_user";
pub const ITEM_SEED: &[u8] = b"shark_item";

pub const VAULTS_AUTHORITY_SEED: &[u8] = b"vaults_authority";

pub const COIN_VAULT_SEED: &[u8] = b"coin_vault";
pub const GEM_VAULT_SEED: &[u8] = b"gem_vault";

pub use item::*;
pub use shark_market::*;
pub use user::*;
