FROM rust:latest AS build

WORKDIR /usr/src/folder-reader

COPY Cargo.toml .
COPY src ./src

RUN cargo build --release

RUN cp /usr/src/folder-reader/target/release/folder-reader /usr/local/bin/folder-reader

CMD ["/usr/local/bin/folder-reader"]
