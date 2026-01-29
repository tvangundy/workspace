#!/usr/bin/env bash
# Generate tfvars, init Terraform, create cluster VMs (first terraform apply).
set -euo pipefail

# Save SCRIPT_DIR before sourcing libraries (they may overwrite it)
TC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${TC_SCRIPT_DIR}"
source "${TC_SCRIPT_DIR}/../lib/tc-common.sh"

# Restore SCRIPT_DIR after sourcing (libraries may have overwritten it)
SCRIPT_DIR="${TC_SCRIPT_DIR}"

# Load TC environment
load_tc_env

# Set up signal handlers to properly kill child processes
cleanup() {
  echo ""
  echo "Interrupt received, cleaning up processes..."
  # Find and kill terraform processes
  TERRAFORM_PIDS=$(pgrep -f "terraform" 2>/dev/null || true)
  if [ -n "${TERRAFORM_PIDS}" ]; then
    echo "  Killing terraform processes: ${TERRAFORM_PIDS}"
    kill -TERM ${TERRAFORM_PIDS} 2>/dev/null || true
    sleep 1
    # Force kill if still running
    kill -KILL ${TERRAFORM_PIDS} 2>/dev/null || true
  fi
  # Kill any child processes spawned by terraform (nc, sh scripts, etc.)
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

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating cluster VMs and applying Talos configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Generating terraform.tfvars..."
if ! "${SCRIPT_DIR}/generate-tfvars.sh"; then
  echo "❌ Failed to generate terraform.tfvars"
  exit 1
fi
echo "✅ terraform.tfvars generated"

echo ""
"${SCRIPT_DIR}/terraform-init.sh"

# Terraform workspaces will be used to isolate state per cluster
# No need to check for state conflicts - each cluster has its own workspace

echo ""
echo "Creating cluster VMs (this may take several minutes)..."
echo "  (Press Ctrl+C to cancel - this will clean up all processes)"
if "${SCRIPT_DIR}/terraform-apply.sh"; then
  echo "✅ Cluster VMs created"
else
  EXIT_CODE=$?
  if [ ${EXIT_CODE} -eq 130 ]; then
    echo "❌ Cluster VM creation was interrupted"
  else
    echo "❌ Cluster VM creation failed"
  fi
  exit ${EXIT_CODE}
fi

