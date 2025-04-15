use std::io::{BufRead, BufReader, Read};
use sha2::Sha256;
use sha2::Digest;

pub fn get_line<R: Read>(reader: &mut BufReader<R>) -> anyhow::Result<String> {
    let mut line = String::new();
    reader.read_line(&mut line)?;

    let ret = line
        .split(':')
        .nth(1)
        .ok_or(anyhow::anyhow!("invalid input: {}", line))?
        .trim()
        .to_string();

    Ok(ret)
}


pub struct ProofOfWork {
    pub prefix: String,
}

impl ProofOfWork {
    const DIFFICULTY: usize = 5;

    pub fn from(prefix: String) -> Self {
        Self { prefix }
    }

    pub fn calculate(&self) -> String {
        let mut nonce = 0_u128;
        loop {
            let mut hasher = Sha256::new();
            hasher.update(format!("{}{}", self.prefix, nonce));
            let result = hasher.finalize();
            let hex_result = format!("{:x}", result);

            if hex_result.starts_with(&"0".repeat(Self::DIFFICULTY)) {
                return nonce.to_string();
            }
            nonce += 1;
        }
    }

}