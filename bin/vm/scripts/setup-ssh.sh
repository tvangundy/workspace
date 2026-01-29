#!/usr/bin/env bash
# Setup SSH access for the user on the VM
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

# Wait for VM agent to be ready before running commands
echo "  Waiting for VM agent to be ready..."
MAX_RETRIES=24
RETRY_COUNT=0
while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
  if incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- true 2>/dev/null; then
    echo "  VM agent is ready"
    break
  fi
  # Check if we should print progress (every 3 attempts)
  MOD_CHECK=$(echo "${RETRY_COUNT}" | awk '{print $1 % 3}')
  if [ "${MOD_CHECK}" = "0" ]; then
    ELAPSED=$(echo "${RETRY_COUNT}" | awk '{print $1 * 5}')
    echo "    Waiting for VM agent... [${RETRY_COUNT}/${MAX_RETRIES} attempts, ~${ELAPSED}s elapsed]"
  fi
  sleep 5
  RETRY_COUNT=$(echo "${RETRY_COUNT}" | awk '{print $1 + 1}')
done

if [ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]; then
  TIMEOUT_SEC=$(echo "${MAX_RETRIES}" | awk '{print $1 * 5}')
  echo "⚠️  Error: VM agent not ready after ${TIMEOUT_SEC} seconds"
  echo "   The VM may still be booting. You can try running this step manually later."
  exit 1
fi

# Detect current user from host
CURRENT_USER="${USER:-$(whoami)}"
CURRENT_UID="${UID:-$(id -u)}"
CURRENT_GID="${GID:-$(id -g)}"
CURRENT_HOME="${HOME:-$HOME}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Setup SSH Access"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  User: ${CURRENT_USER} (UID: ${CURRENT_UID}, GID: ${CURRENT_GID})"

incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
set -euo pipefail

# Install OpenSSH server if not already installed
if ! command -v sshd >/dev/null 2>&1; then
  echo '  Installing OpenSSH server...'
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq || {
    echo '⚠️  Warning: apt-get update failed, continuing anyway...'
  }
  apt-get install -y -qq openssh-server || {
    echo '⚠️  Error: Failed to install OpenSSH server'
    echo '   This may be a temporary network or repository issue'
    echo '   The VM will continue, but SSH may need to be installed manually'
    exit 1
  }
  echo '✅ OpenSSH server installed'
else
  echo '✅ OpenSSH server already installed'
fi

# Create user if it doesn't exist (with same UID/GID as host)
if ! id -u ${CURRENT_USER} >/dev/null 2>&1; then
  echo \"  Creating user ${CURRENT_USER}...\"
  # Create user with same UID/GID as host
  groupadd -g ${CURRENT_GID} ${CURRENT_USER} 2>/dev/null || true
  useradd -m -u ${CURRENT_UID} -g ${CURRENT_GID} -s /bin/bash ${CURRENT_USER} 2>/dev/null || \
    useradd -m -g ${CURRENT_GID} -s /bin/bash ${CURRENT_USER} 2>/dev/null || true
  echo \"✅ User ${CURRENT_USER} created\"
else
  echo \"✅ User ${CURRENT_USER} already exists\"
fi

# Configure passwordless sudo for the user
echo \"  Configuring passwordless sudo for ${CURRENT_USER}...\"
# Check if sudo is installed
if ! command -v sudo >/dev/null 2>&1; then
  apt-get install -y -qq sudo >/dev/null 2>&1 || true
fi

# Add user to sudo group if not already a member
usermod -aG sudo ${CURRENT_USER} 2>/dev/null || true

# Configure passwordless sudo in sudoers.d (more secure than editing main sudoers)
SUDOERS_FILE=\"/etc/sudoers.d/${CURRENT_USER}\"
echo \"${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL\" > \${SUDOERS_FILE}
chmod 0440 \${SUDOERS_FILE}
echo \"✅ Passwordless sudo configured for ${CURRENT_USER}\"

# Create .ssh directory
mkdir -p /home/${CURRENT_USER}/.ssh
chmod 700 /home/${CURRENT_USER}/.ssh
chown ${CURRENT_UID}:${CURRENT_GID} /home/${CURRENT_USER}/.ssh 2>/dev/null || \
  chown ${CURRENT_USER}:${CURRENT_USER} /home/${CURRENT_USER}/.ssh

# Ensure home directory has correct permissions
chmod 755 /home/${CURRENT_USER} 2>/dev/null || true
chown ${CURRENT_UID}:${CURRENT_GID} /home/${CURRENT_USER} 2>/dev/null || \
  chown ${CURRENT_USER}:${CURRENT_USER} /home/${CURRENT_USER} 2>/dev/null || true

# Create authorized_keys file
touch /home/${CURRENT_USER}/.ssh/authorized_keys
chmod 600 /home/${CURRENT_USER}/.ssh/authorized_keys
chown ${CURRENT_UID}:${CURRENT_GID} /home/${CURRENT_USER}/.ssh/authorized_keys 2>/dev/null || \
  chown ${CURRENT_USER}:${CURRENT_USER} /home/${CURRENT_USER}/.ssh/authorized_keys
"

# Copy SSH keys from host to VM
SSH_KEYS_COPIED=0
for key_type in rsa ed25519 ecdsa; do
  if [ -f "${CURRENT_HOME}/.ssh/id_${key_type}" ]; then
    echo "  Copying ${key_type} private key..."
    incus file push "${CURRENT_HOME}/.ssh/id_${key_type}" "${TEST_REMOTE_NAME}:${VM_NAME}/tmp/id_${key_type}"
    incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
      mv /tmp/id_${key_type} /home/${CURRENT_USER}/.ssh/id_${key_type}
      chmod 600 /home/${CURRENT_USER}/.ssh/id_${key_type}
      chown ${CURRENT_UID}:${CURRENT_GID} /home/${CURRENT_USER}/.ssh/id_${key_type} 2>/dev/null || \
        chown ${CURRENT_USER}:${CURRENT_USER} /home/${CURRENT_USER}/.ssh/id_${key_type}
    "
    SSH_KEYS_COPIED=1
  fi
  if [ -f "${CURRENT_HOME}/.ssh/id_${key_type}.pub" ]; then
    echo "  Copying ${key_type} public key..."
    incus file push "${CURRENT_HOME}/.ssh/id_${key_type}.pub" "${TEST_REMOTE_NAME}:${VM_NAME}/tmp/id_${key_type}.pub"
    incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
      mv /tmp/id_${key_type}.pub /home/${CURRENT_USER}/.ssh/id_${key_type}.pub
      chmod 644 /home/${CURRENT_USER}/.ssh/id_${key_type}.pub
      chown ${CURRENT_UID}:${CURRENT_GID} /home/${CURRENT_USER}/.ssh/id_${key_type}.pub 2>/dev/null || \
        chown ${CURRENT_USER}:${CURRENT_USER} /home/${CURRENT_USER}/.ssh/id_${key_type}.pub
    "
  fi
done

# Set up authorized_keys with all public keys
incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
set -euo pipefail

# Clear existing authorized_keys and add all public keys
> /home/${CURRENT_USER}/.ssh/authorized_keys

# Add all public keys to authorized_keys
for pubkey_file in /home/${CURRENT_USER}/.ssh/*.pub; do
  if [ -f \"\${pubkey_file}\" ]; then
    PUBKEY=\$(cat \"\${pubkey_file}\")
    if ! grep -Fxq \"\${PUBKEY}\" /home/${CURRENT_USER}/.ssh/authorized_keys 2>/dev/null; then
      echo \"\${PUBKEY}\" >> /home/${CURRENT_USER}/.ssh/authorized_keys
    fi
  fi
done

# Ensure final permissions are correct
chmod 600 /home/${CURRENT_USER}/.ssh/authorized_keys
chown ${CURRENT_UID}:${CURRENT_GID} /home/${CURRENT_USER}/.ssh/authorized_keys 2>/dev/null || \
  chown ${CURRENT_USER}:${CURRENT_USER} /home/${CURRENT_USER}/.ssh/authorized_keys
chmod 700 /home/${CURRENT_USER}/.ssh
chown ${CURRENT_UID}:${CURRENT_GID} /home/${CURRENT_USER}/.ssh 2>/dev/null || \
  chown ${CURRENT_USER}:${CURRENT_USER} /home/${CURRENT_USER}/.ssh
"

# Configure SSH server
incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
set -euo pipefail

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
  echo '  Generating SSH host keys...'
  ssh-keygen -A > /dev/null 2>&1
fi

# Configure SSH server for public key authentication
if [ -f /etc/ssh/sshd_config ]; then
  # Backup original config
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
  
  # Configure SSH for public key authentication
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || true
  sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config 2>/dev/null || true
  sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null || true
  
  # Ensure these settings are present (add if not found)
  grep -q '^PasswordAuthentication' /etc/ssh/sshd_config || echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
  grep -q '^PubkeyAuthentication' /etc/ssh/sshd_config || echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
  grep -q '^ChallengeResponseAuthentication' /etc/ssh/sshd_config || echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config
  
  echo '✅ SSH server configured'
fi

# Enable and start SSH service
systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

echo '✅ SSH service enabled and started'
"

if [ ${SSH_KEYS_COPIED} -eq 0 ]; then
  echo "⚠️  Warning: No SSH keys found in ${CURRENT_HOME}/.ssh/"
  echo "   You may need to add your SSH key manually:"
  echo "     incus exec ${TEST_REMOTE_NAME}:${VM_NAME} -- bash -c 'echo \"<your-public-key>\" >> /home/${CURRENT_USER}/.ssh/authorized_keys'"
fi

# Function to ensure physical network is configured
ensure_physical_network() {
  local iface=""
  local has_instances_role=false
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Ensure Physical Network Configuration"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
  
  # Export the network name for use in IP detection
  export VM_NETWORK_NAME="${iface}"
  echo "    ✓ Physical network configuration complete"
  echo ""
}

# Ensure physical network is configured before waiting for IP
ensure_physical_network

# Wait for VM IP address to be available using incus list
set +e  # Temporarily disable exit on error for IP extraction
VM_IP=""
MAX_WAIT=120  # Increased timeout since we're waiting for 192.168.2.x specifically
ELAPSED=0

echo "  Waiting for VM IP address (192.168.2.x)..."

while [ ${ELAPSED} -lt ${MAX_WAIT} ] && [ -z "${VM_IP}" ]; do
  VM_IP=""
  
  # Method 1: JSON format with jq (preferred - most reliable)
  if command -v jq >/dev/null 2>&1; then
    # Physical network: only accept 192.168.2.x addresses, exclude Docker and bridge networks
    VM_IP_JSON=$(incus list "${TEST_REMOTE_NAME}:${VM_NAME}" --format json 2>/dev/null | \
      jq -r '.[0].state.network | to_entries[] | .value.addresses[]? | select(.family=="inet" and .address != "127.0.0.1") | .address' 2>/dev/null | \
      grep -E '^192\.168\.' | head -1 || echo "")
    if [ -n "${VM_IP_JSON}" ] && [ "${VM_IP_JSON}" != "null" ] && [ "${VM_IP_JSON}" != "" ]; then
      VM_IP="${VM_IP_JSON}"
    fi
  fi
  
  # Method 2: CSV format (fallback if jq is not available or JSON failed)
  if [ -z "${VM_IP}" ]; then
    # Extract IP from CSV format: "vm,RUNNING,192.168.2.144 (enp5s0),..."
    # Physical network: only accept 192.168.2.x addresses
    VM_IP_CSV=$(incus list "${TEST_REMOTE_NAME}:${VM_NAME}" --format csv -c n,IPv4 2>/dev/null | \
      grep "^${VM_NAME}," | cut -d',' -f3 | awk '{print $1}' | \
      grep -E '^192\.168\.' | head -1 || echo "")
    if [ -n "${VM_IP_CSV}" ] && [ "${VM_IP_CSV}" != "-" ] && [ "${VM_IP_CSV}" != "" ]; then
      VM_IP="${VM_IP_CSV}"
    fi
  fi
  
  # Method 3: Simple grep from table format (last resort)
  if [ -z "${VM_IP}" ]; then
    # Physical network: only accept 192.168.2.x addresses
    VM_IP_TABLE=$(incus list "${TEST_REMOTE_NAME}:${VM_NAME}" 2>/dev/null | \
      grep "${VM_NAME}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
      grep -E '^192\.168\.' | head -1 || echo "")
    if [ -n "${VM_IP_TABLE}" ]; then
      VM_IP="${VM_IP_TABLE}"
    fi
  fi
  
  # Validate IP address format
  if [ -n "${VM_IP}" ] && echo "${VM_IP}" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    break
  fi
  
  VM_IP=""
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [ $((ELAPSED % 10)) -eq 0 ]; then
    echo "    Still waiting for IP address... [${ELAPSED}s elapsed]"
  fi
done

set -e  # Re-enable exit on error

echo ""
if [ -z "${VM_IP}" ] || [ "${VM_IP}" = "-" ]; then
  echo "❌ Error: VM did not receive a 192.168.2.x IP address within ${MAX_WAIT} seconds"
  echo ""
  echo "   This usually means:"
  echo "   1. The physical network is not properly configured"
  echo "   2. The VM needs to be restarted to pick up the new network configuration"
  echo "   3. DHCP server is not responding"
  echo ""
  echo "   To troubleshoot:"
  echo "   - Check network config: task incus:check-network-config"
  echo "   - Check VM status: incus list ${TEST_REMOTE_NAME}:${VM_NAME}"
  echo "   - Restart VM: incus restart ${TEST_REMOTE_NAME}:${VM_NAME}"
  echo ""
  exit 1
fi

echo "✅ SSH setup complete"
echo "   VM IP address: ${VM_IP}"
echo "   You can now SSH into the VM:"
echo "     ssh ${CURRENT_USER}@${VM_IP}"
