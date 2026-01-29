#!/usr/bin/env bash
# Initialize Windsor context and create contexts/<cluster>/windsor.yaml for instantiate.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/tc-common.sh"

# Load TC environment
load_tc_env

# Get project root and set ENV_FILE
PROJECT_ROOT=$(get_windsor_project_root)
ENV_FILE="${PROJECT_ROOT}/.tc-instantiate.env"

log_step "Initializing Windsor context and creating cluster configuration"

# Generate cluster-specific VM names to avoid collisions
# Always generate VM names from current CLUSTER_NAME to ensure they match the cluster being created
# This prevents conflicts when creating a new cluster with a different name
CONTROL_PLANE_VM="${CLUSTER_NAME}-cp"
WORKER_0_VM="${CLUSTER_NAME}-worker-0"
WORKER_1_VM="${CLUSTER_NAME}-worker-1"

# Export immediately so they're available for this script and subsequent scripts
export CONTROL_PLANE_VM WORKER_0_VM WORKER_1_VM
TALOS_IMAGE_VERSION="${TALOS_IMAGE_VERSION:-v1.12.0}"
TALOS_IMAGE_ARCH="${TALOS_IMAGE_ARCH:-metal-amd64}"
PHYSICAL_INTERFACE="${PHYSICAL_INTERFACE:-eno1}"
STORAGE_POOL="${STORAGE_POOL:-local}"
CONTROL_PLANE_MEMORY="${CONTROL_PLANE_MEMORY:-2GB}"
CONTROL_PLANE_CPU="${CONTROL_PLANE_CPU:-2}"
WORKER_MEMORY="${WORKER_MEMORY:-2GB}"
WORKER_CPU="${WORKER_CPU:-2}"
CONTROL_PLANE_IP="${CONTROL_PLANE_IP:-192.168.2.57}"
WORKER_0_IP="${WORKER_0_IP:-192.168.2.123}"
WORKER_1_IP="${WORKER_1_IP:-192.168.2.20}"
# MAC addresses for fixed IP assignment via DHCP reservations
# These ensure VMs get consistent IPs when DHCP reservations are configured
CONTROL_PLANE_MAC="${CONTROL_PLANE_MAC:-10:66:6a:9d:c1:d6}"
WORKER_0_MAC="${WORKER_0_MAC:-10:66:6a:ef:12:03}"
WORKER_1_MAC="${WORKER_1_MAC:-10:66:6a:32:10:2f}"

CONTEXTS_DIR="${PROJECT_ROOT}/contexts"

# Determine which context directory to use
# If there's an active context, use that directory; otherwise use CLUSTER_NAME
ACTIVE_CONTEXT=""
if command -v windsor > /dev/null 2>&1; then
  ACTIVE_CONTEXT=$(windsor context get 2>/dev/null || echo "")
  if [ -z "${ACTIVE_CONTEXT}" ] && [ -n "${WINDSOR_CONTEXT:-}" ]; then
    ACTIVE_CONTEXT="${WINDSOR_CONTEXT}"
  fi
fi

if [ -n "${ACTIVE_CONTEXT}" ]; then
  # Use active context directory
  TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${ACTIVE_CONTEXT}"
else
  # No active context, use CLUSTER_NAME
  TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${CLUSTER_NAME}"
fi

TALOSCONFIG_PATH="${TEST_CONTEXT_DIR}/.talos/talosconfig"
KUBECONFIG_FILE_PATH="${TEST_CONTEXT_DIR}/.kube/config"
TEST_WINDSOR_YAML="${TEST_CONTEXT_DIR}/windsor.yaml"

mkdir -p "${TEST_CONTEXT_DIR}/.talos"
mkdir -p "${TEST_CONTEXT_DIR}/.kube"

[ -f "${TALOSCONFIG_PATH}" ] && rm -f "${TALOSCONFIG_PATH}"
[ -f "${KUBECONFIG_FILE_PATH}" ] && rm -f "${KUBECONFIG_FILE_PATH}"

# Check if windsor.yaml already exists
if [ -f "${TEST_WINDSOR_YAML}" ]; then
  log_info "Found existing windsor.yaml, updating environment variables"
  
  # Create a temporary file with new environment variables
  TEMP_ENV=$(mktemp)
  {
    echo "  INCUS_REMOTE_NAME: ${TEST_REMOTE_NAME}"
    echo "  CLUSTER_NAME: ${CLUSTER_NAME}"
    echo "  CONTROL_PLANE_IP: \"${CONTROL_PLANE_IP}\""
    echo "  WORKER_0_IP: \"${WORKER_0_IP}\""
    echo "  WORKER_1_IP: \"${WORKER_1_IP}\""
    echo "  CONTROL_PLANE_VM: ${CONTROL_PLANE_VM}"
    echo "  WORKER_0_VM: ${WORKER_0_VM}"
    echo "  WORKER_1_VM: ${WORKER_1_VM}"
    echo "  CONTROL_PLANE_MAC: \"${CONTROL_PLANE_MAC}\""
    echo "  WORKER_0_MAC: \"${WORKER_0_MAC}\""
    echo "  WORKER_1_MAC: \"${WORKER_1_MAC}\""
    echo "  TALOS_IMAGE_VERSION: ${TALOS_IMAGE_VERSION}"
    echo "  TALOS_IMAGE_ARCH: ${TALOS_IMAGE_ARCH}"
    echo "  PHYSICAL_INTERFACE: ${PHYSICAL_INTERFACE}"
    echo "  STORAGE_POOL: ${STORAGE_POOL}"
    echo "  CONTROL_PLANE_MEMORY: ${CONTROL_PLANE_MEMORY}"
    echo "  CONTROL_PLANE_CPU: ${CONTROL_PLANE_CPU}"
    echo "  WORKER_MEMORY: ${WORKER_MEMORY}"
    echo "  WORKER_CPU: ${WORKER_CPU}"
    echo "  TALOSCONFIG: ${TALOSCONFIG_PATH}"
    echo "  KUBECONFIG_FILE: ${KUBECONFIG_FILE_PATH}"
    echo "  KUBECONFIG: ${KUBECONFIG_FILE_PATH}"
  } > "${TEMP_ENV}"
  
  # Check if environment section exists
  if grep -q "^environment:" "${TEST_WINDSOR_YAML}"; then
    # Environment section exists - remove old TC-related vars and append new ones
    TEMP_FILE=$(mktemp)
    # List of all TC-related variable names to remove (regardless of whether they're in new_vars)
    # This ensures we remove duplicates even if the variable name appears multiple times
    awk -v temp_env="${TEMP_ENV}" -f - "${TEST_WINDSOR_YAML}" <<'AWK_SCRIPT' > "${TEMP_FILE}"
      BEGIN {
        # Load new variables from temp_env
        while (getline line < temp_env > 0) {
          split(line, parts, ":")
          var_name = parts[1]
          gsub(/^[[:space:]]+/, "", var_name)
          new_vars[var_name] = line
        }
        close(temp_env)
        # Track seen non-TC variables to avoid duplicates
        # Define all TC-related variable names that should be removed
        tc_vars["INCUS_REMOTE_NAME"] = 1
        tc_vars["CLUSTER_NAME"] = 1
        tc_vars["CONTROL_PLANE_VM"] = 1
        tc_vars["WORKER_0_VM"] = 1
        tc_vars["WORKER_1_VM"] = 1
        tc_vars["CONTROL_PLANE_IP"] = 1
        tc_vars["WORKER_0_IP"] = 1
        tc_vars["WORKER_1_IP"] = 1
        tc_vars["CONTROL_PLANE_MAC"] = 1
        tc_vars["WORKER_0_MAC"] = 1
        tc_vars["WORKER_1_MAC"] = 1
        tc_vars["TALOS_IMAGE_VERSION"] = 1
        tc_vars["TALOS_IMAGE_ARCH"] = 1
        tc_vars["PHYSICAL_INTERFACE"] = 1
        tc_vars["STORAGE_POOL"] = 1
        tc_vars["CONTROL_PLANE_MEMORY"] = 1
        tc_vars["CONTROL_PLANE_CPU"] = 1
        tc_vars["WORKER_MEMORY"] = 1
        tc_vars["WORKER_CPU"] = 1
        tc_vars["TALOSCONFIG"] = 1
        tc_vars["KUBECONFIG_FILE"] = 1
        tc_vars["KUBECONFIG"] = 1
      }
      /^environment:/ {
        print
        in_env = 1
        next
      }
      in_env && /^[[:space:]]*[A-Z_][A-Z0-9_]*:/ {
        original_line = $0
        # Extract variable name (handle any indentation)
        gsub(/^[[:space:]]+/, "", original_line)
        gsub(/^[[:space:]]*/, "", original_line)
        split(original_line, parts, ":")
        var_name = parts[1]
        # Skip if it's a TC-related variable (will be replaced with new value)
        if (var_name in tc_vars) {
          next
        }
        # Track seen non-TC variables to avoid duplicates
        if (var_name in seen_non_tc_vars) {
          # Duplicate non-TC variable - skip it
          next
        }
        seen_non_tc_vars[var_name] = 1
        # Keep non-TC variables (first occurrence only)
        print $0
        next
      }
      in_env && /^[[:space:]]*$/ {
        if (!vars_added) {
          for (var in new_vars) {
            print new_vars[var]
          }
          vars_added = 1
        }
        print
        next
      }
      in_env && !/^[[:space:]]/ {
        if (!vars_added) {
          for (var in new_vars) {
            print new_vars[var]
          }
          vars_added = 1
        }
        in_env = 0
        print
        next
      }
      {
        print
      }
      END {
        if (in_env && !vars_added) {
          for (var in new_vars) {
            print new_vars[var]
          }
        }
      }
AWK_SCRIPT
    mv "${TEMP_FILE}" "${TEST_WINDSOR_YAML}"
  else
    # No environment section, append it
    {
      cat "${TEST_WINDSOR_YAML}"
      echo "environment:"
      cat "${TEMP_ENV}"
    } > "${TEST_WINDSOR_YAML}.tmp"
    mv "${TEST_WINDSOR_YAML}.tmp" "${TEST_WINDSOR_YAML}"
  fi
  rm -f "${TEMP_ENV}"
else
  # Create new windsor.yaml
  {
    echo "id: ${CLUSTER_NAME}-TC"
    echo "provider: generic"
    echo "environment:"
    echo "  INCUS_REMOTE_NAME: ${TEST_REMOTE_NAME}"
    echo "  CLUSTER_NAME: ${CLUSTER_NAME}"
    echo "  CONTROL_PLANE_IP: \"${CONTROL_PLANE_IP}\""
    echo "  WORKER_0_IP: \"${WORKER_0_IP}\""
    echo "  WORKER_1_IP: \"${WORKER_1_IP}\""
    echo "  CONTROL_PLANE_VM: ${CONTROL_PLANE_VM}"
    echo "  WORKER_0_VM: ${WORKER_0_VM}"
    echo "  WORKER_1_VM: ${WORKER_1_VM}"
    echo "  CONTROL_PLANE_MAC: \"${CONTROL_PLANE_MAC}\""
    echo "  WORKER_0_MAC: \"${WORKER_0_MAC}\""
    echo "  WORKER_1_MAC: \"${WORKER_1_MAC}\""
    echo "  TALOS_IMAGE_VERSION: ${TALOS_IMAGE_VERSION}"
    echo "  TALOS_IMAGE_ARCH: ${TALOS_IMAGE_ARCH}"
    echo "  PHYSICAL_INTERFACE: ${PHYSICAL_INTERFACE}"
    echo "  STORAGE_POOL: ${STORAGE_POOL}"
    echo "  CONTROL_PLANE_MEMORY: ${CONTROL_PLANE_MEMORY}"
    echo "  CONTROL_PLANE_CPU: ${CONTROL_PLANE_CPU}"
    echo "  WORKER_MEMORY: ${WORKER_MEMORY}"
    echo "  WORKER_CPU: ${WORKER_CPU}"
    echo "  TALOSCONFIG: ${TALOSCONFIG_PATH}"
    echo "  KUBECONFIG_FILE: ${KUBECONFIG_FILE_PATH}"
    echo "  KUBECONFIG: ${KUBECONFIG_FILE_PATH}"
  } > "${TEST_WINDSOR_YAML}"
fi

# Only initialize Windsor context if it doesn't already exist
# Don't switch contexts - keep the active context if one exists
if command -v windsor > /dev/null 2>&1; then
  # Check if there's an active context
  ACTIVE_CONTEXT=$(windsor context get 2>/dev/null || echo "")
  if [ -z "${ACTIVE_CONTEXT}" ] && [ -n "${WINDSOR_CONTEXT:-}" ]; then
    ACTIVE_CONTEXT="${WINDSOR_CONTEXT}"
  fi
  
  if [ -n "${ACTIVE_CONTEXT}" ]; then
    # Active context exists - keep it active, don't switch
    log_info "Using active Windsor context '${ACTIVE_CONTEXT}' (cluster will be named '${CLUSTER_NAME}')"
    # If windsor.yaml exists in the context directory, the context is effectively initialized
    # Only check Windsor's context list if windsor.yaml doesn't exist
    if [ ! -f "${TEST_WINDSOR_YAML}" ]; then
      # windsor.yaml doesn't exist - check if context is registered with Windsor
      if ! windsor context list --format csv 2>/dev/null | grep -q "^${ACTIVE_CONTEXT},"; then
        log_info "Initializing Windsor context '${ACTIVE_CONTEXT}'..."
        windsor init --context "${ACTIVE_CONTEXT}" --backend local --config-dir "${CONTEXTS_DIR}/${ACTIVE_CONTEXT}" > /dev/null 2>&1 || true
      fi
    fi
    # If windsor.yaml exists, context is valid regardless of Windsor's list
  else
    # No active context - check if context exists for cluster name, or create one
    if windsor context list --format csv 2>/dev/null | grep -q "^${CLUSTER_NAME},"; then
      log_info "Windsor context '${CLUSTER_NAME}' already exists, setting as active"
      windsor context set "${CLUSTER_NAME}" > /dev/null 2>&1 || true
    else
      log_info "Initializing new Windsor context '${CLUSTER_NAME}'"
      windsor init --context "${CLUSTER_NAME}" --backend local --config-dir "${TEST_CONTEXT_DIR}" > /dev/null 2>&1 || \
      windsor context set "${CLUSTER_NAME}" > /dev/null 2>&1 || true
    fi
  fi
fi

# Update .tc-instantiate.env with context vars for later scripts
# Remove old VM name exports first to avoid conflicts, then append new values
if [ -f "${ENV_FILE}" ]; then
  # Remove old VM name exports if they exist
  sed -i.bak '/^export CONTROL_PLANE_VM=/d; /^export WORKER_0_VM=/d; /^export WORKER_1_VM=/d' "${ENV_FILE}" 2>/dev/null || \
  sed -i '/^export CONTROL_PLANE_VM=/d; /^export WORKER_0_VM=/d; /^export WORKER_1_VM=/d' "${ENV_FILE}" 2>/dev/null || true
  rm -f "${ENV_FILE}.bak" 2>/dev/null || true
fi

# Determine context name for export (use active context if available, otherwise CLUSTER_NAME)
CONTEXT_NAME_FOR_EXPORT="${ACTIVE_CONTEXT:-${CLUSTER_NAME}}"

# Append context vars to .tc-instantiate.env for later scripts
{
  echo "export CLUSTER_NAME='${CLUSTER_NAME}'"
  echo "export WINDSOR_CONTEXT='${CONTEXT_NAME_FOR_EXPORT}'"
  echo "export CONTROL_PLANE_VM='${CONTROL_PLANE_VM}'"
  echo "export WORKER_0_VM='${WORKER_0_VM}'"
  echo "export WORKER_1_VM='${WORKER_1_VM}'"
  echo "export CONTROL_PLANE_IP='${CONTROL_PLANE_IP}'"
  echo "export WORKER_0_IP='${WORKER_0_IP}'"
  echo "export WORKER_1_IP='${WORKER_1_IP}'"
  echo "export TALOSCONFIG_PATH='${TALOSCONFIG_PATH}'"
  echo "export KUBECONFIG_FILE_PATH='${KUBECONFIG_FILE_PATH}'"
  echo "export TALOSCONFIG='${TALOSCONFIG_PATH}'"
  echo "export KUBECONFIG_FILE='${KUBECONFIG_FILE_PATH}'"
  echo "export TEST_WINDSOR_YAML='${TEST_WINDSOR_YAML}'"
  echo "export TALOS_IMAGE_VERSION='${TALOS_IMAGE_VERSION}'"
  echo "export TALOS_IMAGE_ARCH='${TALOS_IMAGE_ARCH}'"
  echo "export PHYSICAL_INTERFACE='${PHYSICAL_INTERFACE}'"
  echo "export STORAGE_POOL='${STORAGE_POOL}'"
  echo "export CONTROL_PLANE_MEMORY='${CONTROL_PLANE_MEMORY}'"
  echo "export CONTROL_PLANE_CPU='${CONTROL_PLANE_CPU}'"
  echo "export WORKER_MEMORY='${WORKER_MEMORY}'"
  echo "export WORKER_CPU='${WORKER_CPU}'"
  echo "export CONTROL_PLANE_MAC='${CONTROL_PLANE_MAC}'"
  echo "export WORKER_0_MAC='${WORKER_0_MAC}'"
  echo "export WORKER_1_MAC='${WORKER_1_MAC}'"
} >> "${ENV_FILE}"

# Determine context name for message
CONTEXT_NAME_FOR_MSG="${ACTIVE_CONTEXT:-${CLUSTER_NAME}}"
if [ -f "${TEST_WINDSOR_YAML}" ]; then
  echo "✅ Updated ${TEST_WINDSOR_YAML} in context '${CONTEXT_NAME_FOR_MSG}'"
else
  echo "✅ Created ${TEST_WINDSOR_YAML} in context '${CONTEXT_NAME_FOR_MSG}'"
fi

