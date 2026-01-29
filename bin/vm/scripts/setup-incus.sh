#!/usr/bin/env bash
# Setup Incus client on the VM and configure remote connection
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"

# Detect current user from host (same as setup-ssh.sh)
CURRENT_USER="${USER:-$(whoami)}"
CURRENT_UID="${UID:-$(id -u)}"
CURRENT_GID="${GID:-$(id -g)}"

# Only setup Incus if we're deploying to a remote (not local)
if [ "${TEST_REMOTE_NAME}" != "local" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Setup Incus Client on VM"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Wait for VM agent to be ready before executing commands
  echo "  Waiting for VM agent to be ready..."
  MAX_RETRIES=24
  RETRY_COUNT=0
  MOD_CHECK=0
  ELAPSED=0
  TIMEOUT_SEC=0
  while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
    if incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- true 2>/dev/null; then
      echo "  VM agent is ready"
      break
    fi
    # Check if we should print progress (every 3 attempts)
    # Use awk to calculate modulo instead of let with %
    MOD_CHECK=$(echo "${RETRY_COUNT}" | awk '{print $1 % 3}')
    if [ "${MOD_CHECK}" = "0" ]; then
      ELAPSED=$(echo "${RETRY_COUNT}" | awk '{print $1 * 5}')
      echo "    Waiting for VM agent... [${RETRY_COUNT}/${MAX_RETRIES} attempts, ~${ELAPSED}s elapsed]"
    fi
    sleep 5
    RETRY_COUNT=$(echo "${RETRY_COUNT}" | awk '{print $1 + 1}')
  done
  
  if [ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]; then
    TIMEOUT_SEC=$(echo "${MAX_RETRIES}" | awk '{print $1 * 5}')
    echo "⚠️  Error: VM agent not ready after ${TIMEOUT_SEC} seconds"
    echo "   The VM may still be booting. You can try running this step manually later."
    exit 1
  fi
  
  # Setup Incus on the VM
  # The runner:setup-incus task uses TARGET_INCUS_SERVER_NAME to determine the remote name
  # We need to set this to match TEST_REMOTE_NAME so the VM can connect back to the server
  export TARGET_INCUS_SERVER_NAME="${TEST_REMOTE_NAME}"
  
  # Export CURRENT_USER as RUNNER_USER so setup-incus-runner.sh can add the correct user to incus group
  export RUNNER_USER="${CURRENT_USER}"
  
  # Get script directory and call the runner script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  "${SCRIPT_DIR}/setup-incus-runner.sh" "${VM_NAME}"
  
  echo "✅ Incus client setup completed"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Setup Incus Client on VM (skipped)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Skipping Incus setup for local deployment"
fi
