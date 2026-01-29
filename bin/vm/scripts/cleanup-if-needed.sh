#!/usr/bin/env bash
# Cleanup VM if --keep flag was not set
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  # Source the file to load variables
  set +u  # Temporarily allow unset variables while sourcing
  source "${ENV_FILE}"
  set -u  # Re-enable strict checking
fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
# Default to false if not set, and check for true (string comparison)
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"

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
  echo "  VM '${VM_NAME}' is being kept (--keep flag was set)"
  echo "  To destroy it later, run: task vm:destroy -- ${VM_NAME}"
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
