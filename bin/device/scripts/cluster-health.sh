#!/usr/bin/env bash
# Check cluster health
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
CLI_ARGS="${1:-}"
TALOSCONFIG="${TALOSCONFIG:-${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/.talos/talosconfig}"

if [ -z "${CLI_ARGS}" ]; then
  echo "Error: At least one endpoint is required (e.g. control-plane-ip)"
  echo "Usage: task device:cluster-health -- <control-plane-ip> [<worker-ip> ...]"
  exit 1
fi

talosctl health --talosconfig "${TALOSCONFIG}" --endpoints ${CLI_ARGS} --nodes ${CLI_ARGS}
