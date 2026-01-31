#!/usr/bin/env bash
# Generate Talos configuration files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
INSTALL_DISK="${1:-}"

if [ -z "${WINDSOR_CONTEXT:-}" ] || [ -z "${CLUSTER_NAME:-}" ] || [ -z "${CONTROL_PLANE_IP:-}" ]; then
  echo "Error: WINDSOR_CONTEXT, CLUSTER_NAME, and CONTROL_PLANE_IP must be set"
  exit 1
fi
if [ -z "${INSTALL_DISK}" ]; then
  echo "Error: Install disk is required"
  echo "Usage: task device:generate-talosconfig -- <install-disk>"
  echo "Example: task device:generate-talosconfig -- /dev/sda"
  exit 1
fi

mkdir -p "${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/.talos"
mkdir -p "${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/clusters/${CLUSTER_NAME}"
cd "${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/clusters/${CLUSTER_NAME}"
talosctl gen config "${CLUSTER_NAME}" "https://${CONTROL_PLANE_IP}:6443" --install-disk "${INSTALL_DISK}"
mv talosconfig "${TALOSCONFIG}"
