#!/usr/bin/env bash
# TC-specific shared utilities
# Source this from TC scripts. Do not run directly.

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../../lib" && pwd)"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/windsor.sh"
source "${LIB_DIR}/incus.sh"
source "${LIB_DIR}/terraform.sh"

# Load TC-specific environment
load_tc_env() {
  local project_root
  project_root=$(get_windsor_project_root)
  local env_file="${project_root}/.workspace/.tc-instantiate.env"
  
  source_env_file "${env_file}"
  
  # Set defaults
  TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-}"
  REMOTE_NAME="${INCUS_REMOTE_NAME:-${TEST_REMOTE_NAME}}"
  CLUSTER_NAME="${CLUSTER_NAME:-talos-test-cluster}"
  
  # VM names default to cluster-specific names if not explicitly set
  # This prevents collisions between different clusters
  # initialize-context.sh will set these if not already set
  CONTROL_PLANE_VM="${CONTROL_PLANE_VM:-}"
  WORKER_0_VM="${WORKER_0_VM:-}"
  WORKER_1_VM="${WORKER_1_VM:-}"
  
  TERRAFORM_DIR="${project_root}/terraform/cluster"
  
  export TEST_REMOTE_NAME REMOTE_NAME CLUSTER_NAME
  export CONTROL_PLANE_VM WORKER_0_VM WORKER_1_VM TERRAFORM_DIR
}

# Resolve context directory: WINDSOR_CONTEXT takes precedence over CLUSTER_NAME
get_tc_context_dir() {
  local project_root="${1:?project_root required}"
  local cluster_name="${2:-}"
  local contexts_dir="${project_root}/contexts"
  local ctx="${WINDSOR_CONTEXT:-}"
  if [ -z "${ctx}" ] && command -v windsor >/dev/null 2>&1; then
    ctx=$(windsor context get 2>/dev/null || echo "")
  fi
  if [ -n "${ctx}" ]; then
    echo "${contexts_dir}/${ctx}"
  else
    echo "${contexts_dir}/${cluster_name}"
  fi
}
