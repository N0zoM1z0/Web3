use std::{io::Read, net::TcpStream};

use chall::anchor_lang::InstructionData;
use chall::anchor_lang::ToAccountMetas;
use chall::InitializeMarketArgs;
use chall::ListItemArgs;
use solana_sdk::instruction::Instruction;
use solana_sdk::pubkey;
use solana_sdk::pubkey::Pubkey;
use uuid::Uuid;

const SPL_TOKEN_ID: Pubkey = pubkey!("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA");

pub async fn read_instructions(mut socket: &TcpStream) -> anyhow::Result<Vec<Instruction>> {
    let mut buf = [0; 8];
    socket.read_exact(&mut buf)?;
    let len = u64::from_le_bytes(buf);
    let mut buf = vec![0; len as usize];
    socket.read_exact(&mut buf)?;
    let instructions = serde_json::from_slice(&buf)?;
    Ok(instructions)
}

pub fn initialize_market_instruction(
    authority: Pubkey,
    market: Pubkey,
    coin_mint: Pubkey,
    gem_mint: Pubkey,
    vaults_authority: Pubkey,
    coin_vault: Pubkey,
    gem_vault: Pubkey,
    transfer_fee_bps: u64,
) -> Instruction {
    let ix_accounts = chall::accounts::InitializeMarket {
        authority,
        market,
        coin_mint,
        gem_mint,
        vaults_authority,
        coin_vault,
        gem_vault,
        token_program: SPL_TOKEN_ID,
        system_program: solana_program::system_program::ID,
    };
    let ix = chall::instruction::InitializeMarket {
        args: InitializeMarketArgs { transfer_fee_bps },
    };
    return Instruction::new_with_bytes(chall::ID, &ix.data(), ix_accounts.to_account_metas(None));
}

pub fn initialize_user_instruction(
    owner: Pubkey,
    market: Pubkey,
) -> Instruction {
    let (shark_user, _) = Pubkey::find_program_address(
        &[
            chall::states::USER_SEED,
            &market.to_bytes(),
            &owner.to_bytes(),
        ],
        &chall::ID,
    );

    let ix_accounts = chall::accounts::InitializeUser {
        owner,
        market,
        shark_user,
        system_program: solana_program::system_program::ID,
    };

    let ix = chall::instruction::InitializeUser {};

    return Instruction::new_with_bytes(chall::ID, &ix.data(), ix_accounts.to_account_metas(None));
}

pub fn list_item_instruction(
    issuer: Pubkey,
    market: Pubkey,
    uuid: Option<Uuid>,
    price: u128,
    discribtion: String,
) -> (Instruction, Uuid) {
    let uuid = uuid.unwrap_or_else(|| Uuid::new_v4());
    // seeds = ["shark_item", market, uuid]
    let shark_item = Pubkey::find_program_address(
        &[
            chall::states::ITEM_SEED,
            &market.to_bytes(),
            uuid.as_bytes(),
        ],
        &chall::ID,
    )
    .0;

    let ix_accounts = chall::accounts::ListItem {
        issuer,
        market,
        shark_item,
        system_program: solana_program::system_program::ID,
    };
    let ix = chall::instruction::ListItem {
        args: ListItemArgs {
            item_uuid: uuid.into_bytes(),
            price,
            discribtion,
        },
    };

    (
        Instruction::new_with_bytes(chall::ID, &ix.data(), ix_accounts.to_account_metas(None)),
        uuid,
    )
}

pub fn swap_instruction(
    owner: Pubkey,
    owner_source_token_account: Pubkey,
    owner_destination_token_account: Pubkey,
    market: Pubkey,
    coin_vault: Pubkey,
    coin_mint: Pubkey,
    gem_vault: Pubkey,
    gem_mint: Pubkey,
    amount: u64,
) -> Instruction {
    let vaults_authority = Pubkey::find_program_address(
        &[
            chall::states::VAULTS_AUTHORITY_SEED,
        ], &chall::ID).0;

    let ix_accounts = chall::accounts::Swap {
        owner,
        owner_source_token_account,
        owner_destination_token_account,
        vaults_authority,
        market,
        coin_vault,
        coin_mint,
        gem_vault,
        gem_mint,
        token_program: SPL_TOKEN_ID,
        system_program: solana_program::system_program::ID,
    };
    let ix = chall::instruction::Swap {
        args: chall::instructions::SwapArgs {
            swap_amount: amount
        },
    };

    return Instruction::new_with_bytes(chall::ID, &ix.data(), ix_accounts.to_account_metas(None));
}

pub fn deposit_instruction(
    owner: Pubkey,
    market: Pubkey,
    owner_source_token_account: Pubkey,
    destination_token_account: Pubkey,
    mint: Pubkey,
    amount: u64,
) -> Instruction {

    let shark_user = Pubkey::find_program_address(
        &[
            chall::states::USER_SEED,
            &market.to_bytes(),
            &owner.to_bytes(),
        ],
        &chall::ID).0;

    let vaults_authority = Pubkey::find_program_address(
        &[
            chall::states::VAULTS_AUTHORITY_SEED,
        ], &chall::ID).0;

    let ix_accounts = chall::accounts::Deposit {
        owner,
        vaults_authority,
        market,
        shark_user,
        owner_source_token_account,
        destination_token_account,
        mint,
        token_program: SPL_TOKEN_ID,
        system_program: solana_program::system_program::ID,
    };

    let ix = chall::instruction::Deposit {
        args: chall::instructions::DepositArgs {
            deposit_amount: amount
        },
    };

    return Instruction::new_with_bytes(chall::ID, &ix.data(), ix_accounts.to_account_metas(None));

}

pub fn buy_item_instruction(
    authority: Pubkey,
    market: Pubkey,
    shark_item: Pubkey,
    seller: Pubkey,
) -> Instruction {

    let buyer = Pubkey::find_program_address(
        &[
            chall::states::USER_SEED,
            &market.to_bytes(),
            &authority.to_bytes(),
        ],
        &chall::ID).0;

    let ix_accounts = chall::accounts::BuyItem {
        authority,
        market,
        shark_item,
        buyer,
        seller,
        system_program: solana_program::system_program::ID,
    };

    let ix = chall::instruction::BuyItem {};
    return Instruction::new_with_bytes(chall::ID, &ix.data(), ix_accounts.to_account_metas(None));
}