#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Constants
# -----------------------------
SNIPPET_DIR="/var/lib/vz/snippets"

# -----------------------------
# Usage
# -----------------------------
usage() {
  cat <<EOF
Usage:
  $0 --template <template_vmid> --vmid <new_vmid> --name <vm_name>

Required:
  --template <id>     Template VMID
  --vmid <id>         New VMID
  --name <name>       Name of the new VM (also used for snippet filename)

Behavior:
  - Always performs a full clone
  - Creates Cloud-Init snippet: local:snippets/<vm_name>.yml

Example:
  $0 --template 9000 --vmid 213 --name debian13-app01
EOF
}

# -----------------------------
# Argument Parsing
# -----------------------------
TEMPLATE_ID=""
VMID=""
VM_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)
      TEMPLATE_ID="$2"
      shift 2
      ;;
    --vmid)
      VMID="$2"
      shift 2
      ;;
    --name)
      VM_NAME="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# -----------------------------
# Validation
# -----------------------------
if [[ -z "$TEMPLATE_ID" || -z "$VMID" || -z "$VM_NAME" ]]; then
  echo "ERROR: --template, --vmid, and --name are required"
  usage
  exit 1
fi

if qm status "$VMID" &>/dev/null; then
  echo "ERROR: VMID $VMID already exists"
  exit 1
fi

if ! qm status "$TEMPLATE_ID" &>/dev/null; then
  echo "ERROR: Template VMID $TEMPLATE_ID does not exist"
  exit 1
fi

if [[ ! -d "$SNIPPET_DIR" ]]; then
  echo "ERROR: Snippet directory not found: $SNIPPET_DIR"
  exit 1
fi

SNIPPET_FILE="$SNIPPET_DIR/${VM_NAME}.yml"

if [[ -e "$SNIPPET_FILE" ]]; then
  echo "ERROR: Snippet already exists: $SNIPPET_FILE"
  exit 1
fi

# -----------------------------
# Clone
# -----------------------------
echo "Cloning template $TEMPLATE_ID → VM $VMID"
echo "VM name: $VM_NAME"

qm clone "$TEMPLATE_ID" "$VMID" \
  --full \
  --name "$VM_NAME"

# -----------------------------
# Create Snippet
# -----------------------------
cat <<EOF > "$SNIPPET_FILE"
#cloud-config
hostname: ${VM_NAME}
EOF

chmod 600 "$SNIPPET_FILE"

echo "Created Cloud-Init snippet:"
echo "local:snippets/${VM_NAME}.yml"

qm set $VMID \
  -- cicustom "user=local:snippets/user.yml,vendor=local.snippets/${VM_NAME}.yml"
  -- ipconfig0 ip=dhcp

echo "Clone complete."
qm config "$VMID"
