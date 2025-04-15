use std::str::FromStr;
use std::{io::BufReader, net::TcpStream};
use std::io::{Read, Write};

pub mod utils;
pub mod ixs_utils;

use solana_program::pubkey;
use solana_sdk::instruction::Instruction;
use uuid::Uuid;
use crate::pubkey::Pubkey;
pub use utils::get_line;
use utils::ProofOfWork;


fn main() -> anyhow::Result<()> {
    let mut stream = TcpStream::connect("127.0.0.1:1337")?;
    let mut reader = BufReader::new(stream.try_clone()?);

    // solve proof of work
    println!("Solving proof of work...");
    let prefix = get_line(&mut reader)?;
    let pow = ProofOfWork::from(prefix);
    let nonce = pow.calculate();
    writeln!(stream, "nonce: {}", nonce)?;


    let challenge_program = chall::ID;
    let admin = Pubkey::from_str(&get_line(&mut reader)?)?;
    let user = Pubkey::from_str(&get_line(&mut reader)?)?;
    let user_coin_ata = Pubkey::from_str(&get_line(&mut reader)?)?;
    let user_gem_ata = Pubkey::from_str(&get_line(&mut reader)?)?;
    let coin_mint = Pubkey::from_str(&get_line(&mut reader)?)?;
    let gem_mint = Pubkey::from_str(&get_line(&mut reader)?)?;
    let market = Pubkey::from_str(&get_line(&mut reader)?)?;
    let vaults_authority = Pubkey::from_str(&get_line(&mut reader)?)?;
    let coin_vault = Pubkey::from_str(&get_line(&mut reader)?)?;
    let gem_vault = Pubkey::from_str(&get_line(&mut reader)?)?;
    let flag_item_uuid = Uuid::from_str(&get_line(&mut reader)?)?;
    let flag_item_account = Pubkey::from_str(&get_line(&mut reader)?)?;

    println!("admin: {}", admin);
    println!("user: {}", user);
    println!("coin_mint: {}", coin_mint);
    println!("gem_mint: {}", gem_mint);
    println!("market: {}", market);
    println!("vaults_authority: {}", vaults_authority);
    println!("coin_vault: {}", coin_vault);
    println!("gem_vault: {}", gem_vault);
    println!("flag_item_uuid: {}", flag_item_uuid);
    println!("flag_item_account: {}", flag_item_account);

    let mut instructions = Vec::<Instruction>::new();
    
    // --------------------------------
    // your solution here
    // Don't forget to push your instruction to `instructions`

    // ...

    // --------------------------------
    // you don't need to modify code blow
    
    let send_data = serde_json::to_vec(&instructions)?;
    let len = send_data.len() as u64;
    stream.write_all(&len.to_le_bytes())?;
    stream.write_all(&send_data)?;

    let mut response = Vec::<u8>::new();
    stream.read_to_end(&mut response)?;
    let response = String::from_utf8(response)?;
    println!("{}", response);
    Ok(())
}