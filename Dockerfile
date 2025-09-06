# Build stage - using Python 3.13 Alpine latest (patched BusyBox)
FROM python:3.13.7-alpine AS builder

# Update Alpine packages and install build dependencies (use busybox tar to avoid GNU tar CVE)
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    linux-pam \
    rust \
    cargo \
    cmake \
    gcc \
    g++ \
    go \
    curl-dev \
    openssl-dev \
    make \
    pkgconfig \
    mariadb-dev \
    protobuf-dev \
    git \
    musl-dev

WORKDIR /app

# Accept build argument for version
ARG SYNCSTORAGE_VERSION=0.20.1

# Clone the repository and checkout the specified version
RUN git clone https://github.com/mozilla-services/syncstorage-rs.git . && \
    git checkout ${SYNCSTORAGE_VERSION}

# Install Python dependencies required by tokenserver
RUN pip install --no-cache-dir PyFxA cryptography

# Build the application
RUN cargo build --release

# Runtime stage with Python 3.13 Alpine latest (patched BusyBox)  
FROM python:3.13.7-alpine

# Update Alpine packages and fix CVEs (exclude GNU tar)
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    linux-pam

# Add labels for Docker Hub
LABEL org.opencontainers.image.description="Mozilla Sync Storage Server (syncstorage-rs) with Python 3.13 support"
LABEL org.opencontainers.image.source="https://github.com/mozilla-services/syncstorage-rs"
LABEL org.opencontainers.image.version="0.20.1"

# Install runtime dependencies (busybox tar is already included in Alpine base)
RUN apk add --no-cache \
    ca-certificates \
    curl \
    openssl \
    mysql-client \
    mariadb-connector-c

# Install Python FxA module and dependencies for tokenserver
RUN pip install --no-cache-dir PyFxA cryptography requests

# Copy the built binary
COPY --from=builder /app/target/release/syncserver /usr/local/bin/syncserver

# Create a non-root user (Alpine uses adduser)
RUN adduser -D -u 1000 -s /bin/sh app

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
