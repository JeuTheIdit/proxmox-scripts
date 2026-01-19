#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Configuration / Defaults
# -----------------------------
STORAGE_DEFAULT=""   # optional: leave empty to inherit template storage
FULL_CLONE=1         # 1 = full clone, 0 = linked clone

# -----------------------------
# Usage
# -----------------------------
usage() {
  cat <<EOF
Usage:
  $0 --template <template_vmid> --vmid <new_vmid> [options]

Required:
  --template <id>     Template VMID
  --vmid <id>         New VMID

Optional:
  --name <name>       Name of the new VM
  --storage <name>    Target storage (defaults to template storage)
  --linked            Create a linked clone (fast, space-saving)
  --help              Show this help

Examples:
  $0 --template 9000 --vmid 213 --name debian13-app01
  $0 --template 9000 --vmid 214 --storage local-zfs-vm
  $0 --template 9000 --vmid 215 --linked
EOF
}

# -----------------------------
# Argument Parsing
# -----------------------------
TEMPLATE_ID=""
VMID=""
VM_NAME=""
STORAGE="$STORAGE_DEFAULT"

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
    --storage)
      STORAGE="$2"
      shift 2
      ;;
    --linked)
      FULL_CLONE=0
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

# -----------------------------
# Validation
# -----------------------------
if [[ -z "$TEMPLATE_ID" || -z "$VMID" ]]; then
  echo "ERROR: --template and --vmid are required"
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

# -----------------------------
# Clone
# -----------------------------
echo "Cloning template $TEMPLATE_ID → VM $VMID"

CLONE_ARGS=()
CLONE_ARGS+=( "$TEMPLATE_ID" "$VMID" )

[[ -n "$VM_NAME" ]] && CLONE_ARGS+=( "--name" "$VM_NAME" )
[[ -n "$STORAGE" ]] && CLONE_ARGS+=( "--storage" "$STORAGE" )
[[ "$FULL_CLONE" -eq 1 ]] && CLONE_ARGS+=( "--full" )

qm clone "${CLONE_ARGS[@]}"

echo "Clone complete:"
qm config "$VMID"
