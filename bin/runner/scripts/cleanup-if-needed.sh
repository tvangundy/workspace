#!/usr/bin/env bash
# Cleanup VM if --keep flag was not set
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.runner-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
RUNNER_NAME="${RUNNER_NAME:-runner}"

if [ "${SKIP_CLEANUP}" = "true" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Cleanup (Skipped)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  VM '${RUNNER_NAME}' will be kept running (--keep flag was set)"
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Destroying VM '${RUNNER_NAME}'..."

# Use vm:destroy task to clean up
task vm:destroy -- "${RUNNER_NAME}" || {
  echo "⚠️  Warning: Failed to destroy VM '${RUNNER_NAME}'"
  echo "   You may need to manually delete it: task vm:delete -- ${RUNNER_NAME}"
  exit 0  # Don't fail the entire task if cleanup fails
}

echo "✅ VM '${RUNNER_NAME}' destroyed successfully"

