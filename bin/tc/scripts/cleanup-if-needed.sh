#!/usr/bin/env bash
# Cleanup Talos cluster if --destroy flag was set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

# Set PROJECT_ROOT
PROJECT_ROOT=$(get_windsor_project_root)

SKIP_CLEANUP="${SKIP_CLEANUP:-false}"

if [ "${SKIP_CLEANUP}" = "true" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Cluster cleanup (skipped)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Cluster '${CLUSTER_NAME}' on remote '${TEST_REMOTE_NAME}' has been left running."
  echo "  To destroy later: task tc:destroy"
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cleaning up cluster..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Use task tc:destroy to destroy the cluster (consistent with VM flow)
if task tc:destroy > /tmp/tc_cleanup.log 2>&1; then
  echo "✅ Cluster destroyed successfully"
else
  echo "⚠️  Warning: Failed to destroy cluster. Manual cleanup may be required."
  echo "   Run: task tc:destroy"
  tail -15 /tmp/tc_cleanup.log
  exit 1
fi

