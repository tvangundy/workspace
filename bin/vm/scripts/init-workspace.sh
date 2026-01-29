#!/usr/bin/env bash
# Initialize workspace on the VM if VM_INIT_WORKSPACE is true
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
# Set workspace initialization based on flag
if [ "${SKIP_WORKSPACE:-false}" = "true" ]; then
  VM_INIT_WORKSPACE="false"
else
  VM_INIT_WORKSPACE="${VM_INIT_WORKSPACE:-true}"
fi

# Skip if workspace initialization is disabled
if [ "${VM_INIT_WORKSPACE}" != "true" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Workspace Initialization (skipped)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Workspace initialization is disabled (--no-workspace flag was set)"
  exit 0
fi

# Detect current user from host
CURRENT_USER="${USER:-$(whoami)}"
CURRENT_UID="${UID:-$(id -u)}"
CURRENT_GID="${GID:-$(id -g)}"
PROJECT_ROOT="${PROJECT_ROOT:-${WINDSOR_PROJECT_ROOT}}"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
WORKSPACE_NAME=$(basename "${PROJECT_ROOT}")
INIT_PATH="/home/${CURRENT_USER}/${WORKSPACE_NAME}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Workspace Initialization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Source: ${PROJECT_ROOT}"
echo "  Destination: ${INIT_PATH}"

# Check if workspace directory exists
if [ ! -d "${PROJECT_ROOT}" ]; then
  echo "⚠️  Warning: Workspace directory '${PROJECT_ROOT}' does not exist"
  echo "   Skipping workspace initialization"
  exit 0
fi

# Create the workspace directory in the VM
incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
set -euo pipefail
mkdir -p ${INIT_PATH}
chown -R ${CURRENT_UID}:${CURRENT_GID} ${INIT_PATH} 2>/dev/null || \
  chown -R ${CURRENT_USER}:${CURRENT_USER} ${INIT_PATH} 2>/dev/null || true
"

# Copy workspace contents using tar archive (more reliable)
echo "  Creating archive..."
TEMP_ARCHIVE=$(mktemp /tmp/workspace-XXXXXX.tar.gz)
set +e  # Temporarily disable exit on error

# Create tar archive excluding common directories
cd "${PROJECT_ROOT}"
tar --exclude='.git' \
    --exclude='node_modules' \
    --exclude='.terraform' \
    --exclude='.terraform.tfstate*' \
    --exclude='terraform.tfstate*' \
    -czf "${TEMP_ARCHIVE}" . 2>/dev/null

if [ -f "${TEMP_ARCHIVE}" ]; then
  echo "  Copying archive to VM..."
  # Copy archive to VM
  incus file push "${TEMP_ARCHIVE}" "${TEST_REMOTE_NAME}:${VM_NAME}/tmp/workspace.tar.gz" 2>/dev/null
  
  # Extract archive in VM
  echo "  Extracting archive..."
  incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
    cd ${INIT_PATH}
    tar -xzf /tmp/workspace.tar.gz 2>/dev/null || true
    rm -f /tmp/workspace.tar.gz
  " 2>/dev/null
  
  # Clean up local archive
  rm -f "${TEMP_ARCHIVE}"
else
  echo "⚠️  Warning: Failed to create archive, falling back to file-by-file copy..."
  # Fallback: copy files individually
  cd "${PROJECT_ROOT}"
  find . -type f -not -path '*/\.git/*' -not -path '*/node_modules/*' -not -path '*/.terraform/*' -not -path '*/.terraform.tfstate*' -not -path '*/terraform.tfstate*' | while read -r file; do
    # Remove leading ./
    file=$(echo "${file}" | sed 's|^\./||')
    if [ -n "${file}" ]; then
      TARGET_DIR="${INIT_PATH}/$(dirname "${file}")"
      # Ensure target directory exists
      incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "mkdir -p ${TARGET_DIR} 2>/dev/null || true" 2>/dev/null
      # Copy file
      incus file push "${PROJECT_ROOT}/${file}" "${TEST_REMOTE_NAME}:${VM_NAME}${INIT_PATH}/${file}" 2>/dev/null || true
    fi
  done
fi

set -e  # Re-enable exit on error

# Fix ownership and permissions
incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
chown -R ${CURRENT_UID}:${CURRENT_GID} ${INIT_PATH} 2>/dev/null || \
  chown -R ${CURRENT_USER}:${CURRENT_USER} ${INIT_PATH} 2>/dev/null || true
find ${INIT_PATH} -type f -exec chmod 644 {} \; 2>/dev/null || true
find ${INIT_PATH} -type d -exec chmod 755 {} \; 2>/dev/null || true
find ${INIT_PATH} -name '*.sh' -exec chmod 755 {} \; 2>/dev/null || true
"

# Run aqua i and windsor init
echo "  Initializing workspace..."
incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
set -euo pipefail

# Run commands as the user
sudo -u ${CURRENT_USER} bash -c '
  set -euo pipefail
  cd ${INIT_PATH}
  
  # Set up aqua PATH - check both Homebrew and local installation
  if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" 2>/dev/null || true
  elif [ -f /home/${CURRENT_USER}/.linuxbrew/bin/brew ]; then
    eval \"\$(/home/${CURRENT_USER}/.linuxbrew/bin/brew shellenv)\" 2>/dev/null || true
  fi
  export PATH=\"/home/${CURRENT_USER}/.local/share/aquaproj-aqua/bin:\${PATH}\"
  
  # Run aqua i (install packages defined in aqua.yaml)
  echo \"  Running aqua i...\"
  if [ -f aqua.yaml ]; then
    if command -v aqua >/dev/null 2>&1; then
      echo \"    Installing packages from aqua.yaml (this may take a few minutes)...\"
      echo \"    Progress will be shown below...\"
      aqua i --log-level info 2>&1 || {
        echo \"⚠️  Warning: aqua i completed with warnings or errors\"
        echo \"   You may need to run aqua i manually to install remaining packages\"
      }
      echo \"✅ aqua i completed\"
    else
      echo \"⚠️  Warning: aqua command not found, skipping aqua i\"
    fi
  else
    echo \"⚠️  Warning: aqua.yaml not found, skipping aqua i\"
  fi
  
  # Run windsor init - ensure Homebrew is in PATH
  echo \"  Running windsor init...\"
  # Add Homebrew to PATH if it exists (windsor is installed via Homebrew)
  if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null || true)\"
  fi
  if command -v windsor >/dev/null 2>&1; then
    windsor init ${VM_NAME} 2>&1 || windsor init 2>&1 || true
    echo \"✅ windsor init completed\"
  else
    echo \"⚠️  Warning: windsor command not found, skipping windsor init\"
    echo \"   Install windsor to use this feature\"
  fi
'
"
echo "✅ Workspace initialized at ${INIT_PATH}"

# Update root windsor.yaml on VM with environment variables from context
echo "  Updating windsor.yaml with environment variables..."
PROJECT_ROOT="${PROJECT_ROOT:-${WINDSOR_PROJECT_ROOT}}"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
CONTEXT_WINDSOR_YAML="${PROJECT_ROOT}/contexts/${VM_NAME}/windsor.yaml"

if [ -f "${CONTEXT_WINDSOR_YAML}" ]; then
  # Copy the context's windsor.yaml to root windsor.yaml on VM
  incus file push "${CONTEXT_WINDSOR_YAML}" "${TEST_REMOTE_NAME}:${VM_NAME}${INIT_PATH}/windsor.yaml" 2>/dev/null || true
  # Fix ownership
  incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
    chown ${CURRENT_UID}:${CURRENT_GID} ${INIT_PATH}/windsor.yaml 2>/dev/null || \
      chown ${CURRENT_USER}:${CURRENT_USER} ${INIT_PATH}/windsor.yaml 2>/dev/null || true
    chmod 644 ${INIT_PATH}/windsor.yaml 2>/dev/null || true
  " 2>/dev/null || true
else
  # If context windsor.yaml doesn't exist, create one with environment variables
  # Create windsor.yaml content on host first using printf
  TEMP_WINDSOR_YAML=$(mktemp /tmp/windsor-XXXXXX.yaml)
  {
    echo "id: ${VM_NAME}-VM"
    echo "provider: generic"
    echo "environment:"
    echo "  INCUS_REMOTE_NAME: ${TEST_REMOTE_NAME}"
    echo "  VM_INIT_WORKSPACE: ${VM_INIT_WORKSPACE}"
    echo "  VM_INSTANCE_NAME: ${VM_NAME}"
    echo "  VM_IMAGE: ${VM_IMAGE:-ubuntu/24.04}"
    echo "  VM_MEMORY: ${VM_MEMORY:-16GB}"
    echo "  VM_CPU: ${VM_CPU:-4}"
    echo "  VM_DISK_SIZE: ${VM_DISK_SIZE:-100GB}"
    if [ -n "${VM_NETWORK_NAME:-}" ]; then
      echo "  VM_NETWORK_NAME: ${VM_NETWORK_NAME}"
    fi
    echo "  VM_STORAGE_POOL: ${VM_STORAGE_POOL:-local}"
    echo "  VM_AUTOSTART: ${VM_AUTOSTART:-false}"
    echo "  DOCKER_HOST: unix:///var/run/docker.sock"
  } > "${TEMP_WINDSOR_YAML}"
  # Push to VM
  incus file push "${TEMP_WINDSOR_YAML}" "${TEST_REMOTE_NAME}:${VM_NAME}${INIT_PATH}/windsor.yaml" 2>/dev/null || true
  rm -f "${TEMP_WINDSOR_YAML}"
  # Fix ownership
  incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
    chown ${CURRENT_UID}:${CURRENT_GID} ${INIT_PATH}/windsor.yaml 2>/dev/null || \
      chown ${CURRENT_USER}:${CURRENT_USER} ${INIT_PATH}/windsor.yaml 2>/dev/null || true
    chmod 644 ${INIT_PATH}/windsor.yaml 2>/dev/null || true
  " 2>/dev/null || true
fi

# Run windsor init and windsor up if --windsor-up flag was set
RUN_WINDSOR_UP="${RUN_WINDSOR_UP:-false}"
if [ "${RUN_WINDSOR_UP}" = "true" ]; then
  echo ""
  echo "  Running windsor init and windsor up..."
  incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "
    set -euo pipefail
    cd ${INIT_PATH}
    # Add Homebrew to PATH if it exists (windsor is installed via Homebrew)
    if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
      eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null || true)\"
    fi
    if command -v windsor >/dev/null 2>&1; then
      windsor init 2>&1 || true
      windsor up 2>&1 || true
      echo '✅ Windsor init and up completed'
    else
      echo '⚠️  Warning: windsor command not found in VM'
      echo '   Install windsor to use this feature'
    fi
  "
fi
