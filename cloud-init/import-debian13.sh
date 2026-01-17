#!/usr/bin/env bash
set -euo pipefail

# User config
VMID=9000
VM_NAME="debian-13-cloudinit"
STORAGE="local-zfs-vm"          # Change if needed (e.g. zfs, ceph, local)
BRIDGE="vmbr1"
CORES=2
MEMORY=2048
DISK_SIZE=8G
IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
IMAGE_FILE="debian-13-genericcloud-amd64.qcow2"

#Download cloud image
echo "==> Downloading Debian 13 cloud image"
wget -q --show-progress -O "${IMAGE_FILE}" "${IMAGE_URL}"

# Create VM
echo "==> Creating VM ${VMID} (${VM_NAME})"
qm create ${VMID} \
  --name ${VM_NAME} \
  --memory ${MEMORY} \
  --cores ${CORES} \
  --net0 virtio,bridge=${BRIDGE} \
  --ostype l26 \
  --agent enabled=1 \
  --machine q35 \
  --scsihw virtio-scsi-pci

# Import and attach disk
echo "==> Importing disk"
qm importdisk ${VMID} ${IMAGE_FILE} ${STORAGE}

echo "==> Attaching disk"
qm set ${VMID} \
  --scsi0 ${STORAGE}:vm-${VMID}-disk-0,discard=on,ssd=1 \
  --boot order=scsi0

# Add cloud-init drive
echo "==> Adding Cloud-Init drive"
qm set ${VMID} \
  --ide2 ${STORAGE}:cloudinit

# Set defaults
echo "==> Setting Cloud-Init defaults"
qm set ${VMID} \
  --ciuser ansible \
  --ipconfig0 ip=dhcp \
  --serial0 socket \
  --vga serial0

# Resize disk
echo "==> Resizing disk to ${DISK_SIZE}"
qm resize ${VMID} scsi0 ${DISK_SIZE}

# Convert to template
echo "==> Converting VM to template"
qm template ${VMID}

# Clean up
echo "==> Cleaning up image file"
rm -f ${IMAGE_FILE}

echo "==> Debian 13 Cloud-Init template ${VM_NAME} (${VMID}) ready"
