#!/usr/bin/env bash
# Incus-specific utilities
# Source this from other scripts. Do not run directly.

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Verify Incus remote exists and is reachable
verify_incus_remote() {
  local remote_name="${1:-${INCUS_REMOTE_NAME:-}}"
  
  if [ -z "${remote_name}" ]; then
    log_error "Remote name is required"
    return 1
  fi
  
  # Check if remote exists - handle both CSV and table formats
  # Remote names may have "(current)" suffix in CSV format: "nuc (current),url,..."
  local remote_exists=false
  
  # Try CSV format first - extract first column and normalize (remove "(current)" suffix)
  local csv_remotes
  csv_remotes=$(incus remote list --format csv 2>/dev/null | cut -d',' -f1 | sed 's/ (current)$//' 2>/dev/null || echo "")
  if echo "${csv_remotes}" | grep -qE "^${remote_name}$"; then
    remote_exists=true
  # Fallback to table format - extract first column from data rows
  elif incus remote list 2>/dev/null | awk 'NR>2 && NF>0 {print $1}' | sed 's/ (current)$//' | grep -qE "^${remote_name}$"; then
    remote_exists=true
  fi
  
  if [ "${remote_exists}" = "false" ]; then
    log_error "Remote '${remote_name}' does not exist"
    log_info "Available remotes:"
    incus remote list 2>/dev/null || true
    return 1
  fi
  
  # Check if we can connect to remote
  if ! incus list "${remote_name}:" --format csv >/dev/null 2>&1; then
    log_error "Cannot connect to remote '${remote_name}'"
    return 1
  fi
  
  log_info "Remote '${remote_name}' verified and reachable"
  return 0
}

# Check if instance exists on remote
instance_exists() {
  local remote_name="$1"
  local instance_name="$2"
  
  if incus list "${remote_name}:${instance_name}" --format csv -c n 2>/dev/null | grep -q "^${instance_name}$"; then
    return 0
  fi
  return 1
}

# Get instance IP address
get_instance_ip() {
  local remote_name="$1"
  local instance_name="$2"
  local interface="${3:-}"
  
  local ip_address=""
  
  # Try JSON format first (most reliable)
  if command -v jq >/dev/null 2>&1; then
    ip_address=$(incus list "${remote_name}:${instance_name}" --format json 2>/dev/null | \
      jq -r '.[0].state.network | to_entries[] | .value.addresses[]? | select(.family=="inet" and .address != "127.0.0.1") | .address' 2>/dev/null | \
      grep -vE '^172\.17\.|^10\.53\.' | head -1 || echo "")
  fi
  
  # Fallback to CSV format
  if [ -z "${ip_address}" ]; then
    ip_address=$(incus list "${remote_name}:${instance_name}" --format csv -c n,IPv4 2>/dev/null | \
      grep "^${instance_name}," | cut -d',' -f3 | awk '{print $1}' | \
      grep -vE '^-$|^172\.17\.|^10\.53\.' | head -1 || echo "")
  fi
  
  # Validate IP format
  if [ -n "${ip_address}" ] && echo "${ip_address}" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    echo "${ip_address}"
    return 0
  fi
  
  return 1
}

# Wait for instance to be running
wait_for_instance_running() {
  local remote_name="$1"
  local instance_name="$2"
  local max_attempts="${3:-30}"
  
  wait_for_condition \
    "instance '${instance_name}' on remote '${remote_name}' to be running" \
    "incus list '${remote_name}:${instance_name}' --format csv -c s 2>/dev/null | grep -q 'RUNNING'" \
    "${max_attempts}" \
    5
}

