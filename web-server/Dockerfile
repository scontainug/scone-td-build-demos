FROM rust
RUN apt-get update && apt-get upgrade -y && apt-get install build-essential -y && apt install pkg-config -y && apt-get install libssl-dev -y 

WORKDIR /app

COPY . .

RUN apt-get update && apt-get install -y protobuf-compiler

RUN CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=true RUST_BACKTRACE=full cargo build --release

RUN ls /app

RUN cp target/release/web-server ./web-server
CMD ["/app/web-server"]
