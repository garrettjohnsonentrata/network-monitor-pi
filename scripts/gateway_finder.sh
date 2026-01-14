#!/bin/sh
# =============================================================================
# Gateway Finder - Auto-Discovery Script for Prometheus file_sd_configs
# Runs every minute via cron to detect ISP gateway changes
# =============================================================================

set -e

# Configuration
TARGETS_FILE="/targets/targets.json"
TEMP_FILE="/tmp/targets.json.tmp"

# Static targets (always included)
STATIC_TARGETS='
  {
    "targets": ["1.1.1.1"],
    "labels": {
      "target_name": "cloudflare",
      "target_type": "dns",
      "provider": "cloudflare"
    }
  },
  {
    "targets": ["8.8.8.8"],
    "labels": {
      "target_name": "google_dns",
      "target_type": "dns",
      "provider": "google"
    }
  },
  {
    "targets": ["dynamodb.us-east-1.amazonaws.com"],
    "labels": {
      "target_name": "aws_dynamodb",
      "target_type": "cloud",
      "provider": "aws",
      "region": "us-east-1"
    }
  }
'

# Function to get the default gateway IP
get_gateway_ip() {
    # Try ip route first (most reliable on Linux)
    gateway=$(ip route 2>/dev/null | grep -E '^default' | head -1 | awk '{print $3}')
    
    # Fallback to route command if ip route fails
    if [ -z "$gateway" ]; then
        gateway=$(route -n 2>/dev/null | grep '^0.0.0.0' | head -1 | awk '{print $2}')
    fi
    
    # Validate that we got a valid IP
    if echo "$gateway" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "$gateway"
    else
        echo ""
    fi
}

# Function to generate the targets JSON
generate_targets_json() {
    local gateway_ip="$1"
    
    if [ -n "$gateway_ip" ]; then
        # Include gateway in targets
        cat << EOF
[
  {
    "targets": ["${gateway_ip}"],
    "labels": {
      "target_name": "isp_gateway",
      "target_type": "gateway",
      "provider": "isp"
    }
  },
${STATIC_TARGETS}
]
EOF
    else
        # No gateway found, only include static targets
        echo "[$STATIC_TARGETS]"
    fi
}

# Main execution
main() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway finder starting..."
    
    # Get the current gateway IP
    GATEWAY_IP=$(get_gateway_ip)
    
    if [ -n "$GATEWAY_IP" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Detected gateway: ${GATEWAY_IP}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Could not detect gateway IP"
    fi
    
    # Generate the targets JSON
    generate_targets_json "$GATEWAY_IP" > "$TEMP_FILE"
    
    # Validate JSON syntax
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$TEMP_FILE" 2>/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Generated invalid JSON"
            rm -f "$TEMP_FILE"
            exit 1
        fi
    fi
    
    # Atomic move to prevent partial reads
    mv "$TEMP_FILE" "$TARGETS_FILE"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Targets file updated: ${TARGETS_FILE}"
    
    # Log the targets for debugging
    if command -v jq >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Current targets:"
        jq -r '.[].targets[0]' "$TARGETS_FILE" 2>/dev/null | while read -r target; do
            echo "  - $target"
        done
    fi
}

main "$@"
