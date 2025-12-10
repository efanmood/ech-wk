# Multi-stage Dockerfile for ECH Workers - ARMv7 (Armbian)
# Optimized for ARM single-board computers running Armbian

# ==================== Stage 1: Builder ====================
FROM --platform=linux/arm/v7 golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata

WORKDIR /build

# Copy Go source
COPY ech-workers.go .

# Initialize Go module and download dependencies
RUN go mod init ech-workers && \
    go mod tidy

# Build for ARMv7 with optimizations
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=arm \
    GOARM=7

RUN go build -trimpath -ldflags="-s -w" -o ech-workers ech-workers.go

# Verify the binary
RUN chmod +x ech-workers && \
    file ech-workers && \
    ls -lh ech-workers

# ==================== Stage 2: Runtime ====================
FROM --platform=linux/arm/v7 alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    curl \
    && update-ca-certificates

# Create non-root user for running the service
RUN addgroup -g 1000 echworker && \
    adduser -D -u 1000 -G echworker echworker

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/ech-workers /app/ech-workers

# Create directories for data and logs
RUN mkdir -p /app/data /app/logs && \
    chown -R echworker:echworker /app

# Copy Cloudflare Worker script (for reference)
COPY _worker.js /app/_worker.js

# Switch to non-root user
USER echworker

# Expose default SOCKS5/HTTP proxy port
EXPOSE 30000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f -x socks5://localhost:30000 http://www.google.com/ || exit 1

# Default environment variables
ENV LISTEN_ADDR="0.0.0.0:30000" \
    ROUTING_MODE="global" \
    DNS_SERVER="dns.alidns.com/dns-query" \
    ECH_DOMAIN="cloudflare-ech.com"

# Entry point with configurable parameters
ENTRYPOINT ["/app/ech-workers"]

# Default command (can be overridden)
CMD ["-l", "0.0.0.0:30000", "-routing", "global"]
