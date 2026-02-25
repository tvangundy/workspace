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

# Load VM-specific environment: Windsor context first (single source of truth), then session file (CLI/computed vars).
# See docs/runbooks/workspace/instantiate-env-and-windsor-env.md
load_vm_env() {
  local project_root
  project_root=$(get_windsor_project_root)
  load_windsor_env_for_shell
  source_env_file "${project_root}/.workspace/.vm-instantiate.env"

  # Defaults only for vars still unset (session file and windsor env may have set them)
  TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME:-}}"
  VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME:-vm}}"
  VM_IMAGE="${VM_IMAGE:-ubuntu/25.04}"
  VM_MEMORY="${VM_MEMORY:-16GB}"
  VM_CPU="${VM_CPU:-4}"
  VM_DISK_SIZE="${VM_DISK_SIZE:-100GB}"
  VM_NETWORK_NAME="${VM_NETWORK_NAME:-}"
  VM_STORAGE_POOL="${VM_STORAGE_POOL:-local}"
  VM_AUTOSTART="${VM_AUTOSTART:-false}"

  export TEST_REMOTE_NAME VM_NAME VM_IMAGE VM_MEMORY VM_CPU VM_DISK_SIZE
  export VM_NETWORK_NAME VM_STORAGE_POOL VM_AUTOSTART
}

