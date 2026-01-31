#!/usr/bin/env bash
# Device-specific shared utilities
# Source this from device scripts. Do not run directly.

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../../lib" && pwd)"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/windsor.sh"

# Load device environment (Windsor context and variables)
load_device_env() {
  local project_root
  project_root="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
  export WINDSOR_PROJECT_ROOT="${project_root}"

  # Load Windsor environment if available
  if command -v windsor >/dev/null 2>&1; then
    local windsor_env_output
    windsor_env_output=$(windsor env 2>/dev/null || echo "")
    if [ -n "${windsor_env_output}" ]; then
      set +u
      eval "${windsor_env_output}" || true
      set -u
    fi
  fi

  export WINDSOR_PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
}
