#!/usr/bin/env bash
# Bootstrap the etcd cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
CLI_ARGS="${1:-}"
TALOSCONFIG="${TALOSCONFIG:-${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/.talos/talosconfig}"

if [ -z "${CLI_ARGS}" ]; then
  echo "Error: Control plane IP is required"
  echo "Usage: task device:bootstrap-etc-cluster -- <control-plane-ip>"
  exit 1
fi

cd "${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/clusters/${CLUSTER_NAME}"
talosctl bootstrap --talosconfig "${TALOSCONFIG}" --endpoints "${CLI_ARGS}" --nodes "${CLI_ARGS}"
