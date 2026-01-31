#!/usr/bin/env bash
# Get disk information from a Talos node
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

CLI_ARGS="${1:-}"
if [ -z "${CLI_ARGS}" ]; then
  echo "Error: Control plane IP address is required"
  echo "Usage: task device:get-disks -- <control-plane-ip>"
  exit 1
fi

talosctl get disks --insecure --nodes ${CLI_ARGS}
