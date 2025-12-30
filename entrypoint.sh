#!/bin/sh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

# Generate UUID if not provided
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: generate using xray api
        cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -n 1 | \
        awk '{print substr($1,1,4)"-"substr($1,5,4)"-"substr($1,9,4)"-"substr($1,13,4)"-"substr($1,17,14)}'
    fi
}

# Generate x25519 key pair
generate_keys() {
    print_msg "$CYAN" "Generating x25519 key pair..."
    KEY_PAIR=$(/usr/local/bin/xray x25519 2>&1)

    # Xray x25519 output format:
    # PrivateKey: <private_key>
    # Password: <public_key> (note: it's called Password but it's the public key)
    # Hash32: <hash>
    PRIVATE_KEY=$(echo "$KEY_PAIR" | grep "PrivateKey:" | cut -d':' -f2 | tr -d ' \t')
    PUBLIC_KEY=$(echo "$KEY_PAIR" | grep "Password:" | cut -d':' -f2 | tr -d ' \t')

    # Validate keys are not empty
    if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
        print_msg "$RED" "Failed to parse keys, raw output was:"
        echo "$KEY_PAIR"
        exit 1
    fi

    print_msg "$GREEN" "Key pair generated successfully"
}

# Generate short ID
generate_short_id() {
    cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 2 | head -n 1
}

# Validate UUID
validate_uuid() {
    echo "$1" | grep -E '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' >/dev/null 2>&1
}

# Validate port
validate_port() {
    echo "$1" | grep -E '^[0-9]+$' >/dev/null 2>&1 && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# Get server IP
get_server_ip() {
    # Try to get IPv4 first
    IP=$(wget -4qO- https://one.one.one.one/cdn-cgi/trace 2>/dev/null | grep "ip=" | cut -d'=' -f2)
    if [ -z "$IP" ]; then
        IP=$(wget -6qO- https://one.one.one.one/cdn-cgi/trace 2>/dev/null | grep "ip=" | cut -d'=' -f2)
    fi
    echo "$IP"
}

# Print banner
print_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           Xray VLESS-REALITY Docker Container                ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
}

# Print connection info
print_connection_info() {
    SERVER_IP=$(get_server_ip)
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           Xray VLESS-REALITY Configuration${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Server Information:${NC}"
    echo -e "  Address:     ${YELLOW}${SERVER_IP:-<your-server-ip>}${NC}"
    echo -e "  Port:        ${YELLOW}${XRAY_PORT}${NC}"
    echo ""
    echo -e "${CYAN}Client Configuration:${NC}"
    echo -e "  UUID:        ${YELLOW}${XRAY_UUID}${NC}"
    echo -e "  Flow:        ${YELLOW}xtls-rprx-vision${NC}"
    echo -e "  Security:    ${YELLOW}reality${NC}"
    echo -e "  SNI:         ${YELLOW}${XRAY_SNI}${NC}"
    echo -e "  Fingerprint: ${YELLOW}${XRAY_FINGERPRINT}${NC}"
    echo -e "  Public Key:  ${YELLOW}${XRAY_PUBLIC_KEY}${NC}"
    echo -e "  Short ID:    ${YELLOW}${XRAY_SHORT_ID}${NC}"
    echo ""
    echo -e "${CYAN}Share Link (VLESS URL):${NC}"
    echo -e "${YELLOW}${SHARE_URL}${NC}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Save this information! You will need it to configure your client.${NC}"
    echo -e "${YELLOW}Keys will be regenerated if not provided via environment variables.${NC}"
    echo ""
}

# Generate Xray config JSON
generate_config() {
    cat > /etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality",
      "port": ${XRAY_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${XRAY_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "${XRAY_SNI}:443",
          "serverNames": [
            "${XRAY_SNI}",
            ""
          ],
          "privateKey": "${XRAY_PRIVATE_KEY}",
          "shortIds": [
            "${XRAY_SHORT_ID:-}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "route": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "domain": [
          "geosite:category-ads-all"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "ip": [
          "geoip:private",
          "geoip:cn"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": [
          "geosite:cn"
        ],
        "outboundTag": "block"
      }
    ]
  }
}
EOF
}

# Generate VLESS URL for client
generate_share_url() {
    local server_ip=$(get_server_ip)
    SHARE_URL="vless://${XRAY_UUID}@${server_ip}:${XRAY_PORT}?encryption=none&security=reality&flow=xtls-rprx-vision&type=tcp&sni=${XRAY_SNI}&pbk=${XRAY_PUBLIC_KEY}&fp=${XRAY_FINGERPRINT}&sid=${XRAY_SHORT_ID:-}#Xray-Reality"
}

# Main function
main() {
    print_banner

    # Validate and set defaults
    if [ -z "$XRAY_PORT" ] || ! validate_port "$XRAY_PORT"; then
        print_msg "$RED" "Invalid port: $XRAY_PORT, using default: 443"
        XRAY_PORT=443
    fi

    # Generate or validate UUID
    if [ -z "$XRAY_UUID" ]; then
        XRAY_UUID=$(generate_uuid)
        print_msg "$YELLOW" "No UUID provided, generated: $XRAY_UUID"
    elif ! validate_uuid "$XRAY_UUID"; then
        print_msg "$RED" "Invalid UUID format: $XRAY_UUID, generating new one..."
        XRAY_UUID=$(generate_uuid)
    fi

    # Generate keys if not provided
    if [ -z "$XRAY_PRIVATE_KEY" ] || [ -z "$XRAY_PUBLIC_KEY" ]; then
        generate_keys
        print_msg "$YELLOW" "New keys generated (save these if you want to reuse):"
        print_msg "$YELLOW" "  Private Key: $PRIVATE_KEY"
        print_msg "$YELLOW" "  Public Key:  $PUBLIC_KEY"
        XRAY_PRIVATE_KEY=$PRIVATE_KEY
        XRAY_PUBLIC_KEY=$PUBLIC_KEY
    else
        print_msg "$GREEN" "Using provided keys from environment variables"
    fi

    # Generate short ID if not provided
    if [ -z "$XRAY_SHORT_ID" ]; then
        XRAY_SHORT_ID=$(generate_short_id)
        print_msg "$YELLOW" "Generated short ID: $XRAY_SHORT_ID"
    fi

    # Validate SNI
    if [ -z "$XRAY_SNI" ]; then
        print_msg "$YELLOW" "No SNI provided, using default: www.microsoft.com"
        XRAY_SNI="www.microsoft.com"
    fi

    # Set timezone
    if [ -n "$TZ" ]; then
        export TZ
    fi

    # Generate config
    print_msg "$CYAN" "Generating Xray configuration..."
    generate_config

    # Validate config
    if ! /usr/local/bin/xray -test -config /etc/xray/config.json; then
        print_msg "$RED" "Configuration validation failed!"
        exit 1
    fi
    print_msg "$GREEN" "Configuration validated successfully"

    # Generate and print connection info
    generate_share_url
    print_connection_info

    # Save keys to file for persistence (optional)
    cat > /etc/xray/keys.txt << EOF
# Xray VLESS-REALITY Keys
# Generated: $(date)
# Save these values and set as environment variables to reuse the same keys

XRAY_UUID=$XRAY_UUID
XRAY_PRIVATE_KEY=$XRAY_PRIVATE_KEY
XRAY_PUBLIC_KEY=$XRAY_PUBLIC_KEY
XRAY_SHORT_ID=$XRAY_SHORT_ID
XRAY_SNI=$XRAY_SNI
XRAY_PORT=$XRAY_PORT
EOF

    # Handle command
    case "${1:-run}" in
        run)
            print_msg "$GREEN" "Starting Xray..."
            print_msg "$BLUE" "Listening on port: $XRAY_PORT"
            echo ""
            exec /usr/local/bin/xray run -config /etc/xray/config.json
            ;;
        test)
            print_msg "$CYAN" "Testing configuration..."
            /usr/local/bin/xray -test -config /etc/xray/config.json
            cat /etc/xray/config.json
            ;;
        keys)
            cat /etc/xray/keys.txt
            ;;
        version)
            /usr/local/bin/xray version
            ;;
        *)
            print_msg "$RED" "Unknown command: $1"
            print_msg "$YELLOW" "Available commands: run, test, keys, version"
            exit 1
            ;;
    esac
}

main "$@"
