#!/usr/bin/env bash
# Wait for all three cluster VMs to be Running.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

log_step "Waiting for all VMs to boot and become ready"

READY=0
for VM in "${CONTROL_PLANE_VM}" "${WORKER_0_VM}" "${WORKER_1_VM}"; do
  incus list "${TEST_REMOTE_NAME}:${VM}" --format json 2>/dev/null | grep -q '"status":"Running"' && READY=$((READY + 1)) || true
done

if [ ${READY} -eq 3 ]; then
  echo "✅ All VMs are running"
  exit 0
fi

echo "Waiting for VMs to boot..."
MAX_WAIT=300
ELAPSED=0
while [ ${ELAPSED} -lt ${MAX_WAIT} ]; do
  READY=0
  for VM in "${CONTROL_PLANE_VM}" "${WORKER_0_VM}" "${WORKER_1_VM}"; do
    incus list "${TEST_REMOTE_NAME}:${VM}" --format json 2>/dev/null | grep -q '"status":"Running"' && READY=$((READY + 1)) || true
  done
  [ ${READY} -eq 3 ] && echo "✅ All VMs are running" && exit 0
  sleep 10
  ELAPSED=$((ELAPSED + 10))
  echo "  Waiting... (${ELAPSED}s/${MAX_WAIT}s) ${READY}/3 VMs running"
done

echo "❌ Not all VMs running after ${MAX_WAIT}s"
exit 1

