#!/usr/bin/env bash
# Eject one or more USB disks
set -euo pipefail

CLI_ARGS="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

if [ -z "${USB_DISK:-}" ]; then
  echo "Error: USB_DISK variable is not defined"
  echo "Use 'task device:list-disks' to see available disks"
  exit 1
fi

# Parse disk count from CLI_ARGS
if [ -n "${CLI_ARGS}" ]; then
  eval set -- ${CLI_ARGS}
  DISK_COUNT="${1:-1}"
  if ! [[ "${DISK_COUNT}" =~ ^[0-9]+$ ]] || [ "${DISK_COUNT}" -lt 1 ]; then
    echo "Error: disk_count must be a positive integer (minimum 1)"
    echo "Usage: task device:eject-disk [-- <disk_count>]"
    exit 1
  fi
  TOTAL_DISKS=${DISK_COUNT}
else
  TOTAL_DISKS=1
fi

BASE_DISK="${USB_DISK}"
if [[ ! "${BASE_DISK}" =~ ^/dev/disk[0-9]+$ ]]; then
  echo "Error: USB_DISK must be in format /dev/disk<N> (e.g., /dev/disk4)"
  exit 1
fi
BASE_DISK_NUM="${BASE_DISK#/dev/disk}"
DISK_PREFIX="/dev/disk"

# Unmount first
for ((i=0; i<TOTAL_DISKS; i++)); do
  CURRENT_DISK="${DISK_PREFIX}$((BASE_DISK_NUM + i))"
  diskutil unmountDisk "${CURRENT_DISK}" 2>/dev/null || true
done

echo "Ejecting ${TOTAL_DISKS} disk(s) starting from ${BASE_DISK}..."
echo ""

for ((i=0; i<TOTAL_DISKS; i++)); do
  CURRENT_DISK_NUM=$((BASE_DISK_NUM + i))
  CURRENT_DISK="${DISK_PREFIX}${CURRENT_DISK_NUM}"
  echo "Ejecting ${CURRENT_DISK} ($((i+1))/${TOTAL_DISKS})..."
  diskutil eject "${CURRENT_DISK}" || {
    echo "Warning: Failed to eject ${CURRENT_DISK}"
  }
  echo ""
done

echo "Ejection completed for ${TOTAL_DISKS} disk(s)"
