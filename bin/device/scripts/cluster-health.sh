#!/usr/bin/env bash
# Check cluster health
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

CLI_ARGS="${1:-}"
talosctl health --nodes ${CLI_ARGS}
