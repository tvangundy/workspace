#!/usr/bin/env bash
# Windsor-specific utilities
# Source this from other scripts. Do not run directly.

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load Windsor environment variables
load_windsor_env() {
  local context="${1:-${WINDSOR_CONTEXT:-}}"
  
  if [ -z "${context}" ]; then
    log_warning "No Windsor context specified"
    return 1
  fi
  
  # Set context if not already set
  if [ "${WINDSOR_CONTEXT:-}" != "${context}" ]; then
    if windsor context set "${context}" >/dev/null 2>&1; then
      export WINDSOR_CONTEXT="${context}"
    else
      log_warning "Could not set Windsor context to '${context}'"
    fi
  fi
  
  # Load environment variables
  local windsor_env_output
  windsor_env_output=$(windsor env 2>/dev/null || echo "")
  
  if [ -n "${windsor_env_output}" ]; then
    eval "${windsor_env_output}" || return 1
    return 0
  else
    log_warning "Could not get Windsor environment output"
    return 1
  fi
}

# Initialize Windsor context if it doesn't exist
init_windsor_context() {
  local context="${1:-${WINDSOR_CONTEXT:-}}"
  
  if [ -z "${context}" ]; then
    log_error "Context name is required"
    return 1
  fi
  
  if windsor init "${context}" >/dev/null 2>&1; then
    log_info "Windsor context '${context}' initialized"
    return 0
  else
    log_info "Windsor context '${context}' may already exist, continuing..."
    return 0
  fi
}

# Get Windsor project root
get_windsor_project_root() {
  local project_root="${WINDSOR_PROJECT_ROOT:-}"
  
  if [ -z "${project_root}" ]; then
    project_root=$(get_project_root)
  fi
  
  echo "${project_root}"
}

