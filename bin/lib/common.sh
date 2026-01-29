#!/usr/bin/env bash
# Shared common utilities for all scripts
# Source this from other scripts. Do not run directly.

set -euo pipefail

# Logging functions
log_info() {
  echo "✅ $*"
}

log_error() {
  echo "❌ $*" >&2
}

log_warning() {
  echo "⚠️  $*" >&2
}

log_step() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$*"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Get project root from environment or current directory
get_project_root() {
  echo "${WINDSOR_PROJECT_ROOT:-$(pwd)}"
}

# Idempotency helper: check if resource exists before creating
ensure_resource_exists() {
  local resource_type="$1"
  local resource_name="$2"
  local check_cmd="$3"
  local create_cmd="$4"
  
  if eval "$check_cmd" >/dev/null 2>&1; then
    log_info "$resource_type '$resource_name' already exists, skipping creation"
    return 0
  fi
  
  log_info "Creating $resource_type '$resource_name'..."
  if eval "$create_cmd"; then
    log_info "$resource_type '$resource_name' created successfully"
    return 0
  else
    log_error "Failed to create $resource_type '$resource_name'"
    return 1
  fi
}

# Wait for condition with timeout
wait_for_condition() {
  local description="$1"
  local check_cmd="$2"
  local max_attempts="${3:-30}"
  local delay="${4:-5}"
  local attempt=0
  
  log_info "Waiting for $description..."
  while [ $attempt -lt $max_attempts ]; do
    if eval "$check_cmd" >/dev/null 2>&1; then
      log_info "$description - ready"
      return 0
    fi
    
    attempt=$((attempt + 1))
    if [ $((attempt % 3)) -eq 0 ]; then
      local elapsed=$((attempt * delay))
      log_info "  Still waiting... [${attempt}/${max_attempts} attempts, ~${elapsed}s elapsed]"
    fi
    sleep $delay
  done
  
  log_error "$description - timeout after $((max_attempts * delay)) seconds"
  return 1
}

# Safe source of environment file
source_env_file() {
  local env_file="$1"
  if [ -f "${env_file}" ]; then
    set +u
    source "${env_file}"
    set -u
    return 0
  fi
  return 1
}

