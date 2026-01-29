#!/usr/bin/env bash
# Destroy runner VM and remove runner from GitHub repository
set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/runner-common.sh"

# Parse runner name from CLI args or use default
CLI_ARGS_STR="${1:-}"
if [ -n "${CLI_ARGS_STR}" ]; then
  RUNNER_NAME="${CLI_ARGS_STR}"
else
  # Try to load from environment
  load_runner_env
  RUNNER_NAME="${RUNNER_NAME:-runner}"
fi

# Load runner environment to get remote name and other variables
load_runner_env

# Override RUNNER_NAME if provided as argument
if [ -n "${CLI_ARGS_STR}" ]; then
  RUNNER_NAME="${CLI_ARGS_STR}"
  export RUNNER_NAME
fi

TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"
RUNNER_USER="${RUNNER_USER:-runner}"
RUNNER_HOME="${RUNNER_HOME:-/home/${RUNNER_USER}}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Destroy Runner VM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VM: ${TEST_REMOTE_NAME}:${RUNNER_NAME}"
echo ""

# Confirm deletion
echo "⚠️  This will destroy the runner VM '${RUNNER_NAME}' and remove it from GitHub"
echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
sleep 5

# Check if VM exists
VM_EXISTS=false
if incus list "${TEST_REMOTE_NAME}:${RUNNER_NAME}" --format csv -c n 2>/dev/null | grep -q "^${RUNNER_NAME}$"; then
  VM_EXISTS=true
fi

if [ "${VM_EXISTS}" = "false" ]; then
  echo "⚠️  VM '${RUNNER_NAME}' does not exist"
  echo "   Nothing to destroy"
  exit 0
fi

# Step 1: Remove runner from GitHub repository (if installed)
echo ""
echo "Step 1: Remove runner from GitHub repository..."
RUNNER_INSTALLED=false
if incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- test -f "${RUNNER_HOME}/actions-runner/svc.sh" 2>/dev/null; then
  RUNNER_INSTALLED=true
fi

if [ "${RUNNER_INSTALLED}" = "true" ]; then
  # Get token from environment (loaded via Windsor/SOPS)
  TOKEN="${GITHUB_RUNNER_TOKEN:-}"
  
  if [ -z "${TOKEN}" ]; then
    echo "  ⚠️  Warning: GITHUB_RUNNER_TOKEN not found in environment"
    echo "     Runner will be removed from GitHub manually or with a new token"
    echo "     You can remove it from: GitHub Settings → Actions → Runners"
  else
    echo "  Stopping and uninstalling runner service..."
    set +e  # Temporarily disable exit on error
    SERVICE_OUTPUT=$(incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "
      cd ${RUNNER_HOME}/actions-runner 2>/dev/null || exit 1
      if [ -f ./svc.sh ]; then
        sudo ./svc.sh stop 2>&1 || true
        sudo ./svc.sh uninstall 2>&1 || true
      fi
    " 2>&1)
    set -e  # Re-enable exit on error
    
    echo "  Removing runner from GitHub..."
    set +e  # Temporarily disable exit on error
    REMOVE_OUTPUT=$(incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "
      cd ${RUNNER_HOME}/actions-runner 2>/dev/null || exit 1
      if [ -f ./config.sh ]; then
        sudo -u ${RUNNER_USER} ./config.sh remove --token '${TOKEN}' 2>&1
      else
        echo 'Runner config not found'
        exit 1
      fi
    " 2>&1)
    REMOVE_EXIT=$?
    set -e  # Re-enable exit on error
    
    if [ ${REMOVE_EXIT} -eq 0 ]; then
      echo "  ✅ Runner removed from GitHub repository"
    else
      echo "  ⚠️  Warning: Could not remove runner from GitHub"
      echo "     Output: ${REMOVE_OUTPUT}"
      echo "     You may need to remove it manually from: GitHub Settings → Actions → Runners"
    fi
  fi
else
  echo "  ℹ️  Runner not installed on VM, skipping GitHub removal"
fi

# Step 2: Destroy the VM using vm:destroy
echo ""
echo "Step 2: Destroy VM..."
task vm:destroy -- "${RUNNER_NAME}" || {
  echo "⚠️  Warning: Failed to destroy VM '${RUNNER_NAME}'"
  echo "   You may need to manually delete it: task vm:delete -- ${RUNNER_NAME}"
  exit 1
}

echo ""
echo "✅ Runner VM '${RUNNER_NAME}' destroyed successfully"

