#!/usr/bin/env bash
# Cleanup (destroy) VM only if --destroy was set; default is to keep the VM.
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  # Source the file to load variables
  set +u  # Temporarily allow unset variables while sourcing
  source "${ENV_FILE}"
  set -u  # Re-enable strict checking
fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
# Default to true (keep VM); only destroy when --destroy was passed (SKIP_CLEANUP=false)
SKIP_CLEANUP="${SKIP_CLEANUP:-true}"

# Debug: show what we're checking (can be removed later)
if [ "${DEBUG:-false}" = "true" ]; then
  echo "DEBUG: SKIP_CLEANUP='${SKIP_CLEANUP}'" >&2
  echo "DEBUG: VM_NAME='${VM_NAME}'" >&2
fi

# Check if cleanup should be skipped
if [ "${SKIP_CLEANUP}" = "true" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "VM Cleanup (skipped)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  VM '${VM_NAME}' is being kept (default). To destroy it later, run: task vm:destroy -- ${VM_NAME}"
  exit 0
fi

# Cleanup VM
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cleaning up VM..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

set +e  # Temporarily disable exit on error for cleanup
if task vm:destroy -- ${VM_NAME} > /tmp/cleanup.log 2>&1; then
  echo "✅ VM deleted successfully"
  CLEANUP_SUCCESS=true
else
  CLEANUP_SUCCESS=false
  echo "⚠️  Warning: Failed to delete VM. Manual cleanup may be required."
  echo "   Run: task vm:destroy -- ${VM_NAME}"
  if [ -f /tmp/cleanup.log ]; then
    echo "   Error details:"
    tail -10 /tmp/cleanup.log | sed 's/^/     /'
  fi
fi
set -e  # Re-enable exit on error

# Don't fail the entire instantiate task if cleanup fails
# The VM was created successfully, cleanup is just a convenience
if [ "${CLEANUP_SUCCESS}" != "true" ]; then
  echo ""
  echo "   Note: VM '${VM_NAME}' was created successfully but cleanup failed."
  echo "   You can destroy it manually later with: task vm:destroy -- ${VM_NAME}"
fi
