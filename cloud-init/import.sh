#!/usr/bin/env bash
set -euo pipefail

# User config
VMID=9000
VM_NAME="debian-13-cloudinit"
DISK_STORAGE="local-zfs-vm" # VM + EFI disk (ZFS)
CI_STORAGE="local" # Cloud-init ISO storage
BRIDGE0="vmbr1" # Primary network
BRIDGE1="vmbr2" # Secondary network (optional)
CORES=2
MEMORY=2048
DISK_SIZE="8G"
IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
IMAGE_FILE="debian-13-genericcloud-amd64.qcow2"

#Download cloud image
echo "Downloading Debian 13 cloud image"
wget -q --show-progress -O "${IMAGE_FILE}" "${IMAGE_URL}"

# Create VM
echo "Creating VM ${VMID} (${VM_NAME})"
qm create ${VMID} \
  --name ${VM_NAME} \
  --memory ${MEMORY} \
  --cores ${CORES} \
  --ostype l26 \
  --bios ovmf \
  --agent enabled=1 \
  --machine q35 \
  --scsihw virtio-scsi-single \

# Add  EFI disk
echo "Adding EFI disk"
qm set ${VMID} \
  --efidisk0 ${DISK_STORAGE}:0,efitype=4m,pre-enrolled-keys=1

# Add network interfaces
echo "Adding network interfaces"
qm set ${VMID} \
  --net0 virtio,bridge=${BRIDGE0}

# Import the cloud image into the ZVOL as raw
qm importdisk ${VMID} ${IMAGE_FILE} ${DISK_STORAGE} --format raw

# Attach the disk
qm set ${VMID} \
  --scsi0 ${DISK_STORAGE}:vm-${VMID}-disk-1,discard=on,ssd=1 \
  --boot order=scsi0

# Resizing main disk
echo "Resizing main disk to ${DISK_SIZE}"
qm resize ${VMID} scsi0 ${DISK_SIZE}

# Add cloud-init drive
echo "Adding Cloud-Init drive"
qm set ${VMID} \
  --ide2 ${CI_STORAGE}:cloudinit

# Set defaults
echo "Setting Cloud-Init defaults"
qm set ${VMID} \
  --ciuser jnbolsen \
  --ipconfig0 ip=dhcp \
  --serial0 socket \
  --vga serial0 \
  --cicustom "vendor=local:snippets/base.yml"

# Convert to template
echo "Converting VM to template"
qm template ${VMID}

# Clean up
echo "Cleaning up image file"
rm -f ${IMAGE_FILE}

echo "==> Debian 13 Cloud-Init template is ready!"
echo "    VMID: ${VMID}"
echo "    Name: ${VM_NAME}"
echo "    Main disk storage: ${DISK_STORAGE}"
echo "    Cloud-Init ISO storage: ${CI_STORAGE}"
