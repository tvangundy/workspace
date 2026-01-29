#!/usr/bin/env bash
# Initialize Windsor context for VM instantiate
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"
VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
PROJECT_ROOT="${PROJECT_ROOT:-${WINDSOR_PROJECT_ROOT}}"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Initialize Windsor Context"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create contexts directory if it doesn't exist
CONTEXTS_DIR="${PROJECT_ROOT}/contexts"

# Determine which context directory to use
# If there's an active context, use that directory; otherwise use VM_NAME
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
  # No active context, use VM_NAME
  TEST_CONTEXT_DIR="${CONTEXTS_DIR}/${VM_NAME}"
fi

TEST_WINDSOR_YAML="${TEST_CONTEXT_DIR}/windsor.yaml"

mkdir -p "${TEST_CONTEXT_DIR}"

# Get default values for environment variables
VM_IMAGE="${VM_IMAGE:-ubuntu/24.04}"
VM_MEMORY="${VM_MEMORY:-16GB}"
VM_CPU="${VM_CPU:-4}"
VM_DISK_SIZE="${VM_DISK_SIZE:-100GB}"

# Function to ensure physical network is configured
ensure_physical_network() {
  local iface=""
  local has_instances_role=false
  
  echo "  Checking physical network configuration..."
  
  # If using a remote (not local), check networks on the remote to infer the interface
  if [ -n "${TEST_REMOTE_NAME:-}" ] && [ "${TEST_REMOTE_NAME}" != "local" ]; then
    # Check existing networks on the remote to find physical networks
    for candidate in enp5s0 eno1 eth0; do
      # Check if a network with this name exists on the remote
      if incus network show "${TEST_REMOTE_NAME}:${candidate}" >/dev/null 2>&1; then
        NETWORK_JSON=$(incus network show "${TEST_REMOTE_NAME}:${candidate}" --format json 2>/dev/null || echo "")
        if [ -n "${NETWORK_JSON}" ]; then
          NETWORK_TYPE=$(echo "${NETWORK_JSON}" | grep -o '"type":"[^"]*"' | cut -d'"' -f4 || echo "")
          if [ "${NETWORK_TYPE}" = "physical" ]; then
            iface="${candidate}"
            has_instances_role=true  # If network exists and is physical, assume it's configured
            break
          fi
        fi
      fi
    done
    
    # If no existing network found, try to detect from network list
    if [ -z "${iface}" ]; then
      # List all networks and look for physical ones
      NETWORK_LIST=$(incus network list "${TEST_REMOTE_NAME}:" --format json 2>/dev/null || echo "")
      if [ -n "${NETWORK_LIST}" ]; then
        for candidate in enp5s0 eno1 eth0; do
          if echo "${NETWORK_LIST}" | grep -q "\"${candidate}\""; then
            iface="${candidate}"
            has_instances_role=true
            break
          fi
        done
      fi
    fi
    
    # If still not found, use default based on common patterns
    if [ -z "${iface}" ]; then
      # Default to eno1 which is common on servers
      iface="eno1"
      echo "    ⚠️  Could not detect interface from remote, using default: ${iface}"
    fi
  else
    # Local server - use admin command to detect interface
    for candidate in enp5s0 eno1 eth0; do
      if incus admin os system network show 2>/dev/null | grep -q "name: ${candidate}"; then
        iface="${candidate}"
        # Check if it has instances role (check both config and state sections)
        if incus admin os system network show 2>/dev/null | grep -A 30 "name: ${candidate}" | grep -q "instances"; then
          has_instances_role=true
        fi
        break
      fi
    done
    
    if [ -z "${iface}" ]; then
      echo "❌ Error: Could not detect physical network interface (checked: enp5s0, eno1, eth0)"
      echo "   Please configure a physical network interface manually"
      echo "   Run: task incus:check-network-config"
      exit 1
    fi
  fi
  
  echo "    Detected interface: ${iface}"
  
  # Check if instances role is configured (only for local server)
  if [ -z "${TEST_REMOTE_NAME:-}" ] || [ "${TEST_REMOTE_NAME}" = "local" ]; then
    if [ "${has_instances_role}" != "true" ]; then
      echo "    ❌ Missing 'instances' role on ${iface}"
      echo ""
      echo "    To fix this, run the following command:"
      echo "      incus admin os system network edit"
      echo ""
      echo "    Then find '${iface}' in the config.interfaces section and add 'instances' to the roles list:"
      echo "      roles:"
      echo "      - management"
      echo "      - cluster"
      echo "      - instances     # Add this line"
      echo ""
      echo "    After saving, run this script again."
      echo ""
      echo "    Or run: task incus:check-network-config"
      exit 1
    fi
    echo "    ✓ Interface ${iface} has 'instances' role"
  else
    # For remote servers, assume it's configured if network exists
    echo "    ✓ Using interface ${iface} on remote '${TEST_REMOTE_NAME}'"
  fi
  
  # Check if physical network exists
  if ! incus network show "${TEST_REMOTE_NAME}:${iface}" >/dev/null 2>&1; then
    echo "    Creating physical network '${iface}'..."
    if ! incus network create "${TEST_REMOTE_NAME}:${iface}" parent="${iface}" --type=physical 2>&1; then
      echo "    ❌ Error: Failed to create physical network"
      echo "    Please run: PHYSICAL_INTERFACE=${iface} task incus:create-physical-network"
      exit 1
    fi
    echo "    ✓ Physical network '${iface}' created"
  else
    # Verify it's a physical network type
    NETWORK_JSON=$(incus network show "${TEST_REMOTE_NAME}:${iface}" --format json 2>/dev/null || echo "")
    if [ -n "${NETWORK_JSON}" ]; then
      NETWORK_TYPE=$(echo "${NETWORK_JSON}" | grep -o '"type":"[^"]*"' | cut -d'"' -f4 || echo "")
      if [ "${NETWORK_TYPE}" != "physical" ]; then
        echo "    ⚠️  Network '${iface}' exists but is not type 'physical' (type: ${NETWORK_TYPE})"
        echo "    Deleting and recreating as physical network..."
        incus network delete "${TEST_REMOTE_NAME}:${iface}" 2>/dev/null || true
        sleep 2  # Give it a moment to clean up
        if ! incus network create "${TEST_REMOTE_NAME}:${iface}" parent="${iface}" --type=physical 2>&1; then
          echo "    ❌ Error: Failed to recreate physical network"
          echo "    Please run: incus network delete ${TEST_REMOTE_NAME}:${iface}"
          echo "    Then: PHYSICAL_INTERFACE=${iface} task incus:create-physical-network"
          exit 1
        fi
        echo "    ✓ Physical network '${iface}' recreated"
      else
        echo "    ✓ Physical network '${iface}' is configured"
      fi
    fi
  fi
  
  # Set VM_NETWORK_NAME to the physical network
  VM_NETWORK_NAME="${iface}"
  echo "    ✓ Physical network configuration complete"
  echo "    ✓ VM_NETWORK_NAME set to: ${VM_NETWORK_NAME}"
}

# Ensure physical network is configured before VM creation
# This ensures VMs get 192.168.2.x addresses instead of 10.x.x.x
if [ -z "${VM_NETWORK_NAME:-}" ]; then
  ensure_physical_network
fi

VM_STORAGE_POOL="${VM_STORAGE_POOL:-local}"
VM_AUTOSTART="${VM_AUTOSTART:-false}"

# Set workspace initialization based on flag
if [ "${SKIP_WORKSPACE:-false}" = "true" ]; then
  VM_INIT_WORKSPACE="false"
else
  VM_INIT_WORKSPACE="true"
fi

# Check if windsor.yaml already exists
if [ -f "${TEST_WINDSOR_YAML}" ]; then
  echo "ℹ️  Found existing windsor.yaml, updating environment variables"
  
  # Create a temporary file with new environment variables
  TEMP_ENV=$(mktemp)
  {
    echo "  INCUS_REMOTE_NAME: ${TEST_REMOTE_NAME}"
    echo "  VM_INIT_WORKSPACE: ${VM_INIT_WORKSPACE}"
    echo "  VM_INSTANCE_NAME: ${VM_NAME}"
    echo "  VM_IMAGE: ${VM_IMAGE}"
    echo "  VM_MEMORY: ${VM_MEMORY}"
    echo "  VM_CPU: ${VM_CPU}"
    echo "  VM_DISK_SIZE: ${VM_DISK_SIZE}"
    if [ -n "${VM_NETWORK_NAME:-}" ]; then
      echo "  VM_NETWORK_NAME: ${VM_NETWORK_NAME}"
    fi
    echo "  VM_STORAGE_POOL: ${VM_STORAGE_POOL}"
    echo "  VM_AUTOSTART: ${VM_AUTOSTART}"
    echo "  DOCKER_HOST: unix:///var/run/docker.sock"
  } > "${TEMP_ENV}"
  
  # Check if environment section exists
  if grep -q "^environment:" "${TEST_WINDSOR_YAML}"; then
    # Environment section exists - remove old VM-related vars and append new ones
    TEMP_FILE=$(mktemp)
    awk -v temp_env="${TEMP_ENV}" -f - "${TEST_WINDSOR_YAML}" <<'AWK_SCRIPT' > "${TEMP_FILE}"
      BEGIN {
        while (getline line < temp_env > 0) {
          split(line, parts, ":")
          var_name = parts[1]
          gsub(/^[[:space:]]+/, "", var_name)
          new_vars[var_name] = line
        }
        close(temp_env)
      }
      /^environment:/ {
        print
        in_env = 1
        next
      }
      in_env && /^[[:space:]]+[A-Z_]+:/ {
        original_line = $0
        gsub(/^[[:space:]]+/, "", original_line)
        split(original_line, parts, ":")
        var_name = parts[1]
        if (var_name in new_vars) {
          next
        }
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
    echo "id: ${VM_NAME}-VM"
    echo "provider: generic"
    echo "environment:"
    echo "  INCUS_REMOTE_NAME: ${TEST_REMOTE_NAME}"
    echo "  VM_INIT_WORKSPACE: ${VM_INIT_WORKSPACE}"
    echo "  VM_INSTANCE_NAME: ${VM_NAME}"
    echo "  VM_IMAGE: ${VM_IMAGE}"
    echo "  VM_MEMORY: ${VM_MEMORY}"
    echo "  VM_CPU: ${VM_CPU}"
    echo "  VM_DISK_SIZE: ${VM_DISK_SIZE}"
    if [ -n "${VM_NETWORK_NAME:-}" ]; then
      echo "  VM_NETWORK_NAME: ${VM_NETWORK_NAME}"
    fi
    echo "  VM_STORAGE_POOL: ${VM_STORAGE_POOL}"
    echo "  VM_AUTOSTART: ${VM_AUTOSTART}"
    echo "  DOCKER_HOST: unix:///var/run/docker.sock"
  } > "${TEST_WINDSOR_YAML}"
fi

# Export environment variables
export INCUS_REMOTE_NAME="${TEST_REMOTE_NAME}"
export VM_INSTANCE_NAME="${VM_NAME}"
export VM_IMAGE="${VM_IMAGE}"
export VM_MEMORY="${VM_MEMORY}"
export VM_CPU="${VM_CPU}"
export VM_DISK_SIZE="${VM_DISK_SIZE}"
export VM_NETWORK_NAME="${VM_NETWORK_NAME:-}"
export VM_STORAGE_POOL="${VM_STORAGE_POOL}"
export VM_AUTOSTART="${VM_AUTOSTART}"
export VM_INIT_WORKSPACE="${VM_INIT_WORKSPACE}"

# Export VM_NAME for subsequent tasks
export VM_NAME="${VM_NAME}"

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
    echo "ℹ️  Using active Windsor context '${ACTIVE_CONTEXT}' (VM will be named '${VM_NAME}')"
    # If windsor.yaml exists in the context directory, the context is effectively initialized
    # Only check Windsor's context list if windsor.yaml doesn't exist
    if [ ! -f "${TEST_WINDSOR_YAML}" ]; then
      # windsor.yaml doesn't exist - check if context is registered with Windsor
      if ! windsor context list --format csv 2>/dev/null | grep -q "^${ACTIVE_CONTEXT},"; then
        echo "ℹ️  Initializing Windsor context '${ACTIVE_CONTEXT}'..."
        windsor init "${ACTIVE_CONTEXT}" > /dev/null 2>&1 || true
      fi
    fi
    # If windsor.yaml exists, context is valid regardless of Windsor's list
  else
    # No active context - check if context exists for VM name, or create one
    if windsor context list --format csv 2>/dev/null | grep -q "^${VM_NAME},"; then
      echo "ℹ️  Windsor context '${VM_NAME}' already exists, setting as active"
      windsor context set "${VM_NAME}" > /dev/null 2>&1 || true
    else
      echo "ℹ️  Initializing new Windsor context '${VM_NAME}'"
      windsor init "${VM_NAME}" > /dev/null 2>&1 || true
      windsor context set "${VM_NAME}" > /dev/null 2>&1 || true
    fi
  fi
fi

echo "✅ Windsor context initialized"
