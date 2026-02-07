#!/usr/bin/env bash
# Ensure VM image is available on remote
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"

# VM_IMAGE: from env, or from windsor.yaml (initialize-context writes to .workspace/.vm-instantiate.env)
if [ -z "${VM_IMAGE:-}" ]; then
  ACTIVE_CONTEXT=$(windsor context get 2>/dev/null || echo "${WINDSOR_CONTEXT:-}")
  if [ -n "${ACTIVE_CONTEXT}" ]; then
    WINDSOR_YAML="${PROJECT_ROOT}/contexts/${ACTIVE_CONTEXT}/windsor.yaml"
    if [ -f "${WINDSOR_YAML}" ]; then
      VM_IMAGE=$(grep -E '^\s+VM_IMAGE:' "${WINDSOR_YAML}" 2>/dev/null | head -1 | sed -E 's/.*VM_IMAGE:[[:space:]]*["]?([^"]*)["]?.*/\1/' | tr -d ' ')
    fi
  fi
fi
VM_IMAGE="${VM_IMAGE:-ubuntu/25.04}"

# Check if image exists and is a VM
set +e
IMAGE_INFO=$(incus image info "${TEST_REMOTE_NAME}:${VM_IMAGE}" 2>/dev/null)
IMAGE_EXISTS=$?
set -e

if [ ${IMAGE_EXISTS} -eq 0 ]; then
  # Verify it's a VM image (Type format varies by Incus version)
  if echo "${IMAGE_INFO}" | grep -qiE "Type:.*(virtual-machine|VM)"; then
    echo "✅ VM image '${VM_IMAGE}' already exists on remote '${TEST_REMOTE_NAME}'"
    exit 0
  fi
  # Image exists but is a container - delete it so we can copy the VM image
  echo "  Removing container image '${VM_IMAGE}' (need VM image)..."
  incus image delete "${TEST_REMOTE_NAME}:${VM_IMAGE}" 2>/dev/null || true
fi

# Try to copy VM image from images remote (--vm selects VM variant, not container)
echo "Copying VM image '${VM_IMAGE}' from images remote..."
COPY_ERR=$(mktemp)
if ! incus image copy "images:${VM_IMAGE}" "${TEST_REMOTE_NAME}:" --alias "${VM_IMAGE}" --vm 2>"${COPY_ERR}"; then
  COPY_ERR_TEXT=$(cat "${COPY_ERR}")
  rm -f "${COPY_ERR}"
  # Alias already exists = VM image on remote, treat as success (only if it's a VM)
  if echo "${COPY_ERR_TEXT}" | grep -qi "alias already exists"; then
    set +e
    IMAGE_INFO=$(incus image info "${TEST_REMOTE_NAME}:${VM_IMAGE}" 2>/dev/null)
    set -e
    if echo "${IMAGE_INFO}" | grep -qiE "Type:.*(virtual-machine|VM)"; then
      echo "✅ VM image '${VM_IMAGE}' already exists on remote '${TEST_REMOTE_NAME}'"
      exit 0
    fi
  fi
  if [ -n "${COPY_ERR_TEXT}" ]; then
    echo "   Error: ${COPY_ERR_TEXT}"
  fi
else
  rm -f "${COPY_ERR}"
  echo "✅ VM image '${VM_IMAGE}' copied successfully"
  exit 0
fi

# Copy failed - image may already exist (e.g. from previous run)
set +e
IMAGE_INFO=$(incus image info "${TEST_REMOTE_NAME}:${VM_IMAGE}" 2>/dev/null)
IMAGE_EXISTS=$?
set -e
if [ ${IMAGE_EXISTS} -eq 0 ]; then
  if echo "${IMAGE_INFO}" | grep -qiE "Type:.*(virtual-machine|VM)"; then
    echo "✅ VM image '${VM_IMAGE}' already exists on remote '${TEST_REMOTE_NAME}'"
    exit 0
  fi
fi

echo "❌ Failed to copy VM image '${VM_IMAGE}'"
exit 1
