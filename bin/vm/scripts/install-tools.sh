#!/usr/bin/env bash
# Install tools jq, Homebrew, aqua, docker, and windsor
set -euo pipefail

# Load environment variables from file if it exists
PROJECT_ROOT="${WINDSOR_PROJECT_ROOT:-$(pwd)}"
ENV_FILE="${PROJECT_ROOT}/.workspace/.vm-instantiate.env"
if [ -f "${ENV_FILE}" ]; then
  source "${ENV_FILE}"
fi

VM_NAME="${VM_NAME:-${VM_INSTANCE_NAME:-vm}}"
TEST_REMOTE_NAME="${TEST_REMOTE_NAME:-${INCUS_REMOTE_NAME}}"
CURRENT_USER="${USER:-$(whoami)}"
CURRENT_UID="${UID:-$(id -u)}"
CURRENT_GID="${GID:-$(id -g)}"
PROJECT_ROOT="${PROJECT_ROOT:-${WINDSOR_PROJECT_ROOT:-$(pwd)}}"
WORKSPACE_NAME=$(basename "${PROJECT_ROOT}")
INIT_PATH="/home/${CURRENT_USER}/${WORKSPACE_NAME}"

#==============================================================================
# Helper Functions
#==============================================================================

wait_for_vm_agent() {
  local max_retries=24
  local retry_count=0
  
  echo "  Waiting for VM agent to be ready..."
  
  while [ ${retry_count} -lt ${max_retries} ]; do
    if incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- true 2>/dev/null; then
      echo "  VM agent is ready"
      return 0
    fi
    
    if [ $((retry_count % 3)) -eq 0 ]; then
      local elapsed=$((retry_count * 5))
      echo "    Waiting for VM agent... [${retry_count}/${max_retries} attempts, ~${elapsed}s elapsed]"
    fi
    
    sleep 5
    retry_count=$((retry_count + 1))
  done
  
  local timeout_sec=$((max_retries * 5))
  echo "⚠️  Error: VM agent not ready after ${timeout_sec} seconds"
  echo "   The VM may still be booting. You can try running this step manually later."
  return 1
}

exec_in_vm() {
  local command="${1}"
  incus exec "${TEST_REMOTE_NAME}:${VM_NAME}" -- bash -c "${command}"
}

get_brew_prefix() {
  exec_in_vm "
    if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
      echo '/home/linuxbrew/.linuxbrew'
    elif [ -f /home/${CURRENT_USER}/.linuxbrew/bin/brew ]; then
      echo '/home/${CURRENT_USER}/.linuxbrew'
    else
      echo ''
    fi
  " | tr -d '\r\n'
}

is_command_installed() {
  local command="${1}"
  local user="${2:-}"
  
  if [ -n "${user}" ]; then
    exec_in_vm "sudo -u ${user} bash -c 'command -v ${command} >/dev/null 2>&1'" 2>/dev/null || return 1
  else
    exec_in_vm "command -v ${command} >/dev/null 2>&1" 2>/dev/null || return 1
  fi
}

#==============================================================================
# Installation Functions
#==============================================================================

install_homebrew() {
  echo "  Installing Homebrew..."
  
  exec_in_vm "
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    
    # Check if already installed
    if [ -d /home/linuxbrew/.linuxbrew ] && [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
      echo 'Homebrew already installed'
      exit 0
    fi
    
    # Install dependencies (including libraries needed for Helm/Flux/Kubernetes operations)
    apt-get update -qq
    apt-get install -y -qq build-essential curl file git libssl3 ca-certificates gnupg lsb-release > /dev/null 2>&1
    
    # Create directory with proper permissions
    mkdir -p /home/linuxbrew/.linuxbrew
    chown -R ${CURRENT_USER}:${CURRENT_GID} /home/linuxbrew 2>/dev/null || true
    
    # Download installer with retry logic
    MAX_RETRIES=3
    RETRY_COUNT=0
    while [ \${RETRY_COUNT} -lt \${MAX_RETRIES} ]; do
      if curl -fsSL --connect-timeout 30 --max-time 60 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/brew-install.sh; then
        break
      fi
      RETRY_COUNT=\$((RETRY_COUNT + 1))
      if [ \${RETRY_COUNT} -lt \${MAX_RETRIES} ]; then
        echo \"Retrying Homebrew installer download (attempt \${RETRY_COUNT}/\${MAX_RETRIES})...\"
        sleep 5
      else
        echo \"⚠️  Failed to download Homebrew installer after \${MAX_RETRIES} attempts\"
        exit 1
      fi
    done
    chmod +x /tmp/brew-install.sh
    
    # Source SSH agent if available
    if [ -f /home/${CURRENT_USER}/.ssh/agent_env ]; then
      . /home/${CURRENT_USER}/.ssh/agent_env
    fi
    
    # Create wrapper script
    cat > /tmp/brew-install-wrapper.sh << 'BREWWRAPEOF'
#!/bin/bash
set +e
set +u
export DEBIAN_FRONTEND=noninteractive
export NONINTERACTIVE=1

# Environment variables to help with network timeouts
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ANALYTICS=1
# Increase curl timeouts for slow connections
export CURL_CONNECT_TIMEOUT=60
export CURL_MAX_TIME=300

# Temporarily use HTTPS for git to avoid SSH passphrase prompts
git config --global --unset url.\"git@github.com:\".insteadOf 2>/dev/null || true
git config --global --unset url.\"ssh://git@github.com/\".insteadOf 2>/dev/null || true
git config --global url.\"https://github.com/\".insteadOf \"git@github.com:\" 2>/dev/null || true
git config --global url.\"https://github.com/\".insteadOf \"ssh://git@github.com/\" 2>/dev/null || true

    # Test network connectivity before running installer
    echo \"Checking network connectivity to GitHub...\"
    if ! curl -fsSL --connect-timeout 10 --max-time 15 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh > /dev/null 2>&1; then
      echo \"⚠️  Warning: Network connectivity test failed. This may cause installation issues.\"
      echo \"   Continuing anyway...\"
    else
      echo \"✅ Network connectivity OK\"
    fi

    # Run installer with progress visible
    echo \"Running Homebrew installer...\"
    INSTALL_EXIT=1
    /tmp/brew-install.sh < /dev/null 2>&1 | tee /tmp/brew-install-output.log
    INSTALL_EXIT=\${PIPESTATUS[0]}

    # Show errors if any
    if grep -qiE \"Error|Failed\" /tmp/brew-install-output.log 2>/dev/null; then
      echo \"⚠️  Errors detected:\"
      grep -iE \"Error|Failed\" /tmp/brew-install-output.log | head -10
    fi

    # Check for success
    if grep -q \"Installation successful\" /tmp/brew-install-output.log 2>/dev/null; then
      echo \"==> Installation successful\"
      echo \"Homebrew installed successfully\"
    elif [ \"\${INSTALL_EXIT:-1}\" -eq 0 ]; then
      echo \"Homebrew installed successfully\"
    else
      echo \"⚠️  Homebrew installation failed (exit code: \${INSTALL_EXIT:-1})\"
      echo \"Last 30 lines of output:\"
      tail -30 /tmp/brew-install-output.log
      exit 1
    fi

# Restore git SSH config
git config --global --unset url.\"https://github.com/\".insteadOf 2>/dev/null || true
git config --global url.\"git@github.com:\".insteadOf \"https://github.com/\" 2>/dev/null || true
BREWWRAPEOF
    
    chmod +x /tmp/brew-install-wrapper.sh
    chown ${CURRENT_USER}:${CURRENT_GID} /tmp/brew-install-wrapper.sh 2>/dev/null || true
    
    # Run as user
    sudo -u ${CURRENT_USER} -i /tmp/brew-install-wrapper.sh || {
      echo \"❌ Homebrew installation failed\"
      rm -f /tmp/brew-install.sh /tmp/brew-install-wrapper.sh
      exit 1
    }
    
    rm -f /tmp/brew-install.sh /tmp/brew-install-wrapper.sh
    
    # Verify Homebrew is actually installed
    if [ ! -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
      echo \"❌ Homebrew installation completed but brew binary not found\"
      exit 1
    fi
    
    # Add Homebrew to PATH in .bashrc if not already present
    sudo -u ${CURRENT_USER} bash -c '
      if [ -f /home/linuxbrew/.linuxbrew/bin/brew ] && ! grep -q \"linuxbrew\" ~/.bashrc 2>/dev/null; then
        echo \"\" >> ~/.bashrc
        echo \"# Add Homebrew to PATH\" >> ~/.bashrc
        echo \"eval \\\"\\\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\\\" 2>/dev/null || true\" >> ~/.bashrc
      fi
    ' || true
  " || {
    echo "❌ Homebrew installation failed - Homebrew is required. Stopping installation."
    exit 1
  }
}

install_aqua() {
  echo "  Installing aqua package manager..."
  
  # Check if already installed
  if exec_in_vm "sudo -u ${CURRENT_USER} bash -c 'command -v aqua >/dev/null 2>&1'" 2>/dev/null; then
    echo '✅ aqua already installed'
    return 0
  fi
  
  # Homebrew is required - check it's available
  local brew_prefix
  brew_prefix=$(get_brew_prefix)
  
  if [ -z "${brew_prefix}" ]; then
    echo '❌ Homebrew is required but not found. Cannot install aqua.'
    exit 1
  fi
  
  echo '  Installing aqua via Homebrew...'
  
  exec_in_vm "
    sudo -u ${CURRENT_USER} env BREW_PREFIX='${brew_prefix}' bash -c '
      set -eu
      cd ~
      export PATH=\"\${BREW_PREFIX}/bin:\${PATH}\"
      
      if [ -f \"\${BREW_PREFIX}/bin/brew\" ]; then
        # Try to evaluate brew shellenv, but suppress error messages if it fails
        eval \"\$(\\\"\${BREW_PREFIX}/bin/brew\\\" shellenv 2>/dev/null)\" 2>/dev/null || {
          # If shellenv fails, just add to PATH manually
          export PATH=\"\${BREW_PREFIX}/bin:\${BREW_PREFIX}/sbin:\${PATH}\"
        }
        brew install aqua || {
          echo \"❌ Failed to install aqua via Homebrew\"
          exit 1
        }
        
        if command -v aqua >/dev/null 2>&1 || [ -f \"\${BREW_PREFIX}/bin/aqua\" ]; then
          echo \"✅ aqua installed successfully via Homebrew\"
          aqua --version || true
          
          # Add aqua PATH to .bashrc if not already present (must be before Windsor hook)
          if ! grep -q \"AQUA_ROOT_DIR\|aquaproj-aqua.*bin\" ~/.bashrc 2>/dev/null; then
            echo \"\" >> ~/.bashrc
            echo \"# Add Aqua bin directory to PATH (for Aqua-installed tools)\" >> ~/.bashrc
            echo \"export PATH=\\\"\\\${AQUA_ROOT_DIR:-\\\${XDG_DATA_HOME:-\\\$HOME/.local/share}/aquaproj-aqua}/bin:\\\$PATH\\\"\" >> ~/.bashrc
            echo \"✅ Aqua PATH added to ~/.bashrc\"
          fi
          
          exit 0
        else
          echo \"❌ aqua not found after Homebrew installation\"
          exit 1
        fi
      else
        echo \"❌ brew binary not found at \${BREW_PREFIX}/bin/brew\"
        exit 1
      fi
    '
  " || {
    echo "❌ Failed to install aqua - Homebrew is required"
    exit 1
  }
}

install_jq() {
  echo "  Installing jq..."
  
  exec_in_vm "
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    
    if command -v jq >/dev/null 2>&1; then
      echo '✅ jq already installed'
      exit 0
    fi
    
    apt-get update -qq
    apt-get install -y -qq jq > /dev/null 2>&1
    echo '✅ jq installed successfully'
  "
}

install_docker() {
  echo "  Installing Docker..."
  
  exec_in_vm "
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    
    if command -v docker >/dev/null 2>&1; then
      echo '✅ Docker already installed'
      exit 0
    fi
    
    # Install prerequisites
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl > /dev/null 2>&1
    
    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    . /etc/os-release
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \${VERSION_CODENAME} stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    
    # Add user to docker group
    usermod -aG docker ${CURRENT_USER} 2>/dev/null || true
    
    # Start and enable service
    systemctl start docker 2>/dev/null || true
    systemctl enable docker 2>/dev/null || true
    
    echo '✅ Docker installed successfully'
  "
}

configure_br_netfilter() {
  echo "  Configuring br_netfilter kernel module..."
  
  exec_in_vm "
    set -euo pipefail
    
    # Load br_netfilter module if not already loaded (required for Kubernetes networking / Flannel CNI)
    if ! lsmod | grep -q br_netfilter; then
      modprobe br_netfilter 2>/dev/null || echo \"⚠️  Warning: Failed to load br_netfilter module\"
    fi
    
    # Make module load on boot
    if [ ! -f /etc/modules-load.d/br_netfilter.conf ]; then
      echo 'br_netfilter' > /etc/modules-load.d/br_netfilter.conf
      chmod 644 /etc/modules-load.d/br_netfilter.conf
    fi
    
    # Set sysctls for bridge netfilter
    if [ ! -f /etc/sysctl.d/99-kubernetes.conf ]; then
      echo 'net.bridge.bridge-nf-call-iptables=1' > /etc/sysctl.d/99-kubernetes.conf
      echo 'net.bridge.bridge-nf-call-ip6tables=1' >> /etc/sysctl.d/99-kubernetes.conf
      chmod 644 /etc/sysctl.d/99-kubernetes.conf
    else
      if ! grep -q 'net.bridge.bridge-nf-call-iptables' /etc/sysctl.d/99-kubernetes.conf 2>/dev/null; then
        echo 'net.bridge.bridge-nf-call-iptables=1' >> /etc/sysctl.d/99-kubernetes.conf
      fi
      if ! grep -q 'net.bridge.bridge-nf-call-ip6tables' /etc/sysctl.d/99-kubernetes.conf 2>/dev/null; then
        echo 'net.bridge.bridge-nf-call-ip6tables=1' >> /etc/sysctl.d/99-kubernetes.conf
      fi
    fi
    
    # Apply sysctls immediately
    sysctl --system > /dev/null 2>&1 || true
    
    if lsmod | grep -q br_netfilter; then
      echo '✅ br_netfilter module loaded'
    else
      echo '⚠️  Warning: br_netfilter module not loaded (may not be available in kernel)'
    fi
    
    if [ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
      IPTABLES_VAL=\$(cat /proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null || echo '0')
      if [ \"\${IPTABLES_VAL}\" = \"1\" ]; then
        echo '✅ br_netfilter sysctls configured'
      else
        echo '⚠️  Warning: sysctls not set correctly'
      fi
    else
      echo '⚠️  Warning: /proc/sys/net/bridge/bridge-nf-call-iptables not found (module may not be available)'
    fi
  " || echo "⚠️  Warning: br_netfilter configuration may have failed"
}

install_windsor() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Install Windsor"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  local brew_prefix
  brew_prefix=$(get_brew_prefix)
  
  if [ -z "${brew_prefix}" ]; then
    echo "❌ Homebrew not found, cannot install Windsor"
    exit 1
  fi
  
  exec_in_vm "
    set -euo pipefail
    
    WINDSOR_INSTALLED=0
    sudo -u ${CURRENT_USER} bash -c '
      set -eu
      cd ~
      
      BREW_PREFIX=\"${brew_prefix}\"
      
      # Verify brew binary exists
      if [ ! -f \"\${BREW_PREFIX}/bin/brew\" ]; then
        echo \"❌ brew binary not found at \${BREW_PREFIX}/bin/brew\"
        exit 1
      fi
      
      # Configure git to use HTTPS INSTEAD of SSH BEFORE any git operations
      # This must be done early and globally to affect all git operations including Homebrew
      # Remove any existing SSH-based URL rewrites first
      git config --global --unset-all url.\"git@github.com:\".insteadOf 2>/dev/null || true
      git config --global --unset-all url.\"ssh://git@github.com/\".insteadOf 2>/dev/null || true
      # Add HTTPS URL rewrite
      git config --global url.\"https://github.com/\".insteadOf \"git@github.com:\" 2>/dev/null || true
      git config --global url.\"https://github.com/\".insteadOf \"ssh://git@github.com/\" 2>/dev/null || true
      
      # Set environment variables to prevent SSH prompts and Homebrew auto-update
      export GIT_TERMINAL_PROMPT=0
      export HOMEBREW_NO_AUTO_UPDATE=1
      export HOMEBREW_NO_INSTALL_CLEANUP=1
      
      # Set up Homebrew PATH - ensure brew is available
      export PATH=\"\${BREW_PREFIX}/bin:\${BREW_PREFIX}/sbin:\${PATH}\"
      
      # Try to run shellenv to get full Homebrew environment
      if [ -f \"\${BREW_PREFIX}/bin/brew\" ]; then
        eval \"\$(\\\"\${BREW_PREFIX}/bin/brew\\\" shellenv 2>/dev/null || true)\"
      fi
      
      # Verify brew is accessible
      if ! command -v brew >/dev/null 2>&1; then
        echo \"❌ brew command not found in PATH after setup\"
        exit 1
      fi
      
      # Install Windsor - replicate manual installation exactly
      echo \"  Tapping windsorcli/cli...\"
      if ! brew tap windsorcli/cli; then
        echo \"❌ Failed to tap windsorcli/cli\"
        exit 1
      fi
      echo \"  ✅ windsorcli/cli tapped successfully\"
      
      echo \"  Installing windsor...\"
      # Write to file to avoid broken pipe when streaming through incus exec (common with large formulae)
      WINDSOR_LOG=\"/tmp/windsor-install.log\"
      MAX_RETRIES=2
      RETRY=0
      while [ \${RETRY} -le \${MAX_RETRIES} ]; do
        if brew install windsor > \"\${WINDSOR_LOG}\" 2>&1; then
          break
        fi
        RETRY=\$((RETRY + 1))
        if [ \${RETRY} -le \${MAX_RETRIES} ]; then
          echo \"  ⚠️  Windsor install failed (attempt \${RETRY}/\${MAX_RETRIES}), retrying in 10s...\"
          tail -15 \"\${WINDSOR_LOG}\" || true
          sleep 10
        else
          echo \"❌ Failed to install Windsor via Homebrew after \${MAX_RETRIES} retries\"
          echo \"   Last 30 lines of log:\"
          tail -30 \"\${WINDSOR_LOG}\" || true
          rm -f \"\${WINDSOR_LOG}\"
          exit 1
        fi
      done
      rm -f \"\${WINDSOR_LOG}\"
      echo \"  ✅ Windsor package installed successfully\"
      
      # Verify installation - ensure windsor binary actually exists
      # Re-evaluate brew environment to ensure PATH is correct
      eval \"\$(brew shellenv 2>/dev/null || true)\"
      export PATH=\"\${BREW_PREFIX}/bin:\${BREW_PREFIX}/sbin:\${PATH}\"
      
      # Check if windsor binary exists
      if [ ! -f \"\${BREW_PREFIX}/bin/windsor\" ]; then
        echo \"❌ Windsor binary not found at \${BREW_PREFIX}/bin/windsor after installation\"
        echo \"   Checking Cellar location...\"
        WINDSOR_CELLAR=\$(find \${BREW_PREFIX}/Cellar -name windsor -type f 2>/dev/null | head -1)
        if [ -n \"\${WINDSOR_CELLAR}\" ]; then
          echo \"   Found in Cellar: \${WINDSOR_CELLAR}\"
          echo \"   This may be a Homebrew linking issue\"
        else
          echo \"   No windsor binary found anywhere\"
        fi
        exit 1
      fi
      
      # Verify windsor is accessible via command -v
      if ! command -v windsor >/dev/null 2>&1; then
        echo \"⚠️  Warning: Windsor binary exists but not accessible via command -v\"
        echo \"   Binary exists at: \${BREW_PREFIX}/bin/windsor\"
        echo \"   Current PATH: \${PATH}\"
        # Try to add it explicitly
        export PATH=\"\${BREW_PREFIX}/bin:\${PATH}\"
      fi
      
      # Final verification - windsor must be accessible
      if command -v windsor >/dev/null 2>&1; then
        echo \"✅ Windsor installed successfully and found in PATH\"
        echo \"Windsor version:\"
        windsor version 2>&1 || echo \"  (version command had issues, but windsor is installed)\"
      else
        echo \"❌ Windsor binary exists at \${BREW_PREFIX}/bin/windsor but is not accessible\"
        echo \"   This indicates a PATH configuration issue\"
        exit 1
      fi
      
      # Ensure Homebrew is in .bashrc (should already be there, but double-check)
      if [ -f /home/linuxbrew/.linuxbrew/bin/brew ] && ! grep -q \"linuxbrew.*shellenv\" ~/.bashrc 2>/dev/null; then
        echo \"\" >> ~/.bashrc
        echo \"# Add Homebrew to PATH\" >> ~/.bashrc
        echo \"eval \\\"\\\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\\\" 2>/dev/null || true\" >> ~/.bashrc
      fi
      
      # Add Windsor hook to .bashrc if not already present (must be at the end, after all PATH exports)
      if ! grep -q \"windsor hook bash\" ~/.bashrc 2>/dev/null; then
        echo \"\" >> ~/.bashrc
        echo \"# Windsor CLI hook (must be after prompt extensions like rvm, git-prompt)\" >> ~/.bashrc
        echo \"eval \\\"\\\$(windsor hook bash)\\\"\" >> ~/.bashrc
        echo \"✅ Windsor hook added to ~/.bashrc\"
      else
        echo \"✅ Windsor hook already present in ~/.bashrc\"
      fi
    ' && {
      echo \"✅ Windsor installation completed\"
      # Restore normal git behavior (use SSH) after successful installation
      sudo -u ${CURRENT_USER} bash -c 'git config --global --unset-all url.\"https://github.com/\".insteadOf 2>/dev/null || true' || true
    } || {
      echo \"❌ Windsor installation failed\"
      exit 1
    }
  " || {
    echo "❌ Windsor installation failed"
    exit 1
  }
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
  # Wait for VM to be ready
  wait_for_vm_agent || exit 1
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Step: Install Tools on VM"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Install tools - Homebrew is required
  install_homebrew || {
    echo "❌ Homebrew installation failed. Stopping installation."
    exit 1
  }
  
  install_aqua || {
    echo "❌ Failed to install required tools. Stopping installation."
    exit 1
  }
  
  install_jq || {
    echo "❌ Failed to install required tools. Stopping installation."
    exit 1
  }
  
  install_docker || {
    echo "❌ Failed to install required tools. Stopping installation."
    exit 1
  }
  
  configure_br_netfilter
  
  echo "✅ Tools setup completed"
  
  # Install Windsor
  install_windsor
}

main "$@"
