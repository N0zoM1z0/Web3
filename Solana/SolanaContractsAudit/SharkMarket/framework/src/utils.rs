use std::io::{BufRead, BufReader, Read};

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
