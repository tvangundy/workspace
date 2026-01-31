#!/usr/bin/env bash
# Apply Talos configuration to cluster nodes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/device-common.sh"
load_device_env

PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
CLI_ARGS="${1:-}"

if [ -z "${CLI_ARGS}" ]; then
  echo "Error: At least one IP address is required (control-plane-ip)"
  echo "Usage: task device:apply-configuration -- <control-plane-ip> [<worker-ip1> <worker-ip2> ...]"
  echo "Example: task device:apply-configuration -- 192.168.2.31 192.168.2.111 192.168.2.125"
  exit 1
fi

eval set -- ${CLI_ARGS}
CONTROL_PLANE_IP="${1}"

if [[ ! "${CONTROL_PLANE_IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "Error: Invalid control plane IP address format: ${CONTROL_PLANE_IP}"
  exit 1
fi

echo "Checking if node ${CONTROL_PLANE_IP} is reachable..."
if ! ping -c 1 -W 2 "${CONTROL_PLANE_IP}" >/dev/null 2>&1; then
  echo "Warning: Node ${CONTROL_PLANE_IP} is not reachable via ping"
  echo "Make sure the node has booted and is on the network"
fi

CLUSTER_DIR="${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/clusters/${CLUSTER_NAME}"

echo "Applying control plane configuration to: ${CONTROL_PLANE_IP}"
echo "Note: Nodes must be running Talos (booted from the image) for this to work"
talosctl apply-config --insecure --talosconfig "${TALOSCONFIG}" --nodes "${CONTROL_PLANE_IP}" --file "${CLUSTER_DIR}/controlplane.yaml"

shift
if [ $# -gt 0 ]; then
  echo ""
  echo "Applying worker configurations..."
  for ip in "$@"; do
    if [[ ! "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo "Error: Invalid worker IP address format: ${ip}"
      exit 1
    fi
    echo "Checking if worker node ${ip} is reachable..."
    if ! ping -c 1 -W 2 "${ip}" >/dev/null 2>&1; then
      echo "Warning: Worker node ${ip} is not reachable via ping"
    fi
    echo "Applying config to worker node: ${ip}"
    talosctl apply-config --insecure --talosconfig "${TALOSCONFIG}" --nodes "${ip}" --file "${CLUSTER_DIR}/worker.yaml"
  done
else
  echo "No worker nodes specified"
fi

echo ""
echo "Configuration applied successfully"
