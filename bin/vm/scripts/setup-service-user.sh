#!/usr/bin/env bash
# Setup a service user (e.g. mailu) with same SSH keys and privileges as runner user setup, no GitHub runner install.
# Uses VM_SERVICE_USER from .vm-instantiate.env (set by --mailu flag; default: mailu).
set -euo pipefail

# Windsor context first, then shared session file (.vm-instantiate.env)
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
if command -v windsor >/dev/null 2>&1; then eval "$(windsor env --decrypt 2>/dev/null)" || true; fi
ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then source "${ENV_FILE}"; fi

INCUS_REMOTE_NAME="${INCUS_REMOTE_NAME:-${TEST_REMOTE_NAME}}"
INCUS_REMOTE_IP="${INCUS_REMOTE_IP:-}"
VM_INSTANCE_NAME="${VM_INSTANCE_NAME:-${VM_NAME:-vm}}"
SERVICE_USER="${VM_SERVICE_USER:-mailu}"
SERVICE_HOME="/home/${SERVICE_USER}"

# Detect current user from host (the user who will SSH into the VM)
CURRENT_USER="${USER:-$(whoami)}"
CURRENT_UID="${UID:-$(id -u)}"
CURRENT_GID="${GID:-$(id -g)}"
CURRENT_HOME="${HOME:-$HOME}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Setup Service User (${SERVICE_USER})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Creating user '${SERVICE_USER}' with same privileges as '${CURRENT_USER}'"

incus exec "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}" -- bash -c "
set -euo pipefail

# Check if service user already exists
if id -u ${SERVICE_USER} >/dev/null 2>&1; then
  echo \"  User ${SERVICE_USER} already exists, updating...\"
else
  echo \"  Creating user ${SERVICE_USER}...\"
  # Create user with same UID/GID as host user (or use defaults)
  groupadd -g ${CURRENT_GID} ${SERVICE_USER} 2>/dev/null || true
  useradd -m -u ${CURRENT_UID} -g ${CURRENT_GID} -s /bin/bash ${SERVICE_USER} 2>/dev/null || \
    useradd -m -g ${CURRENT_GID} -s /bin/bash ${SERVICE_USER} 2>/dev/null || true
  echo \"✅ User ${SERVICE_USER} created\"
fi

# Add service user to docker group (if Docker is installed)
if getent group docker >/dev/null 2>&1; then
  usermod -aG docker ${SERVICE_USER} 2>/dev/null || true
  echo \"  Added ${SERVICE_USER} to docker group\"
fi

# Add service user to incus group (if Incus is installed)
if getent group incus >/dev/null 2>&1; then
  usermod -aG incus ${SERVICE_USER} 2>/dev/null || true
  echo \"  Added ${SERVICE_USER} to incus group\"
  
  # Ensure socket permissions are correct (if socket exists)
  if [ -S /var/lib/incus/unix.socket ]; then
    chmod g+rw /var/lib/incus/unix.socket 2>/dev/null || true
    if [ -d /var/lib/incus ]; then
      chmod g+rx /var/lib/incus 2>/dev/null || true
    fi
  fi
fi

# Add service user to sudo group
usermod -aG sudo ${SERVICE_USER} 2>/dev/null || true

# Configure passwordless sudo for the service user
SUDOERS_FILE=\"/etc/sudoers.d/${SERVICE_USER}\"
echo \"${SERVICE_USER} ALL=(ALL) NOPASSWD: ALL\" > \${SUDOERS_FILE}
chmod 0440 \${SUDOERS_FILE}
echo \"✅ Passwordless sudo configured for ${SERVICE_USER}\"

# Create .ssh directory
mkdir -p ${SERVICE_HOME}/.ssh
chmod 700 ${SERVICE_HOME}/.ssh
chown ${CURRENT_UID}:${CURRENT_GID} ${SERVICE_HOME}/.ssh 2>/dev/null || \
  chown ${SERVICE_USER}:${SERVICE_USER} ${SERVICE_HOME}/.ssh

# Ensure home directory has correct permissions
chmod 755 ${SERVICE_HOME} 2>/dev/null || true
chown ${CURRENT_UID}:${CURRENT_GID} ${SERVICE_HOME} 2>/dev/null || \
  chown ${SERVICE_USER}:${SERVICE_USER} ${SERVICE_HOME} 2>/dev/null || true

# Create authorized_keys file
touch ${SERVICE_HOME}/.ssh/authorized_keys
chmod 600 ${SERVICE_HOME}/.ssh/authorized_keys
chown ${CURRENT_UID}:${CURRENT_GID} ${SERVICE_HOME}/.ssh/authorized_keys 2>/dev/null || \
  chown ${SERVICE_USER}:${SERVICE_USER} ${SERVICE_HOME}/.ssh/authorized_keys
"

# Copy SSH keys from host to VM (same as setup-ssh.sh does for main user)
SSH_KEYS_COPIED=0
for key_type in rsa ed25519 ecdsa; do
  if [ -f "${CURRENT_HOME}/.ssh/id_${key_type}" ]; then
    echo "  Copying ${key_type} private key..."
    incus file push "${CURRENT_HOME}/.ssh/id_${key_type}" "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}/tmp/id_${key_type}"
    incus exec "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}" -- bash -c "
      mv /tmp/id_${key_type} ${SERVICE_HOME}/.ssh/id_${key_type}
      chmod 600 ${SERVICE_HOME}/.ssh/id_${key_type}
      chown ${CURRENT_UID}:${CURRENT_GID} ${SERVICE_HOME}/.ssh/id_${key_type} 2>/dev/null || \
        chown ${SERVICE_USER}:${SERVICE_USER} ${SERVICE_HOME}/.ssh/id_${key_type}
    "
    SSH_KEYS_COPIED=1
  fi
  if [ -f "${CURRENT_HOME}/.ssh/id_${key_type}.pub" ]; then
    echo "  Copying ${key_type} public key..."
    incus file push "${CURRENT_HOME}/.ssh/id_${key_type}.pub" "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}/tmp/id_${key_type}.pub"
    incus exec "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}" -- bash -c "
      mv /tmp/id_${key_type}.pub ${SERVICE_HOME}/.ssh/id_${key_type}.pub
      chmod 644 ${SERVICE_HOME}/.ssh/id_${key_type}.pub
      chown ${CURRENT_UID}:${CURRENT_GID} ${SERVICE_HOME}/.ssh/id_${key_type}.pub 2>/dev/null || \
        chown ${SERVICE_USER}:${SERVICE_USER} ${SERVICE_HOME}/.ssh/id_${key_type}.pub
    "
  fi
done

# Set up authorized_keys with all public keys
incus exec "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}" -- bash -c "
set -euo pipefail

# Clear existing authorized_keys and add all public keys
> ${SERVICE_HOME}/.ssh/authorized_keys

# Add all public keys to authorized_keys
for pubkey_file in ${SERVICE_HOME}/.ssh/*.pub; do
  if [ -f \"\${pubkey_file}\" ]; then
    PUBKEY=\$(cat \"\${pubkey_file}\")
    if ! grep -Fxq \"\${PUBKEY}\" ${SERVICE_HOME}/.ssh/authorized_keys 2>/dev/null; then
      echo \"\${PUBKEY}\" >> ${SERVICE_HOME}/.ssh/authorized_keys
    fi
  fi
done

# Ensure final permissions are correct
chmod 600 ${SERVICE_HOME}/.ssh/authorized_keys
chown ${CURRENT_UID}:${CURRENT_GID} ${SERVICE_HOME}/.ssh/authorized_keys 2>/dev/null || \
  chown ${SERVICE_USER}:${SERVICE_USER} ${SERVICE_HOME}/.ssh/authorized_keys
chmod 700 ${SERVICE_HOME}/.ssh
chown ${CURRENT_UID}:${CURRENT_GID} ${SERVICE_HOME}/.ssh 2>/dev/null || \
  chown ${SERVICE_USER}:${SERVICE_USER} ${SERVICE_HOME}/.ssh
"

if [ ${SSH_KEYS_COPIED} -eq 0 ]; then
  echo "⚠️  Warning: No SSH keys found in ${CURRENT_HOME}/.ssh/"
  echo "   You may need to add your SSH key manually:"
  echo "     incus exec ${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME} -- bash -c 'echo \"<your-public-key>\" >> ${SERVICE_HOME}/.ssh/authorized_keys'"
else
  echo "✅ SSH keys copied to ${SERVICE_USER} user"
fi

# Get VM IP address for display
VM_IP=""
if command -v jq >/dev/null 2>&1; then
  VM_IP=$(incus list "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}" --format json 2>/dev/null | \
    jq -r '.[0].state.network | to_entries[] | .value.addresses[]? | select(.family=="inet" and .address != "127.0.0.1") | .address' 2>/dev/null | \
    grep -E '^192\.168\.' | head -1 || echo "")
fi

if [ -z "${VM_IP}" ]; then
  VM_IP=$(incus list "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}" --format csv -c n,IPv4 2>/dev/null | \
    grep "^${VM_INSTANCE_NAME}," | cut -d',' -f3 | awk '{print $1}' | \
    grep -E '^192\.168\.' | head -1 || echo "")
fi

# Configure Incus remote for service user (if not local)
if [ "${INCUS_REMOTE_NAME}" != "local" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Configure Incus Remote for Service User (${SERVICE_USER})"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [ -z "${INCUS_REMOTE_IP}" ]; then
    echo "Error: INCUS_REMOTE_IP is required to configure the Incus remote for the service user." >&2
    exit 1
  fi
  INCUS_REMOTE_URL="https://${INCUS_REMOTE_IP}:8443"
  CLIENT_NAME="${VM_INSTANCE_NAME}-${SERVICE_USER}"
  
  echo "  Configuring remote '${INCUS_REMOTE_NAME}' for user '${SERVICE_USER}'..."
  echo "  Remote IP: ${INCUS_REMOTE_IP}"
  echo "  Remote URL: ${INCUS_REMOTE_URL}"
  
  echo "  Generating trust token on server..."
  PREV_REMOTE=""
  set +e
  if incus remote list --format csv -c n 2>/dev/null | grep -q "^${INCUS_REMOTE_NAME}$"; then
    PREV_REMOTE=$(incus remote get-default 2>/dev/null || echo "")
    incus remote switch "${INCUS_REMOTE_NAME}" 2>/dev/null || true
  fi
  TRUST_OUTPUT=$(incus config trust add "${CLIENT_NAME}" 2>&1 || echo "")
  if [ -n "${PREV_REMOTE}" ] && [ "${PREV_REMOTE}" != "${INCUS_REMOTE_NAME}" ]; then
    incus remote switch "${PREV_REMOTE}" 2>/dev/null || true
  fi
  TRUST_TOKEN=$(echo "${TRUST_OUTPUT}" | awk '/token:/ {getline; print}' | head -1 | tr -d '[:space:]' || echo "")
  if [ -z "${TRUST_TOKEN}" ] || [ ${#TRUST_TOKEN} -lt 64 ]; then
    TRUST_TOKEN=$(echo "${TRUST_OUTPUT}" | grep -oE '[a-zA-Z0-9_-]{64,}' | head -1 || echo "")
  fi
  set -e
  
  if [ -n "${TRUST_TOKEN}" ] && [ ${#TRUST_TOKEN} -ge 64 ]; then
    echo "  ✅ Trust token generated"
    
    TRUST_TOKEN_ESCAPED=$(printf '%s\n' "${TRUST_TOKEN}" | sed "s/'/'\\\\''/g")
    
    incus exec "${INCUS_REMOTE_NAME}:${VM_INSTANCE_NAME}" -- bash -c "
      set -euo pipefail
      
      INCUS_REMOTE_NAME=\"${INCUS_REMOTE_NAME}\"
      INCUS_REMOTE_URL=\"${INCUS_REMOTE_URL}\"
      TRUST_TOKEN=\"${TRUST_TOKEN_ESCAPED}\"
      SERVICE_USER=\"${SERVICE_USER}\"
      SERVICE_HOME=\"/home/\${SERVICE_USER}\"
      
      SERVICE_GID=\$(id -g \${SERVICE_USER} 2>/dev/null || echo \"\")
      
      if [ -n \"\${SERVICE_GID}\" ]; then
        chown -R \${SERVICE_USER}:\${SERVICE_GID} \${SERVICE_HOME} 2>/dev/null || \
        chown -R \${SERVICE_USER} \${SERVICE_HOME} 2>/dev/null || true
      else
        chown -R \${SERVICE_USER} \${SERVICE_HOME} 2>/dev/null || true
      fi
      chmod 755 \${SERVICE_HOME} 2>/dev/null || true
      
      if [ ! -d \${SERVICE_HOME}/.config ]; then
        mkdir -p \${SERVICE_HOME}/.config
        if [ -n \"\${SERVICE_GID}\" ]; then
          chown \${SERVICE_USER}:\${SERVICE_GID} \${SERVICE_HOME}/.config 2>/dev/null || \
          chown \${SERVICE_USER} \${SERVICE_HOME}/.config 2>/dev/null || true
        else
          chown \${SERVICE_USER} \${SERVICE_HOME}/.config 2>/dev/null || true
        fi
        chmod 755 \${SERVICE_HOME}/.config
      fi
      
      REMOTE_EXISTS=false
      if sudo -u \${SERVICE_USER} incus remote list --format csv 2>/dev/null | awk -F',' '{print \$1}' | sed 's/ (current)//' | grep -qE \"^\${INCUS_REMOTE_NAME}\$\"; then
        REMOTE_EXISTS=true
      elif sudo -u \${SERVICE_USER} incus remote list 2>/dev/null | grep -qE \"^\\| \${INCUS_REMOTE_NAME} +\\|\"; then
        REMOTE_EXISTS=true
      fi
      
      if [ \"\${REMOTE_EXISTS}\" = \"true\" ]; then
        echo \"  Remote \${INCUS_REMOTE_NAME} already exists for \${SERVICE_USER}\"
        if sudo -u \${SERVICE_USER} incus list \${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
          echo \"  ✅ Remote is working correctly\"
        else
          echo \"  ⚠️  Remote exists but connection failed, removing to reconfigure...\"
          sudo -u \${SERVICE_USER} incus remote remove \${INCUS_REMOTE_NAME} 2>/dev/null || true
          REMOTE_EXISTS=false
        fi
      fi
      
      if [ \"\${REMOTE_EXISTS}\" = \"false\" ]; then
        echo \"  Adding remote \${INCUS_REMOTE_NAME}...\"
        set +e
        ADD_OUTPUT=\$(sudo -u \${SERVICE_USER} incus remote add \"\${INCUS_REMOTE_NAME}\" \"\${INCUS_REMOTE_URL}\" --accept-certificate --token \"\${TRUST_TOKEN}\" 2>&1)
        ADD_RESULT=\$?
        set -e
        
        if [ \${ADD_RESULT} -eq 0 ]; then
          if sudo -u \${SERVICE_USER} incus remote list --format csv 2>/dev/null | awk -F',' '{print \$1}' | sed 's/ (current)//' | grep -qE \"^\${INCUS_REMOTE_NAME}\$\"; then
            echo \"  ✅ Remote \${INCUS_REMOTE_NAME} added successfully\"
          else
            echo \"  ⚠️  Warning: Command succeeded but remote not found in list\"
          fi
        else
          if echo \"\${ADD_OUTPUT}\" | grep -q \"already exists\\|Remote.*exists\"; then
            if sudo -u \${SERVICE_USER} incus list \${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
              echo \"  ✅ Remote \${INCUS_REMOTE_NAME} already exists and is working\"
            else
              echo \"  ⚠️  Warning: Remote exists but connection failed\"
            fi
          else
            echo \"  ℹ️  Could not add remote (token may have been created on wrong server - retry instantiation)\"
            echo \"     \${ADD_OUTPUT}\"
            echo \"     To add manually: sudo -u \${SERVICE_USER} incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL}\"
          fi
        fi
      fi
      
      echo \"  Setting \${INCUS_REMOTE_NAME} as default remote...\"
      sudo -u \${SERVICE_USER} incus remote switch \${INCUS_REMOTE_NAME} 2>/dev/null || true
      echo \"  ✅ Remote configuration complete\"
    "
  else
    echo "  ⚠️  Warning: Could not generate trust token automatically"
    echo "     The remote may need to be configured manually for the service user"
    echo "     To fix:"
    echo "       1. Generate token on server: incus config trust add ${CLIENT_NAME}"
    echo "       2. Add remote from VM: sudo -u ${SERVICE_USER} incus remote add ${INCUS_REMOTE_NAME} ${INCUS_REMOTE_URL}"
  fi
fi

if [ -n "${VM_IP}" ]; then
  echo "✅ Service user (${SERVICE_USER}) setup complete"
  echo "   You can now SSH into the VM as ${SERVICE_USER}:"
  echo "     ssh ${SERVICE_USER}@${VM_IP}"
else
  echo "✅ Service user (${SERVICE_USER}) setup complete"
  echo "   (VM IP address not yet available)"
fi
