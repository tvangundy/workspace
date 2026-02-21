#!/usr/bin/env bash
# Retrieve kubeconfig from the cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
CLI_ARGS="${1:-}"
TALOSCONFIG="${TALOSCONFIG:-${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/.talos/talosconfig}"

if [ -z "${CLI_ARGS}" ]; then
  echo "Error: Control plane IP is required"
  echo "Usage: task device:retrieve-kubeconfig -- <control-plane-ip>"
  exit 1
fi

KUBECONFIG_FILE="${KUBECONFIG_FILE:-${KUBECONFIG:-${KUBE_CONFIG_PATH:-${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/.kube/config}}}"
mkdir -p "$(dirname "${KUBECONFIG_FILE}")"

cd "${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/clusters/${CLUSTER_NAME}"
talosctl kubeconfig "${KUBECONFIG_FILE}" --talosconfig "${TALOSCONFIG}" --endpoints "${CLI_ARGS}" --nodes "${CLI_ARGS}"
