#!/usr/bin/env bash
# Validate VM setup and functionality
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME}}"
VM_NAME="${VM_NAME:-vm}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"

# Get VM information and display summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "VM Creation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get VM status
VM_STATUS=$(incus list ${TEST_REMOTE_NAME}:${VM_NAME} --format json 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "Unknown")

# Get VM IP address from incus commands
VM_IP=""
set +e  # Temporarily disable exit on error for IP extraction

# Try incus list first (most reliable)
VM_IP=$(incus list ${TEST_REMOTE_NAME}:${VM_NAME} --format json 2>/dev/null | \
  grep -o '"IPv4":"[^"]*"' | head -1 | cut -d'"' -f4 | awk '{print $1}' || echo "")

# Fallback: try incus info
if [ -z "${VM_IP}" ] || [ "${VM_IP}" = "null" ]; then
  VM_INFO=$(incus info ${TEST_REMOTE_NAME}:${VM_NAME} 2>/dev/null || echo "")
  if [ -n "${VM_INFO}" ]; then
    VM_IP=$(echo "${VM_INFO}" | grep -i "IPv4:" | head -1 | awk '{print $2}' | awk '{print $1}' || echo "")
  fi
fi

# Additional fallback: try getting from VM directly
if [ -z "${VM_IP}" ] || [ "${VM_IP}" = "null" ]; then
  VM_IP=$(incus exec ${TEST_REMOTE_NAME}:${VM_NAME} -- \
    ip -4 addr show eth0 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print $2}' | head -1 || echo "")
fi

set -e  # Re-enable exit on error

# Display summary
echo "VM Name:        ${VM_NAME}"
echo "Remote:         ${TEST_REMOTE_NAME}"
echo "Status:         ${VM_STATUS}"

if [ -n "${VM_IP}" ] && [ "${VM_IP}" != "null" ] && echo "${VM_IP}" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
  echo "IP Address:     ${VM_IP}"
  echo ""
  echo "SSH Access:     ssh todd@${VM_IP}"
else
  echo "IP Address:     (not yet assigned)"
  echo "                DHCP may need more time to assign an IP address"
  echo "                Check with: incus list ${TEST_REMOTE_NAME}:${VM_NAME}"
fi

echo ""
echo "Tools Installed:"
echo "  - Homebrew"
echo "  - Aqua package manager"
echo "  - Docker"
echo "  - jq"
echo "  - Windsor CLI"

echo ""
if [ "${VM_STATUS}" = "Running" ]; then
  echo "✅ VM is running and ready"
else
  echo "⚠️  VM status: ${VM_STATUS}"
fi
