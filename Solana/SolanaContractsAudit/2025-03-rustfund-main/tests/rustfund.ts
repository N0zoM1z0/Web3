import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Rustfund } from "../target/types/rustfund";
import { PublicKey } from '@solana/web3.js';
import { expect } from 'chai';
describe("rustfund", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.Rustfund as Program<Rustfund>;
  const creator = provider.wallet;
  const otherUser = anchor.web3.Keypair.generate();


  const fundName = "firstflight Fund";
  const description = "this program is for firstflight";
  const goal = new anchor.BN(1000000000); // 1 SOL
  const contribution = new anchor.BN(500000000); //0.5 SOL
  const deadline = new anchor.BN(Math.floor(Date.now() / 1000) + 10); //  10 sec from now (testing)

  let fundPDA: PublicKey;
  let fundBump: number;
  let contributionPDA: PublicKey;
  let contributionBump: number;

  before(async () => {
    // Generate PDA for fund
    [fundPDA, fundBump] = await PublicKey.findProgramAddress(
      [Buffer.from(fundName), creator.publicKey.toBuffer()],
      program.programId
    );
  });

  it("Creates a fund", async () => {
    await program.methods
      .fundCreate(fundName, description, goal)
      .accounts({
        fund: fundPDA,
        creator: creator.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    const fund = await program.account.fund.fetch(fundPDA);
    console.log("fundName", fund.name);
    console.log("fundDescription", fund.description);
    console.log("fundGoal", fund.goal);
    console.log("fundCreator", fund.creator);
    console.log("fundAmountRaised", fund.amountRaised);
  });


  it("Sets a deadline", async () => {
    await program.methods
      .setDeadline(deadline)
      .accounts({
        fund: fundPDA,
        creator: creator.publicKey,
      })
      .rpc();

    const fund = await program.account.fund.fetch(fundPDA);
    console.log("fundDeadline", fund.deadline);
    
  });

  it("Contributes to fund", async () => {
    // Generate PDA for contribution
    [contributionPDA, contributionBump] = await PublicKey.findProgramAddress(
      [fundPDA.toBuffer(), provider.wallet.publicKey.toBuffer()],
      program.programId
    );

    await program.methods
      .contribute(contribution)
      .accounts({
        fund: fundPDA,
        contributor: provider.wallet.publicKey,
        contribution: contributionPDA,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    const fund = await program.account.fund.fetch(fundPDA);
    const contributionAccount = await program.account.contribution.fetch(contributionPDA);
    console.log("fundBalanceAfter", await provider.connection.getBalance(fundPDA));
  });




  it("Refunds contribution", async () => {
    console.log("fundBalanceBefore", await provider.connection.getBalance(fundPDA));
    await new Promise(resolve => setTimeout(resolve, 15000));

    await program.methods
      .refund()
      .accounts({
        fund: fundPDA,
        contribution: contributionPDA,
        contributor: creator.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    const contributorBalanceAfter = await provider.connection.getBalance(provider.wallet.publicKey);
    const contributionAccount = await program.account.contribution.fetch(contributionPDA);
    console.log("contributorBalanceAfter", contributorBalanceAfter);
    console.log("contributionAccount", contributionAccount);

  });

  it("Withdraws funds", async () => {
    const creatorBalanceBefore = await provider.connection.getBalance(creator.publicKey);
   

    await program.methods
      .withdraw()
      .accounts({
        fund: fundPDA,
        creator: creator.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    const creatorBalanceAfter = await provider.connection.getBalance(creator.publicKey);
    const fund = await program.account.fund.fetch(fundPDA);

    console.log("creatorBalanceAfter", creatorBalanceAfter);
    console.log("fundBalanceAfter", await provider.connection.getBalance(fundPDA));
    
  });

  
});