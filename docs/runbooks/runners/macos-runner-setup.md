# macOS GitHub Runner Setup

This guide covers setting up a macOS-based GitHub Actions runner on Apple Silicon (ARM64) Mac devices.


## Prerequisites

- Apple Silicon Mac (ARM64)
- macOS installed
- GitHub repository or organization access
- Admin access on the Mac

## Setup Steps

### 1. Prepare macOS System

1. **Install Homebrew**
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Install Development Tools**
   ```bash
   # Install Xcode Command Line Tools
   xcode-select --install
   
   # Install Docker Desktop for Mac
   brew install --cask docker
   
   # Install Git
   brew install git
   ```

### 2. Install GitHub Actions Runner

1. **Get Runner Token**
   - Navigate to GitHub repository/organization
   - Go to **Settings** → **Actions** → **Runners**
   - Click **New self-hosted runner**

2. **Download and Configure Runner**
   ```bash
   # Create directory
   mkdir ~/actions-runner && cd ~/actions-runner
   
   # Download runner for ARM64
   curl -o actions-runner-osx-arm64-2.XXX.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.XXX.0/actions-runner-osx-arm64-2.XXX.0.tar.gz
   
   # Extract and configure
   tar xzf ./actions-runner-osx-arm64-2.XXX.0.tar.gz
   ./config.sh --url https://github.com/<org-or-user>/<repo> --token <token>
   ```

3. **Install as Service**
   ```bash
   ./svc.sh install
   ./svc.sh start
   ./svc.sh status
   ```

### 3. Configure System Permissions

1. **Grant Accessibility Permissions**
   - System Preferences → Security & Privacy → Privacy → Accessibility
   - Add Terminal/iTerm if needed

2. **Grant Full Disk Access**
   - System Preferences → Security & Privacy → Privacy → Full Disk Access
   - Add Terminal/iTerm if needed

## Verification

- Check runner status in GitHub: **Settings** → **Actions** → **Runners**
- Runner should appear with green status
- Test with a simple GitHub Actions workflow
