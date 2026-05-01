# ── Stage 1: Builder ──────────────────────────────────────────────────────────
FROM rust:1.77-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    musl-tools \
    musl-dev \
    gcc \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Add the musl target for a fully static binary
RUN rustup target add x86_64-unknown-linux-musl

WORKDIR /build

# Cache dependency compilation separately from source changes
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src && echo "fn main() {}" > src/main.rs
RUN cargo build --release --target x86_64-unknown-linux-musl
RUN rm -f target/x86_64-unknown-linux-musl/release/deps/backend*

# Build the real source
COPY src ./src
RUN cargo build --release --target x86_64-unknown-linux-musl

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Run as non-root
RUN useradd --system --no-create-home --shell /usr/sbin/nologin appuser

COPY --from=builder /build/target/x86_64-unknown-linux-musl/release/backend /usr/local/bin/backend

USER appuser

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/backend"]
