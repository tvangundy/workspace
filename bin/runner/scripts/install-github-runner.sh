#!/usr/bin/env bash
# Install and configure GitHub Actions runner
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.runner-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

# Load Windsor environment if available (with decryption for SOPS secrets)
if command -v windsor > /dev/null 2>&1; then
  set +e
  WINDSOR_ENV_OUTPUT=$(windsor env --decrypt 2>/dev/null || echo "")
  set -e
  if [ -n "${WINDSOR_ENV_OUTPUT}" ]; then
    eval "${WINDSOR_ENV_OUTPUT}" || true
  fi
fi

RUNNER_NAME="${RUNNER_NAME:-runner}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"
RUNNER_USER="${RUNNER_USER:-runner}"
RUNNER_HOME="/home/${RUNNER_USER}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step: Install GitHub Actions Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Set up paths for secrets file
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
CONTEXTS_DIR="${PROJECT_ROOT}/contexts"
ACTIVE_CONTEXT="${WINDSOR_CONTEXT:-${RUNNER_NAME}}"
SECRETS_YAML="${CONTEXTS_DIR}/${ACTIVE_CONTEXT}/secrets.yaml"
ENC_SECRETS_YAML="${CONTEXTS_DIR}/${ACTIVE_CONTEXT}/secrets.enc.yaml"

# Track which values were queried interactively (so we can save them)
QUERIED_VALUES=()

# Check for required parameters from SOPS secrets first, then environment, then prompt
REPO_URL="${GITHUB_RUNNER_REPO_URL:-}"
if [ -z "${REPO_URL}" ]; then
  echo ""
  echo "GitHub Runner Repository URL is required."
  echo "Example: https://github.com/username/repository"
  read -p "Enter GitHub Runner Repository URL: " REPO_URL
  if [ -z "${REPO_URL}" ]; then
    echo "❌ Error: Repository URL is required"
    exit 1
  fi
  export GITHUB_RUNNER_REPO_URL="${REPO_URL}"
  QUERIED_VALUES+=("GITHUB_RUNNER_REPO_URL: ${REPO_URL}")
fi

TOKEN="${GITHUB_RUNNER_TOKEN:-}"
if [ -z "${TOKEN}" ]; then
  echo ""
  echo "GitHub Runner Token is required."
  echo "Get it from: GitHub Settings → Actions → Runners → New self-hosted runner"
  read -p "Enter GitHub Runner Token: " TOKEN
  if [ -z "${TOKEN}" ]; then
    echo "❌ Error: Runner token is required"
    exit 1
  fi
  export GITHUB_RUNNER_TOKEN="${TOKEN}"
  QUERIED_VALUES+=("GITHUB_RUNNER_TOKEN: ${TOKEN}")
fi

# Validate token and repository URL before proceeding
echo ""
echo "  Validating GitHub token and repository URL..."

# Validate repository URL format
if [[ ! "${REPO_URL}" =~ ^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(/)?$ ]]; then
  echo "  ❌ Error: Invalid repository URL format: ${REPO_URL}"
  echo "     Expected format: https://github.com/owner/repository"
  exit 1
fi

# Extract repository path
REPO_PATH="${REPO_URL#https://github.com/}"
REPO_PATH="${REPO_PATH%/}"  # Remove trailing slash

# Validate token format (registration tokens are typically alphanumeric, 20-40 chars)
if [[ ! "${TOKEN}" =~ ^[A-Z0-9]{20,40}$ ]]; then
  echo "  ⚠️  Warning: Token format looks unusual (expected 20-40 alphanumeric characters)"
  echo "     This might be an invalid or expired token"
  echo ""
  read -p "  Continue anyway? [y/N]: " CONTINUE
  if [[ ! "${CONTINUE}" =~ ^[Yy]$ ]]; then
    echo "  Aborting. Please get a new token from:"
    echo "  https://github.com/${REPO_PATH}/settings/actions/runners/new"
    exit 1
  fi
fi

# Try to validate token by checking if we can access the repository
echo "  Checking repository access..."
set +e  # Temporarily disable exit on error
REPO_CHECK=$(curl -s -w "\n%{http_code}" -H "Authorization: token ${TOKEN}" \
  "https://api.github.com/repos/${REPO_PATH}" 2>/dev/null)
HTTP_CODE=$(echo "${REPO_CHECK}" | tail -n1)
REPO_RESPONSE=$(echo "${REPO_CHECK}" | sed '$d')
set -e  # Re-enable exit on error

if [ "${HTTP_CODE}" = "200" ]; then
  echo "  ✅ Token is valid and has access to repository"
elif [ "${HTTP_CODE}" = "401" ] || [ "${HTTP_CODE}" = "403" ]; then
  echo "  ❌ Error: Token is invalid or expired (HTTP ${HTTP_CODE})"
  echo ""
  echo "  Registration tokens expire after ~1 hour and are single-use."
  echo "  Please get a new token from:"
  echo "  https://github.com/${REPO_PATH}/settings/actions/runners/new"
  echo ""
  read -p "  Enter new token (or press Enter to exit): " NEW_TOKEN
  if [ -z "${NEW_TOKEN}" ]; then
    echo "  Aborting."
    exit 1
  fi
  TOKEN="${NEW_TOKEN}"
  export GITHUB_RUNNER_TOKEN="${TOKEN}"
  # Update queried values if this was an interactive session
  if [ ${#QUERIED_VALUES[@]} -gt 0 ]; then
    QUERIED_VALUES=("${QUERIED_VALUES[@]/GITHUB_RUNNER_TOKEN: */GITHUB_RUNNER_TOKEN: ${TOKEN}}")
  fi
  echo "  ✅ Using new token"
elif [ "${HTTP_CODE}" = "404" ]; then
  echo "  ❌ Error: Repository not found (HTTP 404)"
  echo "     Please verify the repository URL: ${REPO_URL}"
  exit 1
else
  echo "  ⚠️  Warning: Could not validate token (HTTP ${HTTP_CODE})"
  echo "     This might be a registration token (which may not work with standard API)"
  echo "     Proceeding with runner configuration..."
fi

# Save any queried values to secrets.yaml
if [ ${#QUERIED_VALUES[@]} -gt 0 ]; then
  echo ""
  echo "  Saving queried settings to secrets.yaml..."
  
  # Create secrets.yaml if it doesn't exist
  if [ ! -f "${SECRETS_YAML}" ]; then
    echo "# GitHub Actions Runner Secrets" > "${SECRETS_YAML}"
    echo "# Generated by runner:install-github-runner" >> "${SECRETS_YAML}"
    echo "" >> "${SECRETS_YAML}"
  fi
  
  # Save or update each queried value
  for value_line in "${QUERIED_VALUES[@]}"; do
    VAR_NAME=$(echo "${value_line}" | cut -d':' -f1)
    VAR_VALUE=$(echo "${value_line}" | cut -d':' -f2- | sed 's/^ //')
    
    if grep -q "^${VAR_NAME}:" "${SECRETS_YAML}" 2>/dev/null; then
      # Update existing value
      sed -i.bak "s|^${VAR_NAME}:.*|${value_line}|" "${SECRETS_YAML}" 2>/dev/null || true
      rm -f "${SECRETS_YAML}.bak" 2>/dev/null || true
    else
      # Append new value
      echo "${value_line}" >> "${SECRETS_YAML}"
    fi
  done
  
  echo "  ✅ Settings saved to ${SECRETS_YAML}"
  
  # Try to encrypt automatically if SOPS is available
  if command -v sops > /dev/null 2>&1 && [ -f "${SECRETS_YAML}" ]; then
    echo ""
    echo "  Encrypting secrets file with SOPS..."
    if sops -e --output "${ENC_SECRETS_YAML}" "${SECRETS_YAML}" 2>/dev/null; then
      echo "  ✅ Secrets encrypted: ${ENC_SECRETS_YAML}"
      echo "  ⚠️  Remember to commit ${ENC_SECRETS_YAML}, not ${SECRETS_YAML}"
    else
      echo "  ⚠️  Warning: Failed to encrypt secrets file automatically"
      echo "     You may need to run: task sops:encrypt-secrets-file"
      echo "     Or ensure SOPS is configured with proper AWS KMS keys"
    fi
  else
    echo ""
    echo "  ⚠️  Important: Encrypt the secrets file before committing:"
    echo "     task sops:encrypt-secrets-file"
  fi
fi

# Optional parameters with defaults
RUNNER_VERSION="${GITHUB_RUNNER_VERSION:-}"
RUNNER_ARCH="${GITHUB_RUNNER_ARCH:-x64}"

# Get runner version if not specified
if [ -z "${RUNNER_VERSION}" ]; then
  echo "  Determining latest runner version..."
  RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//')
  
  if [ -z "${RUNNER_VERSION}" ]; then
    echo "❌ Error: Could not determine latest runner version"
    exit 1
  fi
  echo "  Using runner version: ${RUNNER_VERSION}"
fi

echo ""
echo "  Repository: ${REPO_URL}"
echo "  Runner version: ${RUNNER_VERSION}"
echo "  Architecture: ${RUNNER_ARCH}"
echo "  Installing on: ${TEST_REMOTE_NAME}:${RUNNER_NAME} as user ${RUNNER_USER}"

# Create a temporary script file to avoid quoting issues
INSTALL_SCRIPT=$(mktemp)
cat > "${INSTALL_SCRIPT}" <<'INSTALL_SCRIPT_EOF'
set -euo pipefail

# Ensure home directory exists and is owned by runner user
if [ ! -d "${RUNNER_HOME}" ]; then
  mkdir -p "${RUNNER_HOME}"
fi

# Get the runner user's primary group (in case group name differs)
RUNNER_GID=$(id -g "${RUNNER_USER}" 2>/dev/null || echo "")
if [ -n "${RUNNER_GID}" ]; then
  chown -R "${RUNNER_USER}:${RUNNER_GID}" "${RUNNER_HOME}" 2>/dev/null || \
    chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}" 2>/dev/null || \
    chown -R "${RUNNER_USER}" "${RUNNER_HOME}"
else
  chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}" 2>/dev/null || \
    chown -R "${RUNNER_USER}" "${RUNNER_HOME}"
fi
chmod 755 "${RUNNER_HOME}"

# Create actions-runner directory
mkdir -p "${RUNNER_HOME}/actions-runner"
if [ -n "${RUNNER_GID}" ]; then
  chown "${RUNNER_USER}:${RUNNER_GID}" "${RUNNER_HOME}/actions-runner" 2>/dev/null || \
    chown "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}/actions-runner" 2>/dev/null || \
    chown "${RUNNER_USER}" "${RUNNER_HOME}/actions-runner"
else
  chown "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}/actions-runner" 2>/dev/null || \
    chown "${RUNNER_USER}" "${RUNNER_HOME}/actions-runner"
fi
chmod 755 "${RUNNER_HOME}/actions-runner"
cd "${RUNNER_HOME}/actions-runner"

# Download runner as runner user
echo "  Downloading GitHub Actions runner..."
sudo -u "${RUNNER_USER}" curl -o "actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" -L \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"

# Extract as runner user
echo "  Extracting runner..."
sudo -u "${RUNNER_USER}" tar xzf ./actions-runner-linux-${RUNNER_ARCH}-*.tar.gz

# Check if runner is already configured locally and remove it if needed
if [ -f ./config.sh ] && [ -f .runner ]; then
  echo "  Removing existing local runner configuration..."
  # Stop the service if it's running
  if [ -f ./svc.sh ]; then
    sudo ./svc.sh stop 2>/dev/null || true
    sudo ./svc.sh uninstall 2>/dev/null || true
  fi
  # Remove runner from GitHub (if we have a token)
  if [ -n "${TOKEN}" ]; then
    echo "  Removing runner from GitHub..."
    sudo -u "${RUNNER_USER}" ./config.sh remove --token "${TOKEN}" --unattended 2>/dev/null || {
      echo "  ⚠️  Warning: Could not remove runner from GitHub (may need different token)"
    }
  fi
  # Also remove the .runner file and other config files
  sudo -u "${RUNNER_USER}" rm -f .runner .credentials .credentials_rsaparams .env 2>/dev/null || true
  echo "  ✅ Existing local runner configuration removed"
fi

# Configure runner as runner user
echo "  Configuring runner..."
set +e  # Temporarily disable exit on error to catch configuration failures
CONFIG_OUTPUT=$(sudo -u "${RUNNER_USER}" ./config.sh --url "${REPO_URL}" --token "${TOKEN}" --unattended 2>&1)
CONFIG_EXIT=$?
set -e  # Re-enable exit on error

if [ ${CONFIG_EXIT} -ne 0 ]; then
  # Check for specific error types and provide helpful guidance
  if echo "${CONFIG_OUTPUT}" | grep -qi "runner exists with the same name"; then
    echo "  ❌ Error: A runner with the same name already exists on GitHub"
    echo ""
    echo "  This runner may have been registered previously. To resolve this:"
    echo "  1. Go to GitHub: Settings → Actions → Runners"
    echo "  2. Find and remove the existing runner named \"runner\""
    echo "  3. Or use a different runner name"
    echo ""
    echo "  Alternatively, if you have the original registration token, you can:"
    echo "  - Remove it manually from GitHub web UI, or"
    echo "  - Use a different VM/runner name"
    echo ""
    exit 1
  elif echo "${CONFIG_OUTPUT}" | grep -qiE "(404|Not Found|NotFound)"; then
    echo "  ❌ Error: Failed to register runner (404 Not Found)"
    echo ""
    echo "  This usually means one of the following:"
    echo "  1. The registration token is invalid or expired"
    echo "  2. The token doesn't have permission to register runners for this repository"
    echo "  3. The repository URL is incorrect"
    echo ""
    echo "  To fix this:"
    # Extract repository path from URL (e.g., "tvangundy/test" from "https://github.com/tvangundy/test")
    REPO_PATH="${REPO_URL#https://github.com/}"
    REPO_PATH="${REPO_PATH#http://github.com/}"
    REPO_PATH="${REPO_PATH%/}"  # Remove trailing slash if present
    echo "  1. Go to: https://github.com/${REPO_PATH}/settings/actions/runners/new"
    echo "  2. Generate a new registration token"
    echo "  3. Update your secrets.yaml with the new token:"
    echo "     GITHUB_RUNNER_TOKEN: <new-token>"
    echo "  4. Re-run this task"
    echo ""
    echo "  Repository: ${REPO_URL}"
    echo "  Full error output:"
    echo "${CONFIG_OUTPUT}"
    exit 1
  else
    # Some other configuration error
    echo "  ❌ Error: Failed to configure runner"
    echo ""
    echo "  Error output:"
    echo "${CONFIG_OUTPUT}"
    echo ""
    echo "  Common issues:"
    echo "  - Invalid or expired registration token"
    echo "  - Incorrect repository URL"
    echo "  - Network connectivity issues"
    echo "  - Insufficient permissions"
    exit ${CONFIG_EXIT}
  fi
fi

# Install as systemd service (runs as runner user)
echo "  Installing runner service..."
sudo ./svc.sh install "${RUNNER_USER}"
sudo ./svc.sh start

echo "✅ GitHub Actions runner installed and started"
INSTALL_SCRIPT_EOF

# Copy script to VM and execute it with environment variables
# Try multiple locations to find one that works
SCRIPT_PATH=""
for try_path in "/tmp/install-runner.sh" "/root/tmp/install-runner.sh" "${RUNNER_HOME}/install-runner.sh"; do
  # Create directory if needed
  dir_path=$(dirname "${try_path}")
  incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- mkdir -p "${dir_path}" 2>/dev/null || true
  
  # Try to push the file
  if incus file push "${INSTALL_SCRIPT}" "${TEST_REMOTE_NAME}:${RUNNER_NAME}${try_path}" --mode=0755 2>/dev/null; then
    SCRIPT_PATH="${try_path}"
    break
  fi
done

if [ -z "${SCRIPT_PATH}" ]; then
  echo "  ❌ Error: Failed to push install script to VM"
  echo "     Tried: /tmp, /root/tmp, and ${RUNNER_HOME}"
  exit 1
fi
incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- env \
  TOKEN="${TOKEN}" \
  REPO_URL="${REPO_URL}" \
  RUNNER_USER="${RUNNER_USER}" \
  RUNNER_HOME="${RUNNER_HOME}" \
  RUNNER_ARCH="${RUNNER_ARCH}" \
  RUNNER_VERSION="${RUNNER_VERSION}" \
  bash "${SCRIPT_PATH}"

# Clean up
rm -f "${INSTALL_SCRIPT}"
incus exec "${TEST_REMOTE_NAME}:${RUNNER_NAME}" -- rm -f "${SCRIPT_PATH}"

# Update windsor.yaml to add secrets section and runner environment variables
echo ""
echo "  Updating windsor.yaml with runner configuration..."

TEST_WINDSOR_YAML="${CONTEXTS_DIR}/${ACTIVE_CONTEXT}/windsor.yaml"

if [ ! -f "${TEST_WINDSOR_YAML}" ]; then
  echo "  ⚠️  Warning: windsor.yaml not found at ${TEST_WINDSOR_YAML}"
  echo "     This should have been created by initialize-context.sh"
  exit 1
fi

# Step 1: Ensure secrets section exists with sops.enabled: true
if ! grep -q "^secrets:" "${TEST_WINDSOR_YAML}" 2>/dev/null; then
  # Add secrets section before environment section
  if grep -q "^environment:" "${TEST_WINDSOR_YAML}" 2>/dev/null; then
    # Insert before environment section
    awk '/^environment:/ {print "secrets:"; print "  sops:"; print "    enabled: true"; print ""; print} !/^environment:/ {print}' "${TEST_WINDSOR_YAML}" > "${TEST_WINDSOR_YAML}.tmp" && mv "${TEST_WINDSOR_YAML}.tmp" "${TEST_WINDSOR_YAML}"
  else
    # Append at end
    {
      echo ""
      echo "secrets:"
      echo "  sops:"
      echo "    enabled: true"
    } >> "${TEST_WINDSOR_YAML}"
  fi
else
  # Secrets section exists, ensure sops.enabled: true
  if ! awk '/^secrets:/,/^[a-zA-Z_]/ {if (/enabled:/ && !/enabled: true/) {gsub(/enabled:.*/, "enabled: true"); print; next}} {print}' "${TEST_WINDSOR_YAML}" | grep -A 2 "^secrets:" | grep -q "enabled: true" 2>/dev/null; then
    # Update secrets section to ensure sops.enabled: true
    awk '
    /^secrets:/ {
      print
      in_secrets = 1
      next
    }
    in_secrets && /^[[:space:]]+sops:/ {
      print
      next
    }
    in_secrets && /^[[:space:]]+enabled:/ {
      print "    enabled: true"
      in_secrets = 0
      next
    }
    in_secrets && /^[a-zA-Z_]/ {
      # End of secrets section without finding enabled, add it
      print "  sops:"
      print "    enabled: true"
      in_secrets = 0
      print
      next
    }
    in_secrets {
      print
      next
    }
    {
      print
    }
    ' "${TEST_WINDSOR_YAML}" > "${TEST_WINDSOR_YAML}.tmp" && mv "${TEST_WINDSOR_YAML}.tmp" "${TEST_WINDSOR_YAML}"
  fi
fi

# Step 2: Update environment section with runner variables
# Define variables to be updated/added in windsor.yaml
declare -a runner_vars=(
  "GITHUB_RUNNER_REPO_URL"
  "GITHUB_RUNNER_VERSION"
  "GITHUB_RUNNER_ARCH"
  "GITHUB_RUNNER_TOKEN"
  "RUNNER_USER"
  "RUNNER_HOME"
)

# Create a temporary file with new environment variables
# Secrets stored in secrets.yaml should be referenced using SOPS syntax: ${{ sops.VARIABLE_NAME }}
TEMP_ENV=$(mktemp)
{
  echo "  GITHUB_RUNNER_REPO_URL: \"\${{ sops.GITHUB_RUNNER_REPO_URL }}\""
  echo "  GITHUB_RUNNER_VERSION: \"${RUNNER_VERSION}\""
  echo "  GITHUB_RUNNER_ARCH: \"${RUNNER_ARCH}\""
  echo "  GITHUB_RUNNER_TOKEN: \"\${{ sops.GITHUB_RUNNER_TOKEN }}\""
  echo "  RUNNER_USER: \"${RUNNER_USER}\""
  echo "  RUNNER_HOME: \"${RUNNER_HOME}\""
} > "${TEMP_ENV}"

# Create a temporary awk script to avoid quoting issues
AWK_SCRIPT=$(mktemp)
cat > "${AWK_SCRIPT}" <<'AWK_SCRIPT_EOF'
BEGIN {
  split(vars_to_remove, remove_arr, " ")
  for (i in remove_arr) {
    remove_map[remove_arr[i]] = 1
  }
  in_env_section = 0
  printed_new_vars = 0
  
  # Read new variables from temp_env
  while (getline line < temp_env > 0) {
    new_vars[++new_vars_count] = line
  }
  close(temp_env)
}
/^environment:/ {
  print
  in_env_section = 1
  # Read new variables from temp_env and print them here
  for (i = 1; i <= new_vars_count; i++) {
    print new_vars[i]
  }
  printed_new_vars = 1
  next
}
{
  if (in_env_section == 1 && /^[[:space:]]+[a-zA-Z0-9_]+:/) {
    # Check if the current line's variable name is in our remove_map
    split($0, a, ":")
    var_name = a[1]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var_name)
    if (var_name in remove_map) {
      # Skip this line as it's being replaced by new variables
      next
    }
    print
    next
  }
  if (in_env_section == 1 && !/^[[:space:]]+[a-zA-Z0-9_]+:/ && !/^[[:space:]]*$/) {
    # If we are in the environment section but encounter a line that is not a variable
    # (e.g., a comment or another section header), then we are out of the environment section.
    in_env_section = 0
    print
    next
  }
  print
}
END {
  if (!printed_new_vars) {
    # If no environment section was found, append it at the end
    print ""
    print "environment:"
    for (i = 1; i <= new_vars_count; i++) {
      print new_vars[i]
    }
  }
}
AWK_SCRIPT_EOF

# Use awk to update the environment section of windsor.yaml
awk -v temp_env="${TEMP_ENV}" -v vars_to_remove="${runner_vars[*]}" -f "${AWK_SCRIPT}" "${TEST_WINDSOR_YAML}" > "${TEST_WINDSOR_YAML}.tmp" && mv "${TEST_WINDSOR_YAML}.tmp" "${TEST_WINDSOR_YAML}"

# Clean up
rm -f "${AWK_SCRIPT}"

rm -f "${TEMP_ENV}"

echo "  ✅ Updated windsor.yaml with runner configuration"

echo "✅ GitHub Actions runner installation complete"
echo ""
echo "  The runner is now running as a systemd service"
echo "  You can check its status or destroy it with:"
echo "    task runner:status [-- <runner-name>]"
echo "    task runner:destroy [-- <runner-name>]"
echo ""
if [ -f "${ENC_SECRETS_YAML}" ]; then
  echo "  ✅ Secrets are encrypted in: ${ENC_SECRETS_YAML}"
  echo "     The token is stored securely and will be available via 'windsor env'"
elif [ -f "${SECRETS_YAML}" ]; then
  echo "  ⚠️  Remember to encrypt secrets before committing:"
  echo "     task sops:encrypt-secrets-file"
fi

