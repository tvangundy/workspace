# Ubuntu GitHub Runner Setup

This guide covers setting up Ubuntu-based GitHub Actions runners on Raspberry Pi (ARM64) or Intel NUC (x86_64) devices.

## Prerequisites

- Raspberry Pi or Intel NUC hardware
- USB drive for boot media
- GitHub repository or organization access
- Network connectivity

## Setup Steps

### Step 1. Install Ubuntu Server

1. **Download Ubuntu Server**
   - Use [Ubuntu 24.04 Server](https://releases.ubuntu.com/noble/)
   - Select appropriate architecture (ARM64 for RPI, x86_64 for NUC)

2. **Create Boot Media**
   - Use [Balena Etcher](https://etcher.balena.io/) to write image to USB
   - Boot from USB drive

3. **Install Ubuntu Server**
   - During installation, select these server snaps:

     - `openssh`
     - `docker`
     - `mosquitto`
     - `powershell`
     - `aws-cli`
     - `google-cloud-sdk`
     - `prometheus`

### Step 2. Post-Installation Configuration

```bash
# System updates
sudo apt update -y
sudo apt upgrade -y

# Install additional packages
sudo apt install -y \
  build-essential \
  git \
  curl \
  wget \
  python3 \
  python3-pip \
  nodejs \
  npm \
  docker.io \
  default-jre \
  default-jdk \
  unzip \
  software-properties-common \
  ansible

# Configure Docker
sudo usermod -aG docker <username>
su - <username>
docker ps
```

### Step 3. Install GitHub Actions Runner

1. **Get Runner Token**
   - Navigate to GitHub repository/organization
   - Go to **Settings** → **Actions** → **Runners**
   - Click **New self-hosted runner**

2. **Download and Configure Runner**
   ```bash
   mkdir ~/actions-runner && cd ~/actions-runner
   
   # Download runner (select appropriate architecture)
   # ARM64:
   curl -o actions-runner-linux-arm64-2.XXX.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.XXX.0/actions-runner-linux-arm64-2.XXX.0.tar.gz
   
   # x86_64:
   curl -o actions-runner-linux-x64-2.XXX.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.XXX.0/actions-runner-linux-x64-2.XXX.0.tar.gz
   
   # Extract and configure
   tar xzf ./actions-runner-linux-*.tar.gz
   ./config.sh --url https://github.com/<org-or-user>/<repo> --token <token>
   ```

3. **Install as Service**
   ```bash
   sudo ./svc.sh install <username>
   sudo ./svc.sh start
   ```

## Verification

- Check runner status in GitHub: **Settings** → **Actions** → **Runners**
- Runner should appear with green status
- Test with a simple GitHub Actions workflow

