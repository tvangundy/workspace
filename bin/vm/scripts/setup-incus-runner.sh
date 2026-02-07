#!/usr/bin/env bash
# Installs Incus client on the VM and adds users to the incus group.
# The Incus remote is configured for the runner user in setup-runner-user (vm:instantiate --runner).
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Error: VM name is required"
  echo "Usage: $0 <vm-name>"
  exit 1
fi

VM_NAME="${1}"
# INCUS_REMOTE_NAME and INCUS_REMOTE_IP come from vm:instantiate command line (see parse-args.sh / .workspace/.vm-instantiate.env)
INCUS_REMOTE_NAME="${INCUS_REMOTE_NAME:-}"
RUNNER_USER="${RUNNER_USER:-}"

if [ -z "${INCUS_REMOTE_IP:-}" ]; then
  echo "Error: INCUS_REMOTE_IP is required. Pass <remote-ip> to vm:instantiate." >&2
  exit 1
fi
if [ -z "${INCUS_REMOTE_NAME:-}" ]; then
  echo "Error: INCUS_REMOTE_NAME is required. Pass <remote-name> to vm:instantiate." >&2
  exit 1
fi
INCUS_REMOTE_URL="https://${INCUS_REMOTE_IP}:8443"

echo "Setting up Incus client and remote on ${INCUS_REMOTE_NAME}:${VM_NAME}..."
echo "  Remote IP: ${INCUS_REMOTE_IP}"
echo "  Remote name: ${INCUS_REMOTE_NAME}"
echo "  Remote URL: ${INCUS_REMOTE_URL}"
echo ""

# Step 1: Install Incus client if not already installed
echo "Step 1: Checking Incus client installation..."
incus exec "${INCUS_REMOTE_NAME}:${VM_NAME}" -- bash -c "
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
  fi
else
  echo '⚠️  Warning: incus group not found - Incus may not be properly installed'
fi

# Add remote using trust token from /etc/environment (set by set-incus-remote-env)
if [ -f /etc/environment ]; then
  set +u
  source /etc/environment 2>/dev/null || true
  set -u
fi
if [ -n \"\${INCUS_REMOTE_TOKEN:-}\" ] && [ -n \"\${INCUS_REMOTE_NAME:-}\" ] && [ -n \"\${INCUS_REMOTE_IP:-}\" ] && [ -n \"\${DETECTED_USER:-}\" ]; then
  REMOTE_URL=\"https://\${INCUS_REMOTE_IP}:8443\"
  REMOTE_EXISTS=false
  if sudo -u \"\${DETECTED_USER}\" incus remote list 2>/dev/null | grep -q \"\${INCUS_REMOTE_NAME}\"; then
    REMOTE_EXISTS=true
  fi
  if [ \"\${REMOTE_EXISTS}\" = \"true\" ]; then
    echo \"✅ Remote \${INCUS_REMOTE_NAME} already configured for \${DETECTED_USER}\"
  else
    set +e
    sudo -u \"\${DETECTED_USER}\" sg incus -c \"incus remote add \\\"\${INCUS_REMOTE_NAME}\\\" \\\"\${REMOTE_URL}\\\" --accept-certificate --token \\\"\${INCUS_REMOTE_TOKEN}\\\"\" 2>&1
    ADD_RESULT=\$?
    set -e
    if [ \${ADD_RESULT} -eq 0 ]; then
      echo \"✅ Remote \${INCUS_REMOTE_NAME} added for \${DETECTED_USER}\"
    else
      echo \"⚠️  Warning: Could not add remote \${INCUS_REMOTE_NAME} for \${DETECTED_USER} (token may be invalid)\"
    fi
  fi
  # Set the remote as default so incus list shows instances on the host server (not empty local)
  if sudo -u \"\${DETECTED_USER}\" incus remote list 2>/dev/null | grep -q \"\${INCUS_REMOTE_NAME}\"; then
    sudo -u \"\${DETECTED_USER}\" incus remote switch \"\${INCUS_REMOTE_NAME}\" 2>/dev/null || true
    echo \"✅ Remote \${INCUS_REMOTE_NAME} set as default\"
  fi
fi
"

# Step 2: Summary (remote added above when INCUS_REMOTE_TOKEN was set)
echo ""
echo "Step 2: Incus client and remote"
echo "✅ Setup complete"

