import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Chall } from "../target/types/chall";

describe("chall", () => {
  // Configure the client to use the local cluster.
  anchor.setProvider(anchor.AnchorProvider.env());

  const program = anchor.workspace.Chall as Program<Chall>;

  it("Is initialized!", async () => {
    // Add your test here.
    const tx = await program.methods.initialize().rpcAndKeys();
    console.log("Your transaction signature", tx);
  });
});
