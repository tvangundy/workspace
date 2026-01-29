#!/usr/bin/env bash
# Destroy Talos cluster using Terraform
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Check if cluster name was provided as argument
CLI_ARGS_STR="${1:-}"
CLUSTER_NAME_ARG=""
if [ -n "${CLI_ARGS_STR}" ]; then
  eval set -- ${CLI_ARGS_STR}
  if [ $# -gt 0 ]; then
    CLUSTER_NAME_ARG="${1}"
    export CLUSTER_NAME="${CLUSTER_NAME_ARG}"
  fi
fi

# Load TC environment
load_tc_env

# Override CLUSTER_NAME if provided via argument
if [ -n "${CLUSTER_NAME_ARG}" ]; then
  CLUSTER_NAME="${CLUSTER_NAME_ARG}"
  export CLUSTER_NAME
fi

# Set PROJECT_ROOT
PROJECT_ROOT=$(get_windsor_project_root)

if [ ! -d "${TERRAFORM_DIR}" ]; then
  echo "Error: Terraform directory not found: ${TERRAFORM_DIR}"
  echo "  Cluster may already be destroyed or was never created."
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Destroying Talos Cluster"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Cluster: ${CLUSTER_NAME}"
echo "  Remote: ${REMOTE_NAME}"
echo ""

cd "${TERRAFORM_DIR}"

# Ensure we're using the correct workspace for this cluster
CURRENT_WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
WORKSPACE_EXISTS=false
if terraform workspace list 2>/dev/null | sed 's/^[[:space:]]*\*[[:space:]]*//' | grep -q "^${CLUSTER_NAME}$"; then
  WORKSPACE_EXISTS=true
fi

if [ "${WORKSPACE_EXISTS}" = "true" ]; then
  if [ "${CURRENT_WORKSPACE}" != "${CLUSTER_NAME}" ]; then
    echo "Selecting workspace '${CLUSTER_NAME}'..."
    terraform workspace select "${CLUSTER_NAME}"
  fi
else
  echo "⚠️  Warning: Terraform workspace '${CLUSTER_NAME}' does not exist."
  echo "   Attempting to destroy cluster VMs directly via Incus..."
  
  # Try to destroy VMs directly
  CONTROL_PLANE_VM="${CLUSTER_NAME}-cp"
  WORKER_0_VM="${CLUSTER_NAME}-worker-0"
  WORKER_1_VM="${CLUSTER_NAME}-worker-1"
  
  VMS_DESTROYED=0
  for VM in "${CONTROL_PLANE_VM}" "${WORKER_0_VM}" "${WORKER_1_VM}"; do
    if incus list "${REMOTE_NAME}:${VM}" --format csv -c n 2>/dev/null | grep -q "^${VM}$"; then
      echo "  Destroying ${VM}..."
      if incus delete "${REMOTE_NAME}:${VM}" --force >/dev/null 2>&1; then
        echo "  ✅ Destroyed ${VM}"
        VMS_DESTROYED=$((VMS_DESTROYED + 1))
      else
        echo "  ❌ Failed to destroy ${VM}"
      fi
    fi
  done
  
  if [ ${VMS_DESTROYED} -gt 0 ]; then
    echo ""
    echo "✅ Destroyed ${VMS_DESTROYED} cluster VM(s) via Incus"
    
    # Clean up config files - try active context directory first, then cluster name directory
    CONTEXTS_DIR="${PROJECT_ROOT}/contexts"
    ACTIVE_CONTEXT=""
    if command -v windsor > /dev/null 2>&1; then
      ACTIVE_CONTEXT=$(windsor context get 2>/dev/null || echo "")
      if [ -z "${ACTIVE_CONTEXT}" ] && [ -n "${WINDSOR_CONTEXT:-}" ]; then
        ACTIVE_CONTEXT="${WINDSOR_CONTEXT}"
      fi
    fi
    
    if [ -n "${ACTIVE_CONTEXT}" ]; then
      TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${ACTIVE_CONTEXT}"
    else
      TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${CLUSTER_NAME}"
    fi
    
    TALOSCONFIG_PATH="${TEST_CONTEXT_DIR}/.talos/talosconfig"
    KUBECONFIG_FILE_PATH="${TEST_CONTEXT_DIR}/.kube/config"
    
    [ -f "${TALOSCONFIG_PATH}" ] && rm -f "${TALOSCONFIG_PATH}" && echo "  Removed ${TALOSCONFIG_PATH}"
    [ -f "${KUBECONFIG_FILE_PATH}" ] && rm -f "${KUBECONFIG_FILE_PATH}" && echo "  Removed ${KUBECONFIG_FILE_PATH}"
    
    echo ""
    echo "✅ Cleanup complete"
    exit 0
  else
    echo "   No cluster VMs found to destroy."
    echo "   Cluster may already be destroyed or was never created."
    exit 0
  fi
fi

# Set up signal handlers to properly kill terraform processes
cleanup() {
  echo ""
  echo "Interrupt received, cleaning up terraform processes..."
  TERRAFORM_PIDS=$(pgrep -f "terraform destroy" 2>/dev/null || true)
  if [ -n "${TERRAFORM_PIDS}" ]; then
    echo "  Killing terraform processes: ${TERRAFORM_PIDS}"
    kill -TERM ${TERRAFORM_PIDS} 2>/dev/null || true
    sleep 1
    kill -KILL ${TERRAFORM_PIDS} 2>/dev/null || true
  fi
  exit 130  # Exit code for SIGINT
}

trap cleanup SIGINT SIGTERM

echo "Running: terraform destroy -auto-approve (workspace: ${CLUSTER_NAME})"
echo ""
if terraform destroy -auto-approve; then
  echo ""
  echo "✅ Cluster destroyed successfully"
  
  # Clean up config files - try active context directory first, then cluster name directory
  CONTEXTS_DIR="${PROJECT_ROOT}/contexts"
  ACTIVE_CONTEXT=""
  if command -v windsor > /dev/null 2>&1; then
    ACTIVE_CONTEXT=$(windsor context get 2>/dev/null || echo "")
    if [ -z "${ACTIVE_CONTEXT}" ] && [ -n "${WINDSOR_CONTEXT:-}" ]; then
      ACTIVE_CONTEXT="${WINDSOR_CONTEXT}"
    fi
  fi
  
  if [ -n "${ACTIVE_CONTEXT}" ]; then
    TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${ACTIVE_CONTEXT}"
  else
    TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${CLUSTER_NAME}"
  fi
  
  TALOSCONFIG_PATH="${TEST_CONTEXT_DIR}/.talos/talosconfig"
  KUBECONFIG_FILE_PATH="${TEST_CONTEXT_DIR}/.kube/config"
  
  [ -f "${TALOSCONFIG_PATH}" ] && rm -f "${TALOSCONFIG_PATH}" && echo "  Removed ${TALOSCONFIG_PATH}"
  [ -f "${KUBECONFIG_FILE_PATH}" ] && rm -f "${KUBECONFIG_FILE_PATH}" && echo "  Removed ${KUBECONFIG_FILE_PATH}"
  
  # Delete the workspace if it exists (optional cleanup)
  if terraform workspace list 2>/dev/null | grep -q "^[[:space:]]*${CLUSTER_NAME}$"; then
    echo "  Deleting Terraform workspace '${CLUSTER_NAME}'..."
    terraform workspace select default 2>/dev/null || true
    terraform workspace delete "${CLUSTER_NAME}" 2>/dev/null || true
  fi
  
  echo ""
  echo "✅ Cleanup complete"
else
  EXIT_CODE=$?
  echo ""
  echo "❌ Cluster destruction failed with exit code ${EXIT_CODE}"
  exit ${EXIT_CODE}
fi

