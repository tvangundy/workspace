#!/usr/bin/env bash
# Expand the root partition to use the full disk (cloud images often have a small root partition).
# Run after VM is up and we can exec; idempotent (safe if already grown).
set -euo pipefail

# Windsor context first, then session file
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
if command -v windsor >/dev/null 2>&1; then eval "$(windsor env 2>/dev/null)" || true; fi
ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then source "${ENV_FILE}"; fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Expand root partition to use full disk"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Run growpart + resize inside the VM. Detect root device so we work with vda, sda, nvme0n1, etc.
incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c '
  set -euo pipefail
  ROOT_SOURCE=$(findmnt -n -o SOURCE /)
  # ROOT_SOURCE is e.g. /dev/vda2 or /dev/nvme0n1p2
  ROOT_DEVICE="${ROOT_SOURCE#/dev/}"
  # Strip partition suffix: nvme0n1p2 -> nvme0n1, vda2 -> vda
  DISK_DEVICE=$(echo "${ROOT_DEVICE}" | sed -E "s/p?[0-9]+\$//")
  PART_NUM=$(echo "${ROOT_DEVICE}" | sed -E "s/.*p?([0-9]+)\$/\1/")
  DISK_PATH="/dev/${DISK_DEVICE}"

  if ! command -v growpart >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -qq -y cloud-guest-utils >/dev/null 2>&1 || true
  fi
  if growpart "${DISK_PATH}" "${PART_NUM}" 2>/dev/null; then
    echo "  Partition expanded."
  else
    echo "  Partition already at max size or growpart not available (continuing)."
  fi

  FSTYPE=$(findmnt -n -o FSTYPE /)
  if [[ "${FSTYPE}" == "ext4" ]] || [[ "${FSTYPE}" == "ext3" ]]; then
    resize2fs "${ROOT_SOURCE}"
  elif [[ "${FSTYPE}" == "xfs" ]]; then
    xfs_growfs /
  else
    echo "  Unknown fstype ${FSTYPE}; skipping filesystem resize."
    exit 0
  fi
  echo "  Root filesystem resized to use full disk."
'

echo "✅ Root partition expanded"
echo ""
