# Build stage - using Python 3.13 as base
FROM python:3.13-bookworm AS builder

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    cmake \
    gcc \
    g++ \
    golang \
    libcurl4-openssl-dev \
    libssl-dev \
    make \
    pkg-config \
    default-libmysqlclient-dev \
    protobuf-compiler \
    git \
    && rm -rf /var/lib/apt/lists/*

# Accept build argument for version
ARG SYNCSTORAGE_VERSION=0.20.1

# Clone the repository and checkout the specified version
RUN git clone https://github.com/mozilla-services/syncstorage-rs.git . && \
    git checkout ${SYNCSTORAGE_VERSION}

# Install Python dependencies required by tokenserver
RUN pip install --no-cache-dir PyFxA cryptography

# Build the application
RUN cargo build --release

# Runtime stage with Python 3.13
FROM python:3.13-slim-bookworm

# Add labels for Docker Hub
LABEL maintainer="your-email@example.com"
LABEL org.opencontainers.image.description="Mozilla Sync Storage Server (syncstorage-rs) with Python 3.13 support"
LABEL org.opencontainers.image.source="https://github.com/mozilla-services/syncstorage-rs"
LABEL org.opencontainers.image.version="0.20.1"

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4 \
    libssl3 \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python FxA module and dependencies for tokenserver
RUN pip install --no-cache-dir PyFxA cryptography requests

# Copy the built binary
COPY --from=builder /app/target/release/syncserver /usr/local/bin/syncserver

# Create a non-root user
RUN useradd -m -u 1000 -s /bin/bash app

# Create necessary directories
RUN mkdir -p /app/config && chown -R app:app /app

USER app
WORKDIR /app

# Expose the port
EXPOSE 8000

# Add a health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/__heartbeat__ || exit 1

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/syncserver"]
