#!/usr/bin/env bash
# Apply Terraform configuration to create Talos cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

if [ ! -d "${TERRAFORM_DIR}" ]; then
  echo "Error: Terraform directory not found: ${TERRAFORM_DIR}"
  exit 1
fi

# Set up signal handlers to properly kill terraform and child processes
cleanup() {
  echo ""
  echo "Interrupt received, cleaning up terraform processes..."
  # Find and kill terraform processes
  TERRAFORM_PIDS=$(pgrep -f "terraform apply" 2>/dev/null || true)
  if [ -n "${TERRAFORM_PIDS}" ]; then
    echo "  Killing terraform processes: ${TERRAFORM_PIDS}"
    kill -TERM ${TERRAFORM_PIDS} 2>/dev/null || true
    sleep 1
    # Force kill if still running
    kill -KILL ${TERRAFORM_PIDS} 2>/dev/null || true
  fi
  # Kill any child processes (like nc, sh scripts from null_resource)
  CHILD_PIDS=$(pgrep -P $$ 2>/dev/null || true)
  if [ -n "${CHILD_PIDS}" ]; then
    echo "  Killing child processes: ${CHILD_PIDS}"
    kill -TERM ${CHILD_PIDS} 2>/dev/null || true
    sleep 1
    kill -KILL ${CHILD_PIDS} 2>/dev/null || true
  fi
  exit 130  # Exit code for SIGINT
}

trap cleanup SIGINT SIGTERM

cd "${TERRAFORM_DIR}"

# Ensure we're using the correct workspace for this cluster
CURRENT_WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
if [ "${CURRENT_WORKSPACE}" != "${CLUSTER_NAME}" ]; then
  echo "⚠️  Warning: Terraform workspace is '${CURRENT_WORKSPACE}', expected '${CLUSTER_NAME}'"
  echo "   Selecting workspace '${CLUSTER_NAME}'..."
  if terraform workspace list 2>/dev/null | grep -q "^[[:space:]]*${CLUSTER_NAME}$"; then
    terraform workspace select "${CLUSTER_NAME}"
  else
    terraform workspace new "${CLUSTER_NAME}"
  fi
fi

terraform apply -auto-approve

