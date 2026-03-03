# Stage 1: Build the Rust application
FROM rust:1.87.0-slim-bookworm AS builder

WORKDIR /app

# Install OpenSSL development libraries and other build dependencies
# ca-certificates is needed for runtime, but including it here doesn't hurt.
RUN apt-get update && \
    apt-get install -y libssl-dev pkg-config ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy only the Cargo.toml and Cargo.lock files to leverage Docker cache
# for dependencies.
COPY Cargo.toml Cargo.lock* ./

# Copy the entire source code
COPY . .

# Build the release binary
RUN cargo build --release

# Stage 2: Create a minimal production image
FROM debian:bookworm-slim

# Install necessary runtime dependencies if any (though for a simple Axum server,
# usually `ca-certificates` is sufficient for HTTPS connections).
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/bin

# Copy the built binary from the builder stage
COPY --from=builder /app/target/release/server-rust .

# Expose the port your Axum application listens on (default is 3000)
EXPOSE 9000

# Run the application
CMD ["./server-rust"]
