#!/usr/bin/env bash
# Retrieve kubeconfig from the cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
CLI_ARGS="${1:-}"

cd "${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/clusters/${CLUSTER_NAME}"
talosctl kubeconfig "${KUBECONFIG_FILE}" --nodes ${CLI_ARGS}
