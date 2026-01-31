#!/usr/bin/env bash
# Format USB as FAT32 and copy BIOS update files (for Intel NUC BIOS updates)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"

if [ -z "${WINDSOR_CONTEXT:-}" ]; then
  echo "Error: WINDSOR_CONTEXT variable is not defined"
  exit 1
fi
if [ -z "${USB_DISK:-}" ]; then
  echo "Error: USB_DISK variable is not defined"
  echo "Use 'task device:list-disks' to identify your USB device"
  exit 1
fi

BASE_DISK="${USB_DISK}"
if [[ ! "${BASE_DISK}" =~ ^/dev/(disk[0-9]+|sd[a-z]|nvme[0-9]+n[0-9]+)$ ]]; then
  echo "Error: USB_DISK must be a block device (e.g., /dev/disk4 on macOS, /dev/sdb on Linux)"
  exit 1
fi

BIOS_DIR="${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/devices/bios"
if [ ! -d "${BIOS_DIR}" ]; then
  echo "Error: BIOS folder not found at ${BIOS_DIR}"
  echo "Run 'task device:prepare-bios' first"
  exit 1
fi
if [ -z "$(ls -A "${BIOS_DIR}" 2>/dev/null)" ]; then
  echo "Error: BIOS folder is empty"
  exit 1
fi

echo "Unmounting ${BASE_DISK}..."
if [[ "$(uname)" == "Darwin" ]]; then
  diskutil unmountDisk "${BASE_DISK}" 2>/dev/null || true
  echo "Formatting ${BASE_DISK} as FAT32..."
  diskutil eraseDisk FAT32 BIOSUPDATE MBRFormat "${BASE_DISK}"
  echo "Waiting for volume to mount..."
  sleep 3
  MOUNT_POINT="/Volumes/BIOSUPDATE"
  if [ ! -d "${MOUNT_POINT}" ]; then
    echo "Error: Expected volume at ${MOUNT_POINT} - check diskutil list"
    exit 1
  fi
else
  umount "${BASE_DISK}"* 2>/dev/null || true
  echo "Formatting ${BASE_DISK} as FAT32..."
  echo 'type=7' | sudo sfdisk "${BASE_DISK}"
  sudo mkfs.vfat -F 32 -n BIOSUPDATE "${BASE_DISK}1" 2>/dev/null || sudo mkfs.vfat -F 32 -n BIOSUPDATE "${BASE_DISK}p1" 2>/dev/null || true
  sudo mkdir -p /mnt/biosupdate
  PARTITION="${BASE_DISK}1"
  [ -e "${PARTITION}" ] || PARTITION="${BASE_DISK}p1"
  sudo mount "${PARTITION}" /mnt/biosupdate
  MOUNT_POINT="/mnt/biosupdate"
fi

echo "Copying BIOS files to USB..."
cp -r "${BIOS_DIR}"/* "${MOUNT_POINT}/"

if [[ "$(uname)" != "Darwin" ]]; then
  sudo umount "${MOUNT_POINT}"
  sudo rmdir /mnt/biosupdate 2>/dev/null || true
fi

echo "Done. Eject the USB with: task device:eject-disk"
