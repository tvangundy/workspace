#!/usr/bin/env bash
# Fail if any cluster VM already exists (instantiate requires a clean slate).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

# Always generate VM names from current CLUSTER_NAME to avoid conflicts with old clusters
# This ensures we check for the correct cluster's VMs, not stale VM names from previous runs
CONTROL_PLANE_VM="${CLUSTER_NAME}-cp"
WORKER_0_VM="${CLUSTER_NAME}-worker-0"
WORKER_1_VM="${CLUSTER_NAME}-worker-1"

# Export for subsequent scripts
export CONTROL_PLANE_VM WORKER_0_VM WORKER_1_VM

log_step "Checking for existing cluster VMs"

# Show which VM names we're checking
echo "Checking for VMs: ${CONTROL_PLANE_VM}, ${WORKER_0_VM}, ${WORKER_1_VM}"

# Get IP addresses that will be used for this cluster
# These come from environment variables or defaults
CONTROL_PLANE_IP="${CONTROL_PLANE_IP:-192.168.2.57}"
WORKER_0_IP="${WORKER_0_IP:-192.168.2.123}"
WORKER_1_IP="${WORKER_1_IP:-192.168.2.20}"

# Check for IP address conflicts with existing cluster VMs
# Get all cluster VMs (ending in -cp or -worker-*)
ALL_CLUSTER_VMS=$(incus list "${TEST_REMOTE_NAME}:" --format csv -c n 2>/dev/null | grep -E '\-cp$|\-worker-[0-9]' | grep -v "^${CONTROL_PLANE_VM}$" | grep -v "^${WORKER_0_VM}$" | grep -v "^${WORKER_1_VM}$" || echo "")

IP_CONFLICTS=""
if [ -n "${ALL_CLUSTER_VMS}" ]; then
  # Check each existing cluster VM's IP
  for EXISTING_VM in ${ALL_CLUSTER_VMS}; do
    # Get IP from Terraform workspace if it exists
    EXISTING_IP=""
    # Try to extract cluster name from VM name (remove -cp or -worker-X suffix)
    EXISTING_CLUSTER=$(echo "${EXISTING_VM}" | sed 's/-cp$//' | sed 's/-worker-[0-9]$//')
    
    if [ -d "${TERRAFORM_DIR}" ] && command -v terraform >/dev/null 2>&1; then
      cd "${TERRAFORM_DIR}"
      # Try to select the workspace and get IP
      if terraform workspace select "${EXISTING_CLUSTER}" >/dev/null 2>&1; then
        if echo "${EXISTING_VM}" | grep -q '\-cp$'; then
          EXISTING_IP=$(terraform output -raw control_plane_ip 2>/dev/null || echo "")
        elif echo "${EXISTING_VM}" | grep -q '\-worker-0$'; then
          EXISTING_IP=$(terraform output -json worker_ips 2>/dev/null | jq -r '.["worker_0"] // ""' 2>/dev/null || echo "")
        elif echo "${EXISTING_VM}" | grep -q '\-worker-1$'; then
          EXISTING_IP=$(terraform output -json worker_ips 2>/dev/null | jq -r '.["worker_1"] // ""' 2>/dev/null || echo "")
        fi
      fi
      cd - >/dev/null
    fi
    
    # Check for IP conflicts
    if [ -n "${EXISTING_IP}" ]; then
      if [ "${EXISTING_IP}" = "${CONTROL_PLANE_IP}" ] || [ "${EXISTING_IP}" = "${WORKER_0_IP}" ] || [ "${EXISTING_IP}" = "${WORKER_1_IP}" ]; then
        IP_CONFLICTS="${IP_CONFLICTS} ${EXISTING_VM} (${EXISTING_IP})"
      fi
    fi
  done
fi

if [ -n "${IP_CONFLICTS}" ]; then
  echo "❌ IP address conflict detected!"
  echo "   The following existing cluster VMs are using IPs that conflict with this cluster:"
  for CONFLICT in ${IP_CONFLICTS}; do
    echo "     - ${CONFLICT}"
  done
  echo ""
  echo "   Intended IPs for this cluster:"
  echo "     Control Plane: ${CONTROL_PLANE_IP}"
  echo "     Worker 0:     ${WORKER_0_IP}"
  echo "     Worker 1:     ${WORKER_1_IP}"
  echo ""
  echo "   To resolve this conflict:"
  echo "     1. Destroy the conflicting cluster(s): task tc:destroy -- <cluster-name>"
  echo "     2. Or specify different IP addresses in windsor.yaml before creating this cluster"
  echo "     3. Or set environment variables: CONTROL_PLANE_IP, WORKER_0_IP, WORKER_1_IP"
  exit 1
fi

EXISTING=0
EXISTING_VMS=""
for VM in "${CONTROL_PLANE_VM}" "${WORKER_0_VM}" "${WORKER_1_VM}"; do
  if incus list "${TEST_REMOTE_NAME}:${VM}" --format csv -c n 2>/dev/null | grep -q "^${VM}$"; then
    EXISTING=$((EXISTING + 1))
    EXISTING_VMS="${EXISTING_VMS} ${VM}"
  fi
done

if [ ${EXISTING} -gt 0 ]; then
  echo "❌ Cluster VMs already exist for '${CLUSTER_NAME}'"
  echo "   Found ${EXISTING} VM(s):${EXISTING_VMS}"
  echo ""
  echo "   Instantiate requires a clean slate. Destroy the cluster first:"
  echo "     task tc:destroy [-- <cluster-name>]"
  echo ""
  echo "   Then run instantiate again:"
  echo "     task tc:instantiate -- <remote-name> <remote-ip> [<cluster-name>] [--destroy]"
  exit 1
fi

echo "✅ No existing cluster VMs found"

