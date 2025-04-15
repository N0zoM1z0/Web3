FROM rust:1.82.0-slim

RUN apt-get update

RUN rustup update nightly
RUN rustup default nightly

RUN sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"

ENV PATH="/root/.local/share/solana/install/active_release/bin:${PATH}"

RUN cargo install --git https://github.com/coral-xyz/anchor --tag v0.30.1 anchor-cli