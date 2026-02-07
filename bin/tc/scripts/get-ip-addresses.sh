#!/usr/bin/env bash
# Get IPs from Terraform outputs, update windsor.yaml, append to .workspace/.tc-instantiate.env.
# Note: With MAC addresses set in windsor.yaml, IPs should match if DHCP reservations are configured.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

# Set additional variables needed by this script
PROJECT_ROOT=$(get_windsor_project_root)
ENV_FILE="${PROJECT_ROOT}/.workspace/.tc-instantiate.env"

# Context directory: WINDSOR_CONTEXT takes precedence over CLUSTER_NAME
TEST_CONTEXT_DIR=$(get_tc_context_dir "${PROJECT_ROOT}" "${CLUSTER_NAME}")

TEST_WINDSOR_YAML="${TEST_CONTEXT_DIR}/windsor.yaml"

log_step "Retrieving IP addresses from Terraform outputs"

cd "${TERRAFORM_DIR}"
# Ensure we're using the correct workspace for this cluster
CURRENT_WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
if [ "${CURRENT_WORKSPACE}" != "${CLUSTER_NAME}" ]; then
  if terraform workspace list 2>/dev/null | grep -q "^[[:space:]]*${CLUSTER_NAME}$"; then
    terraform workspace select "${CLUSTER_NAME}"
  else
    echo "⚠️  Warning: Workspace '${CLUSTER_NAME}' does not exist yet"
  fi
fi

set +e
CONTROL_PLANE_IP=$(terraform output -raw control_plane_ip 2>/dev/null || echo "")
WORKER_0_IP=$(terraform output -json worker_ips 2>/dev/null | jq -r '.["worker_0"] // ""' 2>/dev/null || echo "")
WORKER_1_IP=$(terraform output -json worker_ips 2>/dev/null | jq -r '.["worker_1"] // ""' 2>/dev/null || echo "")
set -e
cd - >/dev/null

if [ -z "${CONTROL_PLANE_IP}" ] || [ -z "${WORKER_0_IP}" ] || [ -z "${WORKER_1_IP}" ]; then
  echo "⚠️  Could not get all IPs from terraform output; using existing env"
  exit 0
fi

echo "✅ IPs: control-plane ${CONTROL_PLANE_IP}, worker0 ${WORKER_0_IP}, worker1 ${WORKER_1_IP}"

if [[ "$(uname)" = "Darwin" ]]; then
  sed -i '' "s/CONTROL_PLANE_IP: \".*\"/CONTROL_PLANE_IP: \"${CONTROL_PLANE_IP}\"/" "${TEST_WINDSOR_YAML}"
  sed -i '' "s/WORKER_0_IP: \".*\"/WORKER_0_IP: \"${WORKER_0_IP}\"/" "${TEST_WINDSOR_YAML}"
  sed -i '' "s/WORKER_1_IP: \".*\"/WORKER_1_IP: \"${WORKER_1_IP}\"/" "${TEST_WINDSOR_YAML}"
else
  sed -i "s/CONTROL_PLANE_IP: \".*\"/CONTROL_PLANE_IP: \"${CONTROL_PLANE_IP}\"/" "${TEST_WINDSOR_YAML}"
  sed -i "s/WORKER_0_IP: \".*\"/WORKER_0_IP: \"${WORKER_0_IP}\"/" "${TEST_WINDSOR_YAML}"
  sed -i "s/WORKER_1_IP: \".*\"/WORKER_1_IP: \"${WORKER_1_IP}\"/" "${TEST_WINDSOR_YAML}"
fi

# Append updated IPs so regenerate-tfvars / generate-tfvars see them
{
  echo "export CONTROL_PLANE_IP='${CONTROL_PLANE_IP}'"
  echo "export WORKER_0_IP='${WORKER_0_IP}'"
  echo "export WORKER_1_IP='${WORKER_1_IP}'"
} >> "${ENV_FILE}"

