#!/usr/bin/env bash
# Ensure VM image is available on remote
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"
VM_IMAGE="${VM_IMAGE:-ubuntu/24.04}"

# Check if image exists and is a VM
set +e
IMAGE_INFO=$(incus image info "${TEST_REMOTE_NAME}:${VM_IMAGE}" 2>/dev/null)
IMAGE_EXISTS=$?
set -e

if [ ${IMAGE_EXISTS} -eq 0 ] && echo "${IMAGE_INFO}" | grep -q "Type:.*virtual-machine"; then
  echo "✅ VM image '${VM_IMAGE}' already exists on remote '${TEST_REMOTE_NAME}'"
  exit 0
fi

# Try to copy from images remote
echo "Copying VM image '${VM_IMAGE}' from images remote..."
if incus image copy "images:${VM_IMAGE}" "${TEST_REMOTE_NAME}:" --alias "${VM_IMAGE}" 2>/dev/null; then
  echo "✅ VM image '${VM_IMAGE}' copied successfully"
else
  echo "❌ Failed to copy VM image '${VM_IMAGE}'"
  exit 1
fi
