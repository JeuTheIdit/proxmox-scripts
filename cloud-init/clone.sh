#!/usr/bin/env bash
set -euo pipefail

# Print help
usage() {
    cat <<EOF
Usage: $0 --vmid <NEW_VM_ID> --name <NEW_VM_NAME> [options]

Required:
  --vmid      VMID for the new VM
  --name      Hostname / name for the new VM

Optional:
  --ip        IP address with CIDR (e.g., 192.168.1.50/24)
  --gw        Gateway IP (e.g., 192.168.1.1). Only used if --ip is set.
  --sshkey    SSH public key string to inject into the VM
  --help      Show this help message

Description:
  This script clones the Debian 13 Cloud-Init template (VMID 9000 by default)
  and optionally sets hostname, IP address, gateway, and SSH key for the new VM.
  Only the provided options are applied; other settings come from the template
  or the base Cloud-Init YAML at local:snippets/base.yml.

Examples:
  Clone with just VMID and hostname:
    $0 --vmid 9100 --name web01

  Clone with IP + gateway:
    $0 --vmid 9101 --name web02 --ip 192.168.1.51/24 --gw 192.168.1.1

  Clone with SSH key:
    $0 --vmid 9102 --name web03 --sshkey "ssh-ed25519 AAAA..."

  Clone with everything:
    $0 --vmid 9103 --name web04 --ip 192.168.1.52/24 --gw 192.168.1.1 --sshkey "ssh-ed25519 AAAA..."
EOF
    exit 0
}

# Default values
IP=""
GATEWAY=""
SSH_KEY=""

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --vmid) NEW_VM_ID="$2"; shift 2 ;;
        --name) NEW_VM_NAME="$2"; shift 2 ;;
        --ip) IP="$2"; shift 2 ;;
        --gw) GATEWAY="$2"; shift 2 ;;
        --sshkey) SSH_KEY="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Unknown option $1"; usage ;;
    esac
done

# Validate required
if [ -z "${NEW_VM_ID:-}" ] || [ -z "${NEW_VM_NAME:-}" ]; then
    usage
fi

TEMPLATE_ID=9000                # Your Debian 13 Cloud-Init template VMID
BASE_YAML="local:snippets/base.yml"

echo "==> Cloning template $TEMPLATE_ID to VM $NEW_VM_ID ($NEW_VM_NAME)"
qm clone $TEMPLATE_ID $NEW_VM_ID --name $NEW_VM_NAME --full

echo "==> Setting Cloud-Init options for $NEW_VM_ID"
CI_ARGS="--cicustom $BASE_YAML --ciuser jnbolsen"

# Optional overrides
[ -n "$NEW_VM_NAME" ] && CI_ARGS="$CI_ARGS --hostname $NEW_VM_NAME"
[ -n "$IP" ] && {
    if [ -n "$GATEWAY" ]; then
        CI_ARGS="$CI_ARGS --ipconfig0 ip=${IP},gw=${GATEWAY}"
    else
        CI_ARGS="$CI_ARGS --ipconfig0 ip=${IP}"
    fi
}
[ -n "$SSH_KEY" ] && CI_ARGS="$CI_ARGS --sshkey0 \"$SSH_KEY\""

# Apply Cloud-Init settings
eval qm set $NEW_VM_ID $CI_ARGS

echo "==> Starting VM $NEW_VM_ID"
qm start $NEW_VM_ID

echo "==> VM $NEW_VM_ID ($NEW_VM_NAME) created and started!"
