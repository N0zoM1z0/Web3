use chall::anchor_lang::AccountDeserialize;
use chall::anchor_lang::Key;
use chall::states::Item;
use challenge::ChallengeBuilder;
use challenge::ProofOfWork;
use ixs_utils::create_ata_instruction;
use ixs_utils::initialize_market_instruction;
use ixs_utils::initialize_user_instruction;
use ixs_utils::list_item_instruction;
use ixs_utils::read_instructions;
use solana_program_test::tokio;
use solana_sdk::account::ReadableAccount;
use solana_sdk::{
    pubkey::Pubkey, signature::Keypair, signer::Signer,
    system_instruction,
};
use std::env;
use std::io::Write;
use std::{
    io::BufReader,
    net::{TcpListener, TcpStream},
};
use utils::get_line;

pub mod challenge;
pub mod ixs_utils;
pub mod utils;

static WHITELIST_PROGRAMS: [Pubkey; 3] = [
    chall::ID,
    solana_program::system_program::ID,
    spl_associated_token_account::ID
];

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let listener = TcpListener::bind("0.0.0.0:1337")?;
    println!("starting server at port 1337!");
    for stream in listener.incoming() {
        if stream.is_err() {
            println!("error: {:?}", stream.err());
            continue;
        }
        let mut stream = stream.unwrap();

        tokio::spawn(async move {
            if let Err(err) = handle_connection(&mut stream).await {
                let _ = writeln!(stream, "error: {:?}", err);
                println!("error: {:?}", err);
            }
        });
    }
    Ok(())
}

async fn handle_pow(socket: &mut TcpStream) -> anyhow::Result<()> {
    let pow = ProofOfWork::new();
    let prefix = pow.prefix.clone();
    writeln!(socket, "prefix: {}", prefix)?;
    let mut reader = BufReader::new(socket.try_clone()?);
    let nonce = get_line(&mut reader)?;
    let nonce = nonce.parse::<u128>()?;
    if !pow.verify(nonce) {
        writeln!(socket, "invalid nonce")?;
        return Err(anyhow::anyhow!("invalid nonce"));
    };
    Ok(())
}


async fn handle_connection(socket: &mut TcpStream) -> anyhow::Result<()> {

    // Proof of Work
    handle_pow(socket).await?;

    // Prepare challenge
    //
    // 1. load challenge program
    let mut builder = ChallengeBuilder::try_from(socket.try_clone().unwrap()).unwrap();

    #[cfg(debug_assertions)]
    assert!(builder.add_program("./chall/target/deploy/chall.so", Some(chall::ID)) == chall::ID);
    #[cfg(not(debug_assertions))]
    assert!(builder.add_program("./chall.so", Some(chall::ID)) == chall::ID);

    let mut chall = builder.build().await;

    // 2. create user account
    let user_keypair = Keypair::new();
    let user = user_keypair.pubkey();

    let admin_keypair = &chall.ctx.payer;
    let admin = admin_keypair.pubkey();

    // airdrop for gas fee
    chall
        .run_ix(system_instruction::transfer(&admin, &user, 100_000_000_000))
        .await?;

    // 3. prepare other accounts
    let coin_mint = chall.add_mint().await?;
    let gem_mint = chall.add_mint().await?;
    let market = Pubkey::find_program_address(
        &[chall::states::SHARK_MARKET_SEED, admin.as_ref()],
        &chall::ID,
    )
    .0;
    let vaults_authority =
        Pubkey::find_program_address(&[chall::states::VAULTS_AUTHORITY_SEED], &chall::ID).0;
    let coin_vault = Pubkey::find_program_address(&[coin_mint.key().as_ref()], &chall::ID).0;
    let gem_vault = Pubkey::find_program_address(&[gem_mint.key().as_ref()], &chall::ID).0;


    // 4. initialize market
    let initialize_market_ix = initialize_market_instruction(
        admin,
        market,
        coin_mint,
        gem_mint,
        vaults_authority,
        coin_vault,
        gem_vault,
        50,
    );
    println!("{:?}", initialize_market_ix.accounts);
    chall.run_ix(initialize_market_ix).await?;

    
    // initialize admin user
    let initialize_admin_ix = initialize_user_instruction(
        admin,
        market
    );
    chall.run_ix(initialize_admin_ix).await?;

    // mint 100 coin to coin_vault
    chall
        .mint_to(100_000_000_000, &coin_mint, &coin_vault)
        .await?;

    // mint 100 gem to gem_vault
    chall.mint_to(100_000_000_000, &gem_mint, &gem_vault).await?;

    // mint 0.01 gem to admin
    let (admin_gem_ata_ix, admin_gem_ata) = create_ata_instruction(admin, gem_mint);
    chall.run_ix(admin_gem_ata_ix).await?;
    chall.mint_to(10_000_000, &gem_mint, &admin_gem_ata).await?;

    // mint 0.0001 coin to user
    let (user_coin_ata_ix, user_coin_ata) = create_ata_instruction(user, coin_mint);
    chall.run_ixs_full(&[user_coin_ata_ix], &[&user_keypair], &user).await?;
    chall.mint_to(100_000, &coin_mint, &user_coin_ata).await?;

    // 0 gem for user
    let (user_gem_ata_ix, user_gem_ata) = create_ata_instruction(user, gem_mint);
    chall.run_ixs_full(&[user_gem_ata_ix], &[&user_keypair], &user).await?;
    
    // 5. admin list the flag item
    let (list_flag_item_ix, flag_item) = list_item_instruction(
        admin,
        market,
        None,
        90_000_000_000, // 90 coin
        "Buy Me and Get the Flag!".to_string(),
    );
    chall.run_ix(list_flag_item_ix).await?;

    let (flag_item_account, _) = Pubkey::find_program_address(
        &[
            chall::states::ITEM_SEED,
            &market.to_bytes(),
            flag_item.as_bytes(),
        ],
        &chall::ID,
    );

    writeln!(socket, "admin: {}", admin)?;
    writeln!(socket, "user: {}", user)?;
    writeln!(socket, "user coin ATA: {}", user_coin_ata)?;
    writeln!(socket, "user gem ATA: {}", user_gem_ata)?;
    writeln!(socket, "coin_mint: {}", coin_mint)?;
    writeln!(socket, "gem_mint: {}", gem_mint)?;
    writeln!(socket, "market: {}", market)?;
    writeln!(socket, "vaults_authority: {}", vaults_authority)?;
    writeln!(socket, "coin_vault: {}", coin_vault)?;
    writeln!(socket, "gem_vault: {}", gem_vault)?;
    writeln!(socket, "flag_item_uuid: {}", flag_item)?;
    writeln!(socket, "flag_item_account: {}", flag_item_account)?;
    
    // Reading solution
    let solve_ixs = read_instructions(&socket).await?;

    if solve_ixs.len() > 10 {
        writeln!(socket, "Too many instructions")?;
        return Ok(());
    }
    for solve_ix in solve_ixs {
        if! WHITELIST_PROGRAMS.contains(&solve_ix.program_id) {
            writeln!(socket, "invalid program id")?;
            return Ok(());
        }
        chall
            .run_ixs_full(&[solve_ix], &[&user_keypair], &user)
            .await?;
    }

    // Verify solution:
    // user has bought the flag item
    let item: Item = chall::states::Item::try_deserialize(
        &mut chall
            .ctx
            .banks_client
            .get_account(flag_item_account)
            .await?
            .unwrap()
            .data()
            .as_ref()   
    )?;

    println!("{:?}", item.status);

    if item.status != chall::states::ItemStatus::Sold(user) {
        writeln!(socket, "flag item not sold to user")?;
        return Ok(());
    }

    writeln!(socket, "congrats! you won the flag!")?;
    if let Ok(flag) = env::var("FLAG") {
        writeln!(socket, "flag: {}", flag)?;
    } else {
        writeln!(socket, "flag not found, please contact admin")?;
    }
    Ok(())
}
