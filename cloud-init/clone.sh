#!/usr/bin/env bash
set -euo pipefail

# Constants
SNIPPET_DIR="/var/lib/vz/snippets"

# Usage
usage() {
  cat <<EOF
Usage:
  $0 --template <template_vmid> --vmid <new_vmid> --name <vm_name> [OPTIONS]

Required:
  --template <id>     Template VMID (must be a template)
  --vmid <id>         New VMID (must not exist)
  --name <name>       Name of the new VM (used for snippet filename)

Optional:
  --disk <size>       Disk size (e.g., 8G, must be greater than 8G)
  --debug             Enable debug output

Behavior:
  - Always performs a full clone.
  - Creates Cloud-Init vendor config for setting hostname in local:snippets/<vm_name>.yml.
  - Sets Cloud-Init user config from local:snippets/user.yml.
  - Sets vendor config from local:snippets/<vm_name>.yml.
  - Sets NIC to DHCP.

Examples:
  $0 --template 9000 --vmid 213 --name debian13-app01
  $0 --template 9000 --vmid 213 --name debian13-app01 --disk 16G
EOF
}

# Argument parsing
TEMPLATE_ID=""
VMID=""
VM_NAME=""
DISK_SIZE=""
RESIZE=false
DEBUG=false

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
    --resize)
      RESIZE=true
      DISK_SIZE="$2"
      shift 2
      ;;
    --debug)
      DEBUG=true
      shift
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

# Validation
if [[ -z "$TEMPLATE_ID" || -z "$VMID" || -z "$VM_NAME" ]]; then
  echo "ERROR: --template, --vmid, and --name are required"
  usage
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root"
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

if ! qm config "$TEMPLATE_ID" | grep -q 'template: 1'; then
  echo "ERROR: VMID $TEMPLATE_ID is not a template"
  exit 1
fi

if [[ ! -d "$SNIPPET_DIR" ]]; then
  echo "ERROR: Snippet directory not found: $SNIPPET_DIR"
  exit 1
fi

if [[ ! -w "$SNIPPET_DIR" ]]; then
  echo "ERROR: Snippet directory is not writable: $SNIPPET_DIR"
  exit 1
fi

if [[ ! -f "$SNIPPET_DIR/user.yml" ]]; then
  echo "ERROR: user.yml snippet not found in $SNIPPET_DIR"
  exit 1
fi

# Debug mode
if [[ "$DEBUG" == true ]]; then
  set -x
fi

# Clone
echo "Cloning template $TEMPLATE_ID → VM $VMID"
echo "VM name: $VM_NAME"
qm clone "$TEMPLATE_ID" "$VMID" \
  --full \
  --name "$VM_NAME"

# Create snippet
SNIPPET_FILE="$SNIPPET_DIR/${VM_NAME}.yml"

cat <<EOF > "$SNIPPET_FILE"
#cloud-config
hostname: ${VM_NAME}
EOF

chmod 600 "$SNIPPET_FILE"

echo "Created Cloud-Init vendor snippet local:snippets/${VM_NAME}.yml"

# Set VM config
qm set "$VMID" \
  --cicustom "user=local:snippets/user.yml,vendor=local:snippets/${VM_NAME}.yml" \
  --ipconfig0 ip=dhcp

# Resize VM disk if flag is set
if [[ "$RESIZE" == true ]]; then
  echo "Resizing disk to $DISK_SIZE"
  sudo qm resize "$VMID" scsi0 "$DISK_SIZE"
fi

echo "Clone complete"
qm config "$VMID"
