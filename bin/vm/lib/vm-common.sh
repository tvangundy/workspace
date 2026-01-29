#!/usr/bin/env bash
# VM-specific shared utilities
# Source this from VM scripts. Do not run directly.

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../../lib" && pwd)"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/windsor.sh"
source "${LIB_DIR}/incus.sh"

# Load VM-specific environment
load_vm_env() {
  local project_root
  project_root=$(get_windsor_project_root)
  local env_file="${project_root}/.vm-instantiate.env"
  
  source_env_file "${env_file}"
  
  # Set defaults
  TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME:-}}"
  VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME:-vm}}"
  VM_IMAGE="${VM_IMAGE:-ubuntu/24.04}"
  VM_MEMORY="${VM_MEMORY:-16GB}"
  VM_CPU="${VM_CPU:-4}"
  VM_DISK_SIZE="${VM_DISK_SIZE:-100GB}"
  VM_NETWORK_NAME="${VM_NETWORK_NAME:-}"
  VM_STORAGE_POOL="${VM_STORAGE_POOL:-local}"
  VM_AUTOSTART="${VM_AUTOSTART:-false}"
  VM_INIT_WORKSPACE="${VM_INIT_WORKSPACE:-true}"
  
  export TEST_REMOTE_NAME VM_NAME VM_IMAGE VM_MEMORY VM_CPU VM_DISK_SIZE
  export VM_NETWORK_NAME VM_STORAGE_POOL VM_AUTOSTART VM_INIT_WORKSPACE
}

