use meander::reader::read;

use std::io::stdin;

fn main() {
    let mut buf = String::new();
    loop {
        stdin().read_line(&mut buf).unwrap();

        if let Some(read) = read(&buf) {
            buf.clear();
            println!("Read data: {:?}", read);
        }
    }
}
