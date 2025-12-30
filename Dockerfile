# Multi-stage build for Xray VLESS-REALITY Docker image
# Stage 1: Download Xray core and geo data
FROM alpine:3.20 AS builder

# Install dependencies
RUN apk add --no-cache wget ca-certificates

# Set Xray version (use latest, can be overridden with build arg)
ARG XRAY_VERSION=latest
ARG XRAY_ARCH=64

# Determine architecture
RUN case $(uname -m) in \
        x86_64)  echo "64" > /tmp/arch ;; \
        aarch64) echo "arm64-v8a" > /tmp/arch ;; \
        *)       echo "Unsupported architecture" && exit 1 ;; \
    esac

# Download Xray core from GitHub releases
RUN if [ "$XRAY_VERSION" = "latest" ]; then \
        XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$(cat /tmp/arch).zip"; \
    else \
        XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-$(cat /tmp/arch).zip"; \
    fi && \
    echo "Downloading Xray from: $XRAY_URL" && \
    wget -q --show-progress -O /tmp/xray.zip "$XRAY_URL" && \
    unzip -o /tmp/xray.zip -d /tmp/xray && \
    rm /tmp/xray.zip

# Download geoip.dat and geosite.dat
RUN wget -q --show-progress -O /tmp/geoip.dat \
        "https://github.com/v2ray/v2ray-core/blob/master/release/config/geoip.dat" && \
    wget -q --show-progress -O /tmp/geosite.dat \
        "https://github.com/v2ray/v2ray-core/blob/master/release/config/geosite.dat"


# Stage 2: Final minimal image
FROM alpine:3.20

# Install runtime dependencies
# - jq: for JSON processing in entrypoint script
# - bind-tools: for dig (optional, used in healthcheck)
RUN apk add --no-cache \
    jq \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# Set non-root user for security
RUN addgroup -g 1000 xray && \
    adduser -D -u 1000 -G xray xray

# Create directories
RUN mkdir -p /etc/xray \
    /var/log/xray \
    /usr/local/bin

# Copy files from builder
COPY --from=builder /tmp/xray/xray /usr/local/bin/xray
COPY --from=builder /tmp/xray/geoip.dat /etc/xray/geoip.dat
COPY --from=builder /tmp/xray/geosite.dat /etc/xray/geosite.dat

# Copy entrypoint script and set permissions immediately
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Set permissions
RUN chmod +x /usr/local/bin/xray \
    /usr/local/bin/entrypoint.sh && \
    chown -R xray:xray /etc/xray /var/log/xray /usr/local/bin/entrypoint.sh

# Set environment variables with defaults
ENV XRAY_PORT=443 \
    XRAY_UUID= \
    XRAY_SNI=www.microsoft.com \
    XRAY_PUBLIC_KEY= \
    XRAY_PRIVATE_KEY= \
    XRAY_SHORT_ID= \
    XRAY_FINGERPRINT=chrome \
    TZ=Asia/Shanghai

# Expose port
EXPOSE 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -x xray || exit 1

# Switch to non-root user
USER xray

# Set working directory
WORKDIR /etc/xray

# Define entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["run"]
