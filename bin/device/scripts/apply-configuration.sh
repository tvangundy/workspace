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
TALOSCONFIG="${TALOSCONFIG:-${PROJECT_ROOT}/contexts/${WINDSOR_CONTEXT}/.talos/talosconfig}"
TALOS_API_PORT=50000
MAX_WAIT="${APPLY_CONFIG_MAX_WAIT:-600}"
INTERVAL=15

echo "Waiting for control plane Talos API on ${CONTROL_PLANE_IP}:${TALOS_API_PORT} (ensure node is booted from Talos image)..."
ELAPSED=0
while [ "${ELAPSED}" -lt "${MAX_WAIT}" ]; do
  if nc -z -w 3 "${CONTROL_PLANE_IP}" "${TALOS_API_PORT}" 2>/dev/null; then
    echo "Control plane API is reachable (after ${ELAPSED}s)"
    break
  fi
  echo "  waiting... (${ELAPSED}s / ${MAX_WAIT}s max)"
  sleep "${INTERVAL}"
  ELAPSED=$((ELAPSED + INTERVAL))
done
if ! nc -z -w 3 "${CONTROL_PLANE_IP}" "${TALOS_API_PORT}" 2>/dev/null; then
  echo "Error: Control plane API at ${CONTROL_PLANE_IP}:${TALOS_API_PORT} did not become reachable within ${MAX_WAIT}s"
  echo "Ensure the node is powered on and booted from the Talos image."
  exit 1
fi

echo ""
echo "Applying control plane configuration to: ${CONTROL_PLANE_IP}"
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
echo "Waiting for control plane API on ${CONTROL_PLANE_IP}:${TALOS_API_PORT} (nodes will reboot)..."
ELAPSED=0
while [ "${ELAPSED}" -lt "${MAX_WAIT}" ]; do
  if nc -z -w 3 "${CONTROL_PLANE_IP}" "${TALOS_API_PORT}" 2>/dev/null; then
    echo "Control plane API is up after ${ELAPSED}s"
    break
  fi
  echo "  waiting... (${ELAPSED}s / ${MAX_WAIT}s max)"
  sleep "${INTERVAL}"
  ELAPSED=$((ELAPSED + INTERVAL))
done
if ! nc -z -w 3 "${CONTROL_PLANE_IP}" "${TALOS_API_PORT}" 2>/dev/null; then
  echo "Warning: Control plane API did not become reachable within ${MAX_WAIT}s"
  echo "You may need to run bootstrap or set-endpoints later once the node is up"
  exit 1
fi

echo ""
echo "Configuration applied successfully"
