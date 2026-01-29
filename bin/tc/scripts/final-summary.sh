#!/usr/bin/env bash
# Print final success summary for instantiate.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Talos cluster '${CLUSTER_NAME}' instantiated successfully"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Remote: ${TEST_REMOTE_NAME}"
echo "  Kubeconfig: ${KUBECONFIG_FILE_PATH}"
echo "  Talosconfig: ${TALOSCONFIG_PATH}"
echo ""

