#!/usr/bin/env bash
# Setup runner user with same SSH keys as the main user
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.runner-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

RUNNER_NAME="${RUNNER_NAME:-runner}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"
RUNNER_USER="${RUNNER_USER:-runner}"
RUNNER_HOME="/home/${RUNNER_USER}"

# Detect current user from host (the user who will SSH into the VM)
CURRENT_USER="${USER:-$(whoami)}"
CURRENT_UID="${UID:-$(id -u)}"
CURRENT_GID="${GID:-$(id -g)}"
CURRENT_HOME="${HOME:-$HOME}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Setup Runner User"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Creating user '${RUNNER_USER}' with same privileges as '${CURRENT_USER}'"

incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "
set -euo pipefail

# Check if runner user already exists
if id -u ${RUNNER_USER} >/dev/null 2>&1; then
  echo \"  User ${RUNNER_USER} already exists, updating...\"
else
  echo \"  Creating user ${RUNNER_USER}...\"
  # Create user with same UID/GID as host user (or use defaults)
  groupadd -g ${CURRENT_GID} ${RUNNER_USER} 2>/dev/null || true
  useradd -m -u ${CURRENT_UID} -g ${CURRENT_GID} -s /bin/bash ${RUNNER_USER} 2>/dev/null || \
    useradd -m -g ${CURRENT_GID} -s /bin/bash ${RUNNER_USER} 2>/dev/null || true
  echo \"✅ User ${RUNNER_USER} created\"
fi

# Add runner user to docker group (if Docker is installed)
if getent group docker >/dev/null 2>&1; then
  usermod -aG docker ${RUNNER_USER} 2>/dev/null || true
  echo \"  Added ${RUNNER_USER} to docker group\"
fi

# Add runner user to incus group (if Incus is installed)
if getent group incus >/dev/null 2>&1; then
  usermod -aG incus ${RUNNER_USER} 2>/dev/null || true
  echo \"  Added ${RUNNER_USER} to incus group\"
  
  # Ensure socket permissions are correct (if socket exists)
  if [ -S /var/lib/incus/unix.socket ]; then
    # Ensure incus group has read/write access to the socket
    chmod g+rw /var/lib/incus/unix.socket 2>/dev/null || true
    # Ensure socket directory is accessible
    if [ -d /var/lib/incus ]; then
      chmod g+rx /var/lib/incus 2>/dev/null || true
    fi
  fi
fi

# Add runner user to sudo group
usermod -aG sudo ${RUNNER_USER} 2>/dev/null || true

# Configure passwordless sudo for the runner user
SUDOERS_FILE=\"/etc/sudoers.d/${RUNNER_USER}\"
echo \"${RUNNER_USER} ALL=(ALL) NOPASSWD: ALL\" > \${SUDOERS_FILE}
chmod 0440 \${SUDOERS_FILE}
echo \"✅ Passwordless sudo configured for ${RUNNER_USER}\"

# Create .ssh directory
mkdir -p ${RUNNER_HOME}/.ssh
chmod 700 ${RUNNER_HOME}/.ssh
chown ${CURRENT_UID}:${CURRENT_GID} ${RUNNER_HOME}/.ssh 2>/dev/null || \
  chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}/.ssh

# Ensure home directory has correct permissions
chmod 755 ${RUNNER_HOME} 2>/dev/null || true
chown ${CURRENT_UID}:${CURRENT_GID} ${RUNNER_HOME} 2>/dev/null || \
  chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME} 2>/dev/null || true

# Create authorized_keys file
touch ${RUNNER_HOME}/.ssh/authorized_keys
chmod 600 ${RUNNER_HOME}/.ssh/authorized_keys
chown ${CURRENT_UID}:${CURRENT_GID} ${RUNNER_HOME}/.ssh/authorized_keys 2>/dev/null || \
  chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}/.ssh/authorized_keys
"

# Copy SSH keys from host to VM (same as setup-ssh.sh does for main user)
SSH_KEYS_COPIED=0
for key_type in rsa ed25519 ecdsa; do
  if [ -f "${CURRENT_HOME}/.ssh/id_${key_type}" ]; then
    echo "  Copying ${key_type} private key..."
    incus file push "${CURRENT_HOME}/.ssh/id_${key_type}" "${TEST_REMOTE_NAME}:${RUNNER_NAME}/tmp/id_${key_type}"
    incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "
      mv /tmp/id_${key_type} ${RUNNER_HOME}/.ssh/id_${key_type}
      chmod 600 ${RUNNER_HOME}/.ssh/id_${key_type}
      chown ${CURRENT_UID}:${CURRENT_GID} ${RUNNER_HOME}/.ssh/id_${key_type} 2>/dev/null || \
        chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}/.ssh/id_${key_type}
    "
    SSH_KEYS_COPIED=1
  fi
  if [ -f "${CURRENT_HOME}/.ssh/id_${key_type}.pub" ]; then
    echo "  Copying ${key_type} public key..."
    incus file push "${CURRENT_HOME}/.ssh/id_${key_type}.pub" "${TEST_REMOTE_NAME}:${RUNNER_NAME}/tmp/id_${key_type}.pub"
    incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "
      mv /tmp/id_${key_type}.pub ${RUNNER_HOME}/.ssh/id_${key_type}.pub
      chmod 644 ${RUNNER_HOME}/.ssh/id_${key_type}.pub
      chown ${CURRENT_UID}:${CURRENT_GID} ${RUNNER_HOME}/.ssh/id_${key_type}.pub 2>/dev/null || \
        chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}/.ssh/id_${key_type}.pub
    "
  fi
done

# Set up authorized_keys with all public keys
incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "
set -euo pipefail

# Clear existing authorized_keys and add all public keys
> ${RUNNER_HOME}/.ssh/authorized_keys

# Add all public keys to authorized_keys
for pubkey_file in ${RUNNER_HOME}/.ssh/*.pub; do
  if [ -f \"\${pubkey_file}\" ]; then
    PUBKEY=\$(cat \"\${pubkey_file}\")
    if ! grep -Fxq \"\${PUBKEY}\" ${RUNNER_HOME}/.ssh/authorized_keys 2>/dev/null; then
      echo \"\${PUBKEY}\" >> ${RUNNER_HOME}/.ssh/authorized_keys
    fi
  fi
done

# Ensure final permissions are correct
chmod 600 ${RUNNER_HOME}/.ssh/authorized_keys
chown ${CURRENT_UID}:${CURRENT_GID} ${RUNNER_HOME}/.ssh/authorized_keys 2>/dev/null || \
  chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}/.ssh/authorized_keys
chmod 700 ${RUNNER_HOME}/.ssh
chown ${CURRENT_UID}:${CURRENT_GID} ${RUNNER_HOME}/.ssh 2>/dev/null || \
  chown ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}/.ssh
"

if [ ${SSH_KEYS_COPIED} -eq 0 ]; then
  echo "⚠️  Warning: No SSH keys found in ${CURRENT_HOME}/.ssh/"
  echo "   You may need to add your SSH key manually:"
  echo "     incus exec ${TEST_REMOTE_NAME}:${RUNNER_NAME} -- bash -c 'echo \"<your-public-key>\" >> ${RUNNER_HOME}/.ssh/authorized_keys'"
else
  echo "✅ SSH keys copied to ${RUNNER_USER} user"
fi

# Get VM IP address for display
VM_IP=""
if command -v jq >/dev/null 2>&1; then
  VM_IP=$(incus list "${TEST_REMOTE_NAME}:${RUNNER_NAME}" --format json 2>/dev/null | \
    jq -r '.[0].state.network | to_entries[] | .value.addresses[]? | select(.family=="inet" and .address != "127.0.0.1") | .address' 2>/dev/null | \
    grep -E '^192\.168\.' | head -1 || echo "")
fi

if [ -z "${VM_IP}" ]; then
  VM_IP=$(incus list "${TEST_REMOTE_NAME}:${RUNNER_NAME}" --format csv -c n,IPv4 2>/dev/null | \
    grep "^${RUNNER_NAME}," | cut -d',' -f3 | awk '{print $1}' | \
    grep -E '^192\.168\.' | head -1 || echo "")
fi

# Configure Incus remote for runner user (if not local)
if [ "${TEST_REMOTE_NAME}" != "local" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Configure Incus Remote for Runner User"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Get Incus server IP (default to common IP or use environment variable)
  if [ -n "${INCUS_SERVER_IP:-}" ]; then
    INCUS_SERVER_IP="${INCUS_SERVER_IP}"
  elif [ -n "${INCUS_REMOTE_IP_0:-}" ]; then
    INCUS_SERVER_IP="${INCUS_REMOTE_IP_0}"
  else
    INCUS_SERVER_IP="192.168.2.101"
  fi
  
  INCUS_REMOTE_NAME="${TEST_REMOTE_NAME}"
  INCUS_REMOTE_URL="https://${INCUS_SERVER_IP}:8443"
  CLIENT_NAME="${RUNNER_NAME}-${RUNNER_USER}"
  
  echo "  Configuring remote '${INCUS_REMOTE_NAME}' for user '${RUNNER_USER}'..."
  echo "  Server IP: ${INCUS_SERVER_IP}"
  echo "  Remote URL: ${INCUS_REMOTE_URL}"
  
  # Generate trust token on server
  echo "  Generating trust token on server..."
  set +e
  TRUST_OUTPUT=$(incus config trust add "${CLIENT_NAME}" --remote "${INCUS_REMOTE_NAME}" 2>&1 || \
                 incus config trust add "${CLIENT_NAME}" 2>&1 || echo "")
  TRUST_TOKEN=$(echo "${TRUST_OUTPUT}" | awk '/token:/ {getline; print}' | head -1 | tr -d '[:space:]' || echo "")
  if [ -z "${TRUST_TOKEN}" ] || [ ${#TRUST_TOKEN} -lt 64 ]; then
    TRUST_TOKEN=$(echo "${TRUST_OUTPUT}" | grep -oE '[a-zA-Z0-9_-]{64,}' | head -1 || echo "")
  fi
  set -e
  
  if [ -n "${TRUST_TOKEN}" ] && [ ${#TRUST_TOKEN} -ge 64 ]; then
    echo "  ✅ Trust token generated"
    
    # Escape the trust token for safe passing to the VM
    TRUST_TOKEN_ESCAPED=$(printf '%s\n' "${TRUST_TOKEN}" | sed "s/'/'\\\\''/g")
    
    # Configure remote for runner user
    incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- bash -c "
      set -euo pipefail
      
      INCUS_REMOTE_NAME=\"${INCUS_REMOTE_NAME}\"
      INCUS_REMOTE_URL=\"${INCUS_REMOTE_URL}\"
      TRUST_TOKEN=\"${TRUST_TOKEN_ESCAPED}\"
      RUNNER_USER=\"${RUNNER_USER}\"
      RUNNER_HOME=\"/home/\${RUNNER_USER}\"
      
      # Get runner user's primary GID
      RUNNER_GID=\$(id -g \${RUNNER_USER} 2>/dev/null || echo \"\")
      
      # Ensure runner user owns their home directory and has correct permissions
      if [ -n \"\${RUNNER_GID}\" ]; then
        chown -R \${RUNNER_USER}:\${RUNNER_GID} \${RUNNER_HOME} 2>/dev/null || \
        chown -R \${RUNNER_USER} \${RUNNER_HOME} 2>/dev/null || true
      else
        chown -R \${RUNNER_USER} \${RUNNER_HOME} 2>/dev/null || true
      fi
      chmod 755 \${RUNNER_HOME} 2>/dev/null || true
      
      # Create .config directory if it doesn't exist
      if [ ! -d \${RUNNER_HOME}/.config ]; then
        mkdir -p \${RUNNER_HOME}/.config
        if [ -n \"\${RUNNER_GID}\" ]; then
          chown \${RUNNER_USER}:\${RUNNER_GID} \${RUNNER_HOME}/.config 2>/dev/null || \
          chown \${RUNNER_USER} \${RUNNER_HOME}/.config 2>/dev/null || true
        else
          chown \${RUNNER_USER} \${RUNNER_HOME}/.config 2>/dev/null || true
        fi
        chmod 755 \${RUNNER_HOME}/.config
      fi
      
      # Check if remote already exists
      REMOTE_EXISTS=false
      if sudo -u \${RUNNER_USER} incus remote list --format csv 2>/dev/null | awk -F',' '{print \$1}' | sed 's/ (current)//' | grep -qE \"^\${INCUS_REMOTE_NAME}\$\"; then
        REMOTE_EXISTS=true
      elif sudo -u \${RUNNER_USER} incus remote list 2>/dev/null | grep -qE \"^\\| \${INCUS_REMOTE_NAME} +\\|\"; then
        REMOTE_EXISTS=true
      fi
      
      if [ \"\${REMOTE_EXISTS}\" = \"true\" ]; then
        echo \"  Remote \${INCUS_REMOTE_NAME} already exists for \${RUNNER_USER}\"
        # Verify connection
        if sudo -u \${RUNNER_USER} incus list \${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
          echo \"  ✅ Remote is working correctly\"
        else
          echo \"  ⚠️  Remote exists but connection failed, removing to reconfigure...\"
          sudo -u \${RUNNER_USER} incus remote remove \${INCUS_REMOTE_NAME} 2>/dev/null || true
          REMOTE_EXISTS=false
        fi
      fi
      
      if [ \"\${REMOTE_EXISTS}\" = \"false\" ]; then
        echo \"  Adding remote \${INCUS_REMOTE_NAME}...\"
        
        # Try to add remote with trust token (non-interactive)
        set +e
        ADD_OUTPUT=\$(echo \"\${TRUST_TOKEN}\" | sudo -u \${RUNNER_USER} incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL} --token - 2>&1)
        ADD_RESULT=\$?
        set -e
        
        # Check if we need to accept certificate fingerprint
        if [ \${ADD_RESULT} -ne 0 ] || echo \"\${ADD_OUTPUT}\" | grep -q \"fingerprint\\|ok (y/n\"; then
          # Extract fingerprint from output
          FINGERPRINT=\$(echo \"\${ADD_OUTPUT}\" | grep -oE '[a-f0-9]{64}' | head -1 || echo \"\")
          
          if [ -n \"\${FINGERPRINT}\" ]; then
            echo \"  Accepting certificate fingerprint: \${FINGERPRINT}\"
            # Use the fingerprint to accept the certificate non-interactively
            set +e
            echo \"\${FINGERPRINT}\" | sudo -u \${RUNNER_USER} incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL} --token \"\${TRUST_TOKEN}\" 2>&1
            ADD_RESULT=\$?
            set -e
          fi
        fi
        
        # Verify remote was added
        if [ \${ADD_RESULT} -eq 0 ]; then
          # Double-check it's actually in the list
          if sudo -u \${RUNNER_USER} incus remote list --format csv 2>/dev/null | awk -F',' '{print \$1}' | sed 's/ (current)//' | grep -qE \"^\${INCUS_REMOTE_NAME}\$\"; then
            echo \"  ✅ Remote \${INCUS_REMOTE_NAME} added successfully\"
          else
            echo \"  ⚠️  Warning: Command succeeded but remote not found in list\"
          fi
        else
          # Check if it's because remote already exists
          if echo \"\${ADD_OUTPUT}\" | grep -q \"already exists\\|Remote.*exists\"; then
            if sudo -u \${RUNNER_USER} incus list \${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
              echo \"  ✅ Remote \${INCUS_REMOTE_NAME} already exists and is working\"
            else
              echo \"  ⚠️  Warning: Remote exists but connection failed\"
            fi
          else
            echo \"  ⚠️  Warning: Failed to add remote\"
            echo \"     Error: \${ADD_OUTPUT}\"
            echo \"     You may need to add it manually:\"
            echo \"       sudo -u \${RUNNER_USER} incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL}\"
          fi
        fi
      fi
      
      # Set as default remote
      echo \"  Setting \${INCUS_REMOTE_NAME} as default remote...\"
      sudo -u \${RUNNER_USER} incus remote switch \${INCUS_REMOTE_NAME} 2>/dev/null || true
      echo \"  ✅ Remote configuration complete\"
    "
  else
    echo "  ⚠️  Warning: Could not generate trust token automatically"
    echo "     The remote may need to be configured manually for the runner user"
    echo "     To fix:"
    echo "       1. Generate token on server: incus config trust add ${CLIENT_NAME}"
    echo "       2. Add remote from VM: sudo -u ${RUNNER_USER} incus remote add ${INCUS_REMOTE_NAME} ${INCUS_REMOTE_URL}"
  fi
fi

if [ -n "${VM_IP}" ]; then
  echo "✅ Runner user setup complete"
  echo "   You can now SSH into the VM as ${RUNNER_USER}:"
  echo "     ssh ${RUNNER_USER}@${VM_IP}"
else
  echo "✅ Runner user setup complete"
  echo "   (VM IP address not yet available)"
fi

