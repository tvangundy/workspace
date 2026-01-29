#!/usr/bin/env bash
# Sets up Incus client on the VM and configures the nuc remote with trust token
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Error: VM name is required"
  echo "Usage: $0 <vm-name>"
  exit 1
fi

VM_NAME="${1}"
REMOTE="${INCUS_REMOTE_NAME}"
RUNNER_USER="${RUNNER_USER:-}"

# Get Incus server IP (default to common IP or use environment variable)
# First try environment variable, then Windsor variable, then default
if [ -n "${INCUS_SERVER_IP:-}" ]; then
  # Use environment variable if set
  :
elif [ -n "${INCUS_REMOTE_IP_0:-}" ]; then
  INCUS_SERVER_IP="${INCUS_REMOTE_IP_0}"
else
  INCUS_SERVER_IP="192.168.2.101"
fi

# Get remote name (default to REMOTE if TARGET_INCUS_SERVER_NAME is not set)
if [ -n "${TARGET_INCUS_SERVER_NAME:-}" ]; then
  INCUS_REMOTE_NAME="${TARGET_INCUS_SERVER_NAME}"
else
  INCUS_REMOTE_NAME="${REMOTE}"
fi
INCUS_REMOTE_URL="https://${INCUS_SERVER_IP}:8443"

echo "Setting up Incus client and remote on ${REMOTE}:${VM_NAME}..."
echo "  Server IP: ${INCUS_SERVER_IP}"
echo "  Remote name: ${INCUS_REMOTE_NAME}"
echo "  Remote URL: ${INCUS_REMOTE_URL}"
echo ""

# Step 1: Install Incus client if not already installed
echo "Step 1: Checking Incus client installation..."
incus exec "${REMOTE}:${VM_NAME}" -- bash -c "
set -euo pipefail

if command -v incus >/dev/null 2>&1; then
  echo '✅ Incus client is already installed'
  incus version
else
  echo 'Installing Incus client...'
  
  # Install required packages first (curl, gpg, ca-certificates)
  export DEBIAN_FRONTEND=noninteractive
  echo '  Installing required packages (curl, gpg, ca-certificates)...'
  apt-get update -qq
  apt-get install -y -qq curl gpg ca-certificates > /dev/null 2>&1
  
  # Detect OS and install accordingly
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=\"\${ID:-}\"
    OS_VERSION_ID=\"\${VERSION_ID:-}\"
  else
    echo '⚠️  Warning: Could not detect OS, skipping Incus installation'
    exit 1
  fi
  
  # Install Incus client based on OS
  if [ \"\${OS_ID}\" = \"ubuntu\" ] || [ \"\${OS_ID}\" = \"debian\" ]; then
    # Try installing from default repositories first (Ubuntu 24.04+ has Incus)
    if apt-cache search incus 2>/dev/null | grep -q '^incus '; then
      echo '  Installing Incus from default repositories...'
      apt-get update -qq
      apt-get install -y -qq incus > /dev/null
      echo '✅ Incus client installed from default repositories'
    else
      # Fallback: Add Incus repository for Debian/Ubuntu
      echo '  Incus not in default repos, adding zabbly repository...'
      # Remove any existing malformed sources files first
      rm -f /etc/apt/sources.list.d/zabbly-incus-stable.sources /etc/apt/sources.list.d/zabbly-incus-stable.list 2>/dev/null || true
      curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --dearmor | tee /usr/share/keyrings/zabbly.gpg > /dev/null
      # Use proper repository URL format - for Ubuntu use codename, for Debian use version
      if [ \"\${OS_ID}\" = \"ubuntu\" ]; then
        # Get Ubuntu codename (e.g., noble for 24.04)
        UBUNTU_CODENAME=\$(lsb_release -cs 2>/dev/null || echo \"\${VERSION_CODENAME:-jammy}\")
        echo \"deb [signed-by=/usr/share/keyrings/zabbly.gpg] https://pkgs.zabbly.com/incus/stable \${OS_ID} \${UBUNTU_CODENAME} main\" | tee /etc/apt/sources.list.d/zabbly-incus-stable.list > /dev/null
      else
        echo \"deb [signed-by=/usr/share/keyrings/zabbly.gpg] https://pkgs.zabbly.com/incus/stable \${OS_ID} \${OS_VERSION_ID} main\" | tee /etc/apt/sources.list.d/zabbly-incus-stable.list > /dev/null
      fi
      apt-get update -qq
      apt-get install -y -qq incus > /dev/null
      echo '✅ Incus client installed from zabbly repository'
    fi
  elif [ \"\${OS_ID}\" = \"almalinux\" ] || [ \"\${OS_ID}\" = \"rocky\" ] || [ \"\${OS_ID}\" = \"rhel\" ]; then
    # Install via snap or other method for RHEL-based systems
    if command -v snap >/dev/null 2>&1; then
      snap install incus
      echo '✅ Incus client installed via snap'
    else
      echo '⚠️  Warning: Incus installation method not available for RHEL-based systems'
      echo '   Install Incus manually or install snapd first'
      exit 1
    fi
  else
    echo \"⚠️  Warning: Incus installation not configured for OS: \${OS_ID}\"
    echo '   Please install Incus client manually'
    exit 1
  fi
fi

# Ensure user is in incus group to access Incus daemon
if getent group incus >/dev/null 2>&1; then
  # Detect user if not set - try RUNNER_USER first, then current user, then ubuntu, then first non-root user
  DETECTED_USER=\"\"
  if [ -n \"${RUNNER_USER}\" ]; then
    DETECTED_USER=\"${RUNNER_USER}\"
  else
    # Try to get current user
    DETECTED_USER=\$(whoami 2>/dev/null || echo \"\")
    # If root or empty, try ubuntu user (default on Ubuntu cloud images)
    if [ -z \"\${DETECTED_USER}\" ] || [ \"\${DETECTED_USER}\" = \"root\" ]; then
      if id ubuntu >/dev/null 2>&1; then
        DETECTED_USER=\"ubuntu\"
      else
        # Get first non-root user
        DETECTED_USER=\$(getent passwd | grep -v '^root:' | grep -v '^daemon:' | head -1 | cut -d: -f1 || echo \"\")
      fi
    fi
  fi
  
  if [ -z \"\${DETECTED_USER}\" ]; then
    echo '⚠️  Warning: Could not detect user for incus group membership'
  elif ! id \"\${DETECTED_USER}\" >/dev/null 2>&1; then
    echo \"⚠️  Warning: User \${DETECTED_USER} does not exist, skipping incus group setup\"
  else
    # Check if user is already in incus group
    if ! groups \"\${DETECTED_USER}\" 2>/dev/null | grep -q '\bincus\b'; then
      echo \"Adding \${DETECTED_USER} to incus group...\"
      usermod -aG incus \"\${DETECTED_USER}\"
      echo \"✅ User \${DETECTED_USER} added to incus group\"
    else
      echo \"✅ User \${DETECTED_USER} is already in incus group\"
    fi
    
    # Ensure socket permissions are correct (if socket exists)
    if [ -S /var/lib/incus/unix.socket ]; then
      # Ensure incus group has read/write access to the socket
      chmod g+rw /var/lib/incus/unix.socket 2>/dev/null || true
      # Ensure socket directory is accessible
      if [ -d /var/lib/incus ]; then
        chmod g+rx /var/lib/incus 2>/dev/null || true
      fi
    fi
    
    # Activate group membership for the current session (if user is logged in via SSH)
    # This allows the user to use incus commands immediately without logging out
    if [ \"\${DETECTED_USER}\" != \"root\" ] && id \"\${DETECTED_USER}\" >/dev/null 2>&1; then
      # Try to activate group membership by running a command as the user
      # This creates a new shell session with the updated group membership
      echo \"Activating incus group membership for \${DETECTED_USER}...\"
      # Use sg (substitute group) to run a command with the incus group active
      # This doesn't require the user to log out/in
      sudo -u \"\${DETECTED_USER}\" sg incus -c 'id' >/dev/null 2>&1 || true
      echo \"✅ Group membership activated\"
    fi
    
    echo ''
    echo '⚠️  Note: If you still cannot access incus, you may need to log out and back in'
    echo '   Or run: newgrp incus'
  fi
else
  echo '⚠️  Warning: incus group not found - Incus may not be properly installed'
fi
"

# Step 2: Generate trust token on the server (if we have access)
echo ""
echo "Step 2: Generating trust token on Incus server..."
TRUST_TOKEN=""
# Detect user for client name
DETECTED_USER_FOR_CLIENT="${RUNNER_USER}"
if [ -z "${DETECTED_USER_FOR_CLIENT}" ]; then
  # Default to 'ubuntu' which is the default user on Ubuntu cloud images
  DETECTED_USER_FOR_CLIENT="ubuntu"
fi
CLIENT_NAME="${VM_NAME}-${DETECTED_USER_FOR_CLIENT}"

# Try to generate token on server if we have access
set +e  # Temporarily disable exit on error for token generation
if [ "${REMOTE}" != "local" ]; then
  # Always try to generate token - the remote might be accessible even if not in list
  echo "  Generating trust token on server via host Incus client..."
  # Try to generate token - use the remote name directly
  TRUST_OUTPUT=$(incus config trust add "${CLIENT_NAME}" --remote "${INCUS_REMOTE_NAME}" 2>&1 || \
                 incus config trust add "${CLIENT_NAME}" 2>&1 || echo "")
  # Try to extract token: look for line after "token:" or extract base64-like strings
  TRUST_TOKEN=$(echo "${TRUST_OUTPUT}" | awk '/token:/ {getline; print}' | head -1 | tr -d '[:space:]' || echo "")
  # If that didn't work, try extracting long base64 strings (tokens are typically 100+ chars)
  if [ -z "${TRUST_TOKEN}" ] || [ ${#TRUST_TOKEN} -lt 64 ]; then
    TRUST_TOKEN=$(echo "${TRUST_OUTPUT}" | grep -oE '[a-zA-Z0-9_-]{64,}' | head -1 || echo "")
  fi
  if [ -n "${TRUST_TOKEN}" ] && [ ${#TRUST_TOKEN} -ge 64 ]; then
    echo "✅ Trust token generated: ${TRUST_TOKEN:0:20}..."
  else
    echo "⚠️  Warning: Could not generate trust token automatically"
    echo "   Token output: ${TRUST_OUTPUT}"
    echo "   You may need to generate the token manually on the server:"
    echo "     incus config trust add ${CLIENT_NAME}"
  fi
fi
set -e  # Re-enable exit on error

# Step 3: Configure Incus remote on the VM
echo ""
echo "Step 3: Configuring Incus remote on VM..."

# Determine which user to configure the remote for
REMOTE_USER="${RUNNER_USER:-ubuntu}"
if [ -z "${RUNNER_USER}" ]; then
  # Try to detect the user from the VM
  REMOTE_USER=$(incus exec "${REMOTE}:${VM_NAME}" -- bash -c "getent passwd | grep -v '^root:' | grep -v '^daemon:' | head -1 | cut -d: -f1" 2>/dev/null || echo "ubuntu")
fi

if [ -n "${TRUST_TOKEN}" ]; then
  # Use the generated token
  echo "  Adding remote with trust token for user ${REMOTE_USER}..."
  # Escape the trust token for safe passing to the VM
  TRUST_TOKEN_ESCAPED=$(printf '%s\n' "${TRUST_TOKEN}" | sed "s/'/'\\\\''/g")
  incus exec "${REMOTE}:${VM_NAME}" -- bash -c "
    set -euo pipefail
    
    # Variables that need to be expanded in the VM shell
    INCUS_REMOTE_NAME=\"${INCUS_REMOTE_NAME}\"
    INCUS_REMOTE_URL=\"${INCUS_REMOTE_URL}\"
    TRUST_TOKEN=\"${TRUST_TOKEN_ESCAPED}\"
    REMOTE_USER=\"${REMOTE_USER}\"
    
    # Check if remote already exists for the user
    REMOTE_EXISTS=false
    if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | grep -qE \"^\${INCUS_REMOTE_NAME}( |,)\" || \
       sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -qE \"^\${INCUS_REMOTE_NAME}( |)\" || \
       sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -q \"\${INCUS_REMOTE_NAME}\"; then
      REMOTE_EXISTS=true
    fi
    
    if [ \"\${REMOTE_EXISTS}\" = \"true\" ]; then
      echo \"⚠️  Remote \${INCUS_REMOTE_NAME} already exists for user \${REMOTE_USER}\"
      
      # Check if the existing remote points to the same URL
      EXISTING_URL=\$(sudo -u \${REMOTE_USER} incus remote get-url \${INCUS_REMOTE_NAME} 2>/dev/null || echo \"\")
      if [ \"\${EXISTING_URL}\" = \"\${INCUS_REMOTE_URL}\" ]; then
        echo \"✅ Remote \${INCUS_REMOTE_NAME} already configured with correct URL, verifying connection...\"
        # Test if we can connect to the existing remote
        if sudo -u \${REMOTE_USER} incus list \${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
          echo \"✅ Existing remote \${INCUS_REMOTE_NAME} is working correctly\"
          exit 0
        else
          echo \"⚠️  Existing remote exists but connection failed, removing to reconfigure...\"
        fi
      else
        echo \"⚠️  Remote \${INCUS_REMOTE_NAME} exists with different URL (\${EXISTING_URL}), removing to reconfigure...\"
      fi
      
      # Remove the existing remote
      echo \"  Removing existing remote \${INCUS_REMOTE_NAME}...\"
      if sudo -u \${REMOTE_USER} incus remote remove \${INCUS_REMOTE_NAME} 2>&1; then
        echo \"✅ Remote \${INCUS_REMOTE_NAME} removed successfully\"
        # Verify it was actually removed
        sleep 1
        if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | grep -qE \"^\${INCUS_REMOTE_NAME}( |,)\" || \
           sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -q \"\${INCUS_REMOTE_NAME}\"; then
          echo \"⚠️  Warning: Remote \${INCUS_REMOTE_NAME} still exists after removal attempt\"
          echo \"   This may cause issues, but continuing...\"
        fi
      else
        echo \"⚠️  Warning: Failed to remove existing remote \${INCUS_REMOTE_NAME}\"
        echo \"   Attempting to add anyway (may fail if remote truly exists)...\"
      fi
    fi
    
    # Add remote with trust token (non-interactive) as the user
    set +e
    ADD_OUTPUT=\$(echo \"\${TRUST_TOKEN}\" | sudo -u \${REMOTE_USER} incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL} --token - 2>&1)
    ADD_RESULT=\$?
    set -e
    
    # Check if the error is because remote already exists
    if [ \${ADD_RESULT} -ne 0 ] && echo \"\${ADD_OUTPUT}\" | grep -q \"already exists\\|Remote.*exists\"; then
      echo \"⚠️  Remote \${INCUS_REMOTE_NAME} already exists (removal may have failed)\"
      echo \"  Verifying existing remote works...\"
      if sudo -u \${REMOTE_USER} incus list \${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
        echo \"✅ Existing remote \${INCUS_REMOTE_NAME} is working correctly\"
        ADD_RESULT=0
      else
        echo \"❌ Existing remote \${INCUS_REMOTE_NAME} exists but is not working\"
        echo \"   Error output: \${ADD_OUTPUT}\"
        echo \"   You may need to manually fix the remote:\"
        echo \"     sudo -u \${REMOTE_USER} incus remote remove \${INCUS_REMOTE_NAME}\"
        echo \"     sudo -u \${REMOTE_USER} incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL}\"
        exit 1
      fi
    # Check if we need to accept certificate fingerprint
    elif [ \${ADD_RESULT} -ne 0 ] || echo \"\${ADD_OUTPUT}\" | grep -q \"fingerprint\\|ok (y/n\"; then
      # Extract fingerprint from output
      FINGERPRINT=\$(echo \"\${ADD_OUTPUT}\" | grep -oE '[a-f0-9]{64}' | head -1 || echo \"\")
      
      if [ -n \"\${FINGERPRINT}\" ]; then
        # Use the fingerprint to accept the certificate
        set +e
        echo \"\${FINGERPRINT}\" | sudo -u \${REMOTE_USER} incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL} --token \"\${TRUST_TOKEN}\" 2>&1
        ADD_RESULT=\$?
        set -e
        if [ \${ADD_RESULT} -ne 0 ]; then
          # Check again if it's because remote already exists
          if echo \"\${ADD_OUTPUT}\" | grep -q \"already exists\\|Remote.*exists\"; then
            if sudo -u \${REMOTE_USER} incus list \${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
              echo \"✅ Remote \${INCUS_REMOTE_NAME} already exists and is working\"
              ADD_RESULT=0
            else
              echo \"❌ Failed to add remote with trust token and fingerprint\"
              echo \"   Error output: \${ADD_OUTPUT}\"
              exit 1
            fi
          else
            echo \"❌ Failed to add remote with trust token and fingerprint\"
            echo \"   Error output: \${ADD_OUTPUT}\"
            exit 1
          fi
        fi
      else
        # If no fingerprint found, try with 'y'
        set +e
        echo 'y' | sudo -u \${REMOTE_USER} incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL} --token \"\${TRUST_TOKEN}\" 2>&1
        ADD_RESULT=\$?
        set -e
        if [ \${ADD_RESULT} -ne 0 ]; then
          # Check again if it's because remote already exists
          if echo \"\${ADD_OUTPUT}\" | grep -q \"already exists\\|Remote.*exists\"; then
            if sudo -u \${REMOTE_USER} incus list \${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
              echo \"✅ Remote \${INCUS_REMOTE_NAME} already exists and is working\"
              ADD_RESULT=0
            else
              echo \"❌ Failed to add remote with trust token\"
              echo \"   Error output: \${ADD_OUTPUT}\"
              exit 1
            fi
          else
            echo \"❌ Failed to add remote with trust token\"
            echo \"   Error output: \${ADD_OUTPUT}\"
            exit 1
          fi
        fi
      fi
    fi
    
    # Verify the remote was actually added for the user
    if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | grep -q \"^\${INCUS_REMOTE_NAME},\" || \
       sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -q \"\${INCUS_REMOTE_NAME}\"; then
      echo \"✅ Remote \${INCUS_REMOTE_NAME} added successfully for user \${REMOTE_USER}\"
    else
      echo \"❌ Failed to add remote \${INCUS_REMOTE_NAME} for user \${REMOTE_USER}\"
      echo \"   Error output: \${ADD_OUTPUT}\"
      echo \"   You may need to add it manually:\"
      echo \"     incus remote add \${INCUS_REMOTE_NAME} \${INCUS_REMOTE_URL}\"
      exit 1
    fi
  "
else
  # Prompt for token or try without token (certificate-based auth)
  echo "  Adding remote (may prompt for trust token) for user ${REMOTE_USER}..."
  incus exec "${REMOTE}:${VM_NAME}" -- bash -c "
    set -euo pipefail
    
    # Initialize variables to avoid unbound variable errors
    ADD_OUTPUT=\"\"
    FINGERPRINT=\"\"
    REMOTE_USER=\"${REMOTE_USER}\"
    
    # Check if remote already exists for the user
    if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | grep -qE '^${INCUS_REMOTE_NAME}( |,)' || \
       sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -qE '^${INCUS_REMOTE_NAME}( |)' || \
       sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -q '${INCUS_REMOTE_NAME}'; then
      echo '⚠️  Remote ${INCUS_REMOTE_NAME} already exists for user \${REMOTE_USER}'
      # Test if it works
      if sudo -u \${REMOTE_USER} incus list ${INCUS_REMOTE_NAME}: --format csv > /dev/null 2>&1; then
        echo '✅ Existing remote ${INCUS_REMOTE_NAME} is working for user \${REMOTE_USER}'
        exit 0
      else
        echo '⚠️  Existing remote is not working, removing...'
        sudo -u \${REMOTE_USER} incus remote remove ${INCUS_REMOTE_NAME} 2>/dev/null || true
      fi
    fi
    
    # Try to add remote without token (certificate-based auth)
    echo 'Adding remote ${INCUS_REMOTE_NAME}...'
    
    # First, try to get the server certificate fingerprint
    # This allows us to accept it non-interactively
    set +e
    CERT_INFO=\$(timeout 10 openssl s_client -connect ${INCUS_SERVER_IP}:8443 -servername ${INCUS_SERVER_IP} </dev/null 2>/dev/null | openssl x509 -fingerprint -noout -sha256 2>/dev/null || echo \"\")
    if [ -n \"\${CERT_INFO}\" ]; then
      # Extract fingerprint (format: SHA256 Fingerprint=XX:XX:XX...)
      FINGERPRINT=\$(echo \"\${CERT_INFO}\" | grep -oE '[A-F0-9:]{95,}' | tr -d ':' | tr '[:upper:]' '[:lower:]' || echo \"\")
    fi
    set -e
    
    # Try to add remote and auto-accept certificate fingerprint
    set +e
    # Method 1: Try with 'y' to accept fingerprint
    ADD_OUTPUT=\$(printf 'y\\n' | timeout 30 sudo -u \${REMOTE_USER} incus remote add ${INCUS_REMOTE_NAME} ${INCUS_REMOTE_URL} 2>&1 || echo \"ADD_FAILED\")
    ADD_RESULT=\$?
    set -e
    
    # Check if the remote was added successfully
    if [ \${ADD_RESULT} -eq 0 ]; then
      # Verify it was actually added for the user
      if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | grep -qE '^${INCUS_REMOTE_NAME}( |,)' || \
         sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -qE '^${INCUS_REMOTE_NAME}( |)' || \
         sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -q '${INCUS_REMOTE_NAME}'; then
        echo '✅ Remote ${INCUS_REMOTE_NAME} added successfully for user \${REMOTE_USER}'
      else
        ADD_RESULT=1
      fi
    fi
    
    # If that failed, try with the fingerprint
    if [ \${ADD_RESULT} -ne 0 ] && [ -n \"\${FINGERPRINT}\" ] && [ \"\${FINGERPRINT}\" != \"\" ]; then
      echo '  Trying with certificate fingerprint...'
      set +e
      printf \"\${FINGERPRINT}\\n\" | timeout 30 sudo -u \${REMOTE_USER} incus remote add ${INCUS_REMOTE_NAME} ${INCUS_REMOTE_URL} 2>&1
      ADD_RESULT=\$?
      set -e
      
      if [ \${ADD_RESULT} -eq 0 ]; then
        if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | grep -qE '^${INCUS_REMOTE_NAME}( |,)' || \
           sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -qE '^${INCUS_REMOTE_NAME}( |)' || \
           sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -q '${INCUS_REMOTE_NAME}'; then
          echo '✅ Remote ${INCUS_REMOTE_NAME} added successfully (using fingerprint) for user \${REMOTE_USER}'
          ADD_RESULT=0
        fi
      fi
    fi
    
    # If still failed, try extracting fingerprint from error output
    if [ \${ADD_RESULT} -ne 0 ] && [ -n \"\${ADD_OUTPUT}\" ]; then
      EXTRACTED_FINGERPRINT=\$(echo \"\${ADD_OUTPUT}\" | grep -oE '[a-f0-9]{64}' | head -1 || echo \"\")
      if [ -n \"\${EXTRACTED_FINGERPRINT}\" ] && [ \"\${EXTRACTED_FINGERPRINT}\" != \"\${FINGERPRINT}\" ]; then
        echo '  Trying with extracted fingerprint...'
        set +e
        printf \"\${EXTRACTED_FINGERPRINT}\\n\" | timeout 30 sudo -u \${REMOTE_USER} incus remote add ${INCUS_REMOTE_NAME} ${INCUS_REMOTE_URL} 2>&1
        ADD_RESULT=\$?
        set -e
        
        if [ \${ADD_RESULT} -eq 0 ]; then
          if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | grep -qE '^${INCUS_REMOTE_NAME}( |,)' || \
             sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -qE '^${INCUS_REMOTE_NAME}( |)' || \
             sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -q '${INCUS_REMOTE_NAME}'; then
            echo '✅ Remote ${INCUS_REMOTE_NAME} added successfully (using extracted fingerprint) for user \${REMOTE_USER}'
            ADD_RESULT=0
          fi
        fi
      fi
    fi
    
    # If all methods failed, log warning but don't fail (VM can still function)
    if [ \${ADD_RESULT} -ne 0 ]; then
      echo '⚠️  Warning: Could not add Incus remote automatically'
      echo '   Error: not authorized (trust token required)'
      echo '   Error output: \${ADD_OUTPUT}'
      echo '   The VM will continue to function, but Incus commands from within the VM will not work.'
      echo '   To enable Incus remote access from the VM, generate a trust token on the server:'
      echo \"     incus config trust add ${CLIENT_NAME}\"
      echo '   Then manually add the remote from within the VM:'
      echo \"     incus remote add ${INCUS_REMOTE_NAME} ${INCUS_REMOTE_URL}\"
      # Don't exit - allow the process to continue
    fi
  "
fi

# Step 3.5: Verify remote was actually added (regardless of which path was taken)
echo ""
echo "Verifying remote was added for user ${REMOTE_USER}..."
REMOTE_ADDED=false
REMOTE_CHECK_OUTPUT=$(incus exec "${REMOTE}:${VM_NAME}" -- bash -c "
  set +e
  REMOTE_USER=\"${REMOTE_USER}\"
  REMOTE_NAME=\"${INCUS_REMOTE_NAME}\"
  # Check CSV format first (more reliable)
  if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | awk -F',' '{print \$1}' | sed 's/ (current)//' | grep -qE \"^\${REMOTE_NAME}\$\"; then
    echo 'REMOTE_EXISTS'
  # Fallback to table format
  elif sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -qE \"^\\| \${REMOTE_NAME} +\\|\"; then
    echo 'REMOTE_EXISTS'
  else
    echo 'REMOTE_MISSING'
  fi
  set -e
" 2>/dev/null || echo "REMOTE_MISSING")

if echo "${REMOTE_CHECK_OUTPUT}" | grep -q "REMOTE_EXISTS"; then
  REMOTE_ADDED=true
  echo "✅ Remote '${INCUS_REMOTE_NAME}' is configured"
else
  REMOTE_ADDED=false
  echo "❌ Error: Remote '${INCUS_REMOTE_NAME}' was not added successfully"
  echo ""
  echo "The Incus remote setup failed. The VM creation process will stop."
  echo ""
  echo "To fix this issue, you can try:"
  echo ""
  echo "  1. Generate a trust token on the Incus server:"
  echo "     incus config trust add ${CLIENT_NAME}"
  echo ""
  echo "  2. Add the remote from within the VM:"
  echo "     incus remote add ${INCUS_REMOTE_NAME} ${INCUS_REMOTE_URL}"
  echo ""
  echo "   Or if you have the trust token:"
  echo "     echo '<trust-token>' | incus remote add ${INCUS_REMOTE_NAME} ${INCUS_REMOTE_URL} --token -"
  echo ""
  exit 1
fi

# Step 4: Set the remote as default (always check, don't rely on REMOTE_ADDED variable)
echo ""
echo "Step 4: Setting ${INCUS_REMOTE_NAME} as default remote for user ${REMOTE_USER}..."
REMOTE_SET_RESULT=$(incus exec "${REMOTE}:${VM_NAME}" -- bash -c "
set -euo pipefail

REMOTE_USER=\"${REMOTE_USER}\"
REMOTE_NAME=\"${INCUS_REMOTE_NAME}\"

# Check if remote exists first for the user (re-check to be sure)
REMOTE_EXISTS=false
# Check CSV format first (more reliable)
if sudo -u \${REMOTE_USER} incus remote list --format csv 2>/dev/null | awk -F',' '{print \$1}' | sed 's/ (current)//' | grep -qE \"^\${REMOTE_NAME}\$\"; then
  REMOTE_EXISTS=true
# Fallback to table format
elif sudo -u \${REMOTE_USER} incus remote list 2>/dev/null | grep -qE \"^\\| \${REMOTE_NAME} +\\|\"; then
  REMOTE_EXISTS=true
fi

if [ \"\${REMOTE_EXISTS}\" = \"true\" ]; then
  # Switch to the remote as default for the user
  if sudo -u \${REMOTE_USER} incus remote switch \${REMOTE_NAME} 2>/dev/null; then
    echo \"✅ \${REMOTE_NAME} is now the default remote for user \${REMOTE_USER}\"
  else
    echo \"⚠️  Could not switch to \${REMOTE_NAME} as default, but it exists\"
  fi
  
  # Verify connection
  echo ''
  echo 'Verifying connection...'
  if sudo -u \${REMOTE_USER} incus list \${REMOTE_NAME}: --format csv > /dev/null 2>&1; then
    echo \"✅ Successfully connected to \${REMOTE_NAME}\"
    echo ''
    echo \"Remote configuration for user \${REMOTE_USER}:\"
    sudo -u \${REMOTE_USER} incus remote list | grep -E \"^\${REMOTE_NAME}|^NAME|^-\" || sudo -u \${REMOTE_USER} incus remote list
  else
    echo \"❌ Error: Could not connect to \${REMOTE_NAME}\"
    echo '   Verify the server is accessible and the trust token is correct'
    exit 1
  fi
else
  echo \"❌ Error: Remote \${REMOTE_NAME} was not added for user \${REMOTE_USER}\"
  echo '   The Incus remote setup failed. The VM creation process will stop.'
  exit 1
fi
" 2>&1)
REMOTE_SET_EXIT=$?

if [ ${REMOTE_SET_EXIT} -ne 0 ]; then
  echo "${REMOTE_SET_RESULT}"
  echo ""
  echo "❌ Failed to set up Incus remote. Exiting..."
  exit 1
else
  echo "${REMOTE_SET_RESULT}"
fi

# Step 5: Verify user can access Incus (if user was set)
echo ""
if [ -n "${RUNNER_USER:-}" ]; then
  echo "Step 5: Verifying Incus access for user ${RUNNER_USER}..."
  incus exec "${REMOTE}:${VM_NAME}" -- bash -c "
    set +e
    # Try to run incus command as the user to verify access
    if sudo -u ${RUNNER_USER} incus list --format csv >/dev/null 2>&1; then
      echo '✅ User ${RUNNER_USER} can access Incus'
    elif sudo -u ${RUNNER_USER} sg incus -c 'incus list --format csv' >/dev/null 2>&1; then
      echo '✅ User ${RUNNER_USER} can access Incus (with group activation)'
    else
      echo '⚠️  Warning: User ${RUNNER_USER} may not be able to access Incus yet'
      echo '   This is normal - group membership requires logging out and back in'
      echo '   Or run: newgrp incus'
    fi
    set -e
  " || true
fi

echo ""
echo "✅ Incus remote setup complete"
echo ""
echo "To use Incus from the VM, you can now run:"
echo "  incus list"
echo "  incus list ${INCUS_REMOTE_NAME}:"
echo ""
if [ -n "${RUNNER_USER:-}" ]; then
  echo "Note: If you get permission errors, log out and back in, or run:"
  echo "  newgrp incus"
fi

