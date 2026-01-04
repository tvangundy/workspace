# GitHub Runners on IncusOS VMs

This guide walks you through setting up GitHub Actions runners using Ubuntu virtual machines on an [IncusOS](https://linuxcontainers.org/incus-os/docs/main/getting-started/) system. You'll create Ubuntu VMs and configure them as self-hosted GitHub Actions runners.

## Overview

Setting up GitHub runners on IncusOS VMs involves:

1. **Initializing workspace**: Setting up the Windsor workspace and context
2. **Setting up runner in GitHub**: Configuring the runner in GitHub to obtain registration token and repository URL
3. **Setting environment variables**: Configuring workspace variables for runner setup
4. **Storing runner token as secret**: Using SOPS to securely store the GitHub runner token
5. **Verifying configuration**: Verifying environment variables and secrets are present
6. **Configuring network**: Setting up direct network attachment for VMs to get IP addresses (if not already done)
7. **Launching Ubuntu VM**: Creating and configuring the Ubuntu runner VM
8. **Initializing runner VM**: Installing dependencies and setting up the runner user
9. **Installing GitHub Actions runner**: Installing and configuring the runner service
10. **Managing runners**: Configuring auto-start, updates, and maintenance

This approach allows you to run GitHub Actions workflows on self-hosted infrastructure, providing more control over the execution environment and potentially reducing costs for compute-intensive workflows.

## Prerequisites

- Incus client installed on your local machine
- IncusOS server set up and accessible (see [IncusOS Setup](incusos-setup.md))
- Incus remote configured (see [IncusOS Setup - Step 7](incusos-setup.md#step-7-connect-to-incus-server))
- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))
- GitHub repository or organization access (admin permissions to add self-hosted runners)
- Sufficient resources: At least 4GB RAM and 50GB storage per VM on the IncusOS host

## System Requirements

Each runner VM will require:

- **Ubuntu runner VM**: Minimum 2GB RAM, 20GB disk (4GB RAM, 40GB disk recommended)
- **Network**: The VM needs network connectivity to reach GitHub and your repositories

## Step 1: Set Up Runner in GitHub

Before configuring environment variables, you need to set up the runner in GitHub to obtain the required configuration values:

1. **Navigate to GitHub**:
   - For a **repository-level runner**: Go to your repository → **Settings** → **Actions** → **Runners** → **New self-hosted runner**
   - For an **organization-level runner**: Go to your organization → **Settings** → **Actions** → **Runners** → **New self-hosted runner**

2. **Select Platform**:
   - Select **Linux** and **x64** (or ARM64 if using ARM VMs)
   - The setup page will display:
     - The repository/organization URL (e.g., `https://github.com/tvangundy/workspace`)
     - A registration token (a long alphanumeric string)

3. **Copy the Information**:
   - Copy the repository URL shown on the page
   - Copy the registration token
   - **Important**: The token expires after a short time (typically 1 hour), so you'll need to use it promptly

**Note**: Repository-level runners are only available to that specific repository. Organization-level runners are available to all repositories in the organization. Choose based on your needs.

## Step 2: Set Environment Variables

Use the information you obtained from GitHub (repository URL and token) to configure the environment variables below.

Add these lines to `./contexts/github-runners/windsor.yaml`:

```yaml
environment:
  # Incus remote configuration
  INCUS_REMOTE_NAME: "nuc"
  INCUS_REMOTE_IP_0: "192.168.2.101"

  INCUS_NETWORK_NAME: "eno1"
  
  # Ubuntu runner VM configuration
  UBUNTU_GITHUB_RUNNER_0_NAME: "github-runner-ubuntu"
  UBUNTU_GITHUB_RUNNER_0_MEMORY: "8GB"
  UBUNTU_GITHUB_RUNNER_0_CPU: "4"
  UBUNTU_GITHUB_RUNNER_0_AUTOSTART: "true"
  
  # Runner user configuration
  RUNNER_USER: "runner"
  RUNNER_HOME: "/home/runner"
  
  # GitHub Actions runner configuration
  GITHUB_RUNNER_REPO_URL: "https://github.com/<org-or-user>/<repo>"
  # GITHUB_RUNNER_TOKEN: Stored as a secret (see Step 4 below)
  # GITHUB_RUNNER_VERSION: "2.XXX.X"  # Optional: defaults to latest if not specified
  # GITHUB_RUNNER_ARCH: "x64"          # Optional: defaults to "x64" (or "arm64" for ARM VMs)
```

**Note**: Replace the placeholder values with your actual configuration:

- `INCUS_REMOTE_NAME`: The name of your Incus remote (from `incus remote list`)
- `INCUS_REMOTE_IP_0`: The IP address of your IncusOS host
- `INCUS_NETWORK_NAME`: Your physical network interface name (e.g., `eno1`, `eth0`, `enp5s0`)
- `UBUNTU_GITHUB_RUNNER_0_NAME`: Name for your Ubuntu runner VM
- `UBUNTU_GITHUB_RUNNER_0_MEMORY`: Memory allocation for Ubuntu runner VM (e.g., `"8GB"` - 8GB minimum recommended for optimal performance, 16GB for Docker-heavy workloads)
- `UBUNTU_GITHUB_RUNNER_0_CPU`: CPU count for Ubuntu runner VM (e.g., `"4"` - 4 cores minimum recommended, 8 cores for parallel builds)
- `UBUNTU_GITHUB_RUNNER_0_AUTOSTART`: Auto-start setting for Ubuntu runner VM (`"true"` or `"false"`)
- `RUNNER_USER`: The user name for the runner (e.g., `"runner"`)
- `RUNNER_HOME`: The home directory path for the runner user (e.g., `"/home/runner"`)
- `GITHUB_RUNNER_REPO_URL`: The GitHub repository or organization URL (obtained from the GitHub runner setup page above)
- `GITHUB_RUNNER_TOKEN`: The runner registration token from GitHub - **stored as a secret** (see Step 4 below)
- `GITHUB_RUNNER_VERSION`: (Optional) Specific runner version (e.g., `"2.XXX.X"`). If not specified, the latest version will be used
- `GITHUB_RUNNER_ARCH`: (Optional) Runner architecture (`"x64"` or `"arm64"`). Defaults to `"x64"`

### Additional Configuration Notes

**Runner Version** (Optional):
   - The task will automatically use the latest version if `GITHUB_RUNNER_VERSION` is not specified
   - To use a specific version, check the [GitHub Actions Runner releases](https://github.com/actions/runner/releases) page
   - Use the version number without the `v` prefix (e.g., `"2.311.0"`)

**Runner Architecture** (Optional):
   - For x86_64/AMD64 VMs: Use `"x64"` (default)
   - For ARM64 VMs: Use `"arm64"`

## Step 3: Store GitHub Runner Token as a Secret

The `GITHUB_RUNNER_TOKEN` should be stored as an encrypted secret using SOPS rather than in the environment variables. This keeps the sensitive token secure. Follow these steps:

### Step 4.1: Generate the Secrets File

If you haven't already created a secrets file for the `github-runners` context, generate it:

```bash
task sops:generate-secrets-file
```

This creates `contexts/github-runners/secrets.yaml` with a template.

### Step 4.2: Add the Runner Token to the Secrets File

Edit the `contexts/github-runners/secrets.yaml` file and add the `GITHUB_RUNNER_TOKEN`:

```bash
# Using your preferred editor
vim contexts/github-runners/secrets.yaml
# or
nano contexts/github-runners/secrets.yaml
# or
code contexts/github-runners/secrets.yaml
```

Add the token you obtained from GitHub in Step 2:

```yaml
GITHUB_RUNNER_TOKEN: "<runner-token-from-github>"
```

**Important**: Replace `<runner-token-from-github>` with the actual token you copied from the GitHub runner setup page in Step 2.

### Step 4.3: Encrypt the Secrets File

Encrypt the secrets file using SOPS:

```bash
task sops:encrypt-secrets-file
```

This creates `contexts/github-runners/secrets.enc.yaml` (the encrypted version that can be safely committed to version control).

### Step 4.4: Configure Windsor to Use the Secret

Update `contexts/github-runners/windsor.yaml` to reference the secret and enable SOPS:

{% raw %}
```yaml
secrets:
  sops:
    enabled: true
environment:
  # ... other environment variables ...
  GITHUB_RUNNER_REPO_URL: "https://github.com/<org-or-user>/<repo>"
  GITHUB_RUNNER_TOKEN: ${{ sops.GITHUB_RUNNER_TOKEN }}
  # ... other environment variables ...
```
{% endraw %}

**Note**: For more details on managing secrets with SOPS, see the [Managing Secrets with SOPS](../secrets/secrets.md) runbook.

## Step 4: Verify the environment variables and secrets are present:

```bash
windsor env
```

## Step 5: Configure Network for VMs

Before launching VMs, you need to configure direct network attachment so VMs can get IP addresses from your physical network's DHCP server. Follow the network configuration steps (Step 4) in the [Talos on IncusOS VMs](talos-incus-vm.md) runbook to set up the network.

## Step 6: Launch Ubuntu Runner VM

Launch an Ubuntu virtual machine that will serve as your Linux GitHub Actions runner:

```bash
# Launch Ubuntu 24.04 Server VM (recommended for Docker support)
incus launch images:ubuntu/24.04 $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME --vm \
  --network $INCUS_NETWORK_NAME \
  --config limits.memory=$UBUNTU_GITHUB_RUNNER_0_MEMORY \
  --config limits.cpu=$UBUNTU_GITHUB_RUNNER_0_CPU \
  --config boot.autostart=$UBUNTU_GITHUB_RUNNER_0_AUTOSTART \
  --config security.secureboot=false \
  --config raw.qemu=-cpu host
```

**Note**: 

- The VM name, memory, CPU, and autostart settings use environment variables from your `windsor.yaml` file
- The network uses the `INCUS_NETWORK_NAME` environment variable from your `windsor.yaml` file
- The `--vm` flag creates a virtual machine instead of a container
- **Performance optimizations**:
  - `security.secureboot=false`: Disables Secure Boot for better performance (only disable if security allows)
  - `raw.qemu=-cpu host`: Passes through host CPU features for better performance
- **Recommended resources for optimal performance**:
  - **Memory**: 8GB minimum (16GB recommended for Docker-heavy workloads)
  - **CPU**: 4 cores minimum (8 cores recommended for parallel builds)
- Adjust memory and CPU limits in your `windsor.yaml` file based on your needs and available host resources

### Get the VM IP Address

After the VM boots, get its IP address:

```bash
# List VMs and their IP addresses
incus list $INCUS_REMOTE_NAME:

# Or get detailed information
incus info $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME
```

**Note**: With direct network attachment, the VM gets an IP address from your DHCP server. You may need to check your router's DHCP lease table or use the Incus Web UI console to find the IP address.

### Access the Ubuntu VM

Ubuntu VMs from Incus images don't have a default password. Use `incus exec` to access the VM without authentication:

```bash
# Access via incus exec (recommended - no password needed)
incus exec $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME -- bash

# Or run commands directly
incus exec $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME -- apt update

# To set up SSH access, you'll need to configure it from inside the VM
# First access via incus exec, then set a password or configure SSH keys
```

**Note**: If you need console access (e.g., for troubleshooting boot issues), you can use `incus console $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME`, but you'll need to configure a password first via `incus exec`.

## Step 7: Initialize Ubuntu Runner VM

Initialize the Ubuntu VM for use as a GitHub Actions runner. This will install all required dependencies and set up the runner user:

```bash
task runner:initialize -- $UBUNTU_GITHUB_RUNNER_0_NAME
```

This task will:

1. **Install aqua**: Package manager used by GitHub Actions to set up the environment
2. **Install Docker**: Container runtime for Docker-based workflows
3. **Create runner user**: A dedicated `runner` user (not root) for running GitHub Actions
4. **Set up SSH access**: Configure SSH server and prepare for key-based authentication

**Note**: The `runner:initialize` task uses the `INCUS_REMOTE_NAME`, `RUNNER_USER`, and `RUNNER_HOME` environment variables from your `windsor.yaml` file.

## Step 8: Install GitHub Actions Runner

#### Verify Environment Variables

Before installing the runner, ensure you've completed the earlier steps:

1. **Set up the runner in GitHub** (see the "Set Up Runner in GitHub" section above)
2. **Added the configuration values** to your `windsor.yaml` file (see the "Set Environment Variables" section above)
3. **Reloaded environment variables**: `windsor env`

**Important**: The runner token expires after a short time (typically 1 hour). Make sure to add it to your `windsor.yaml` and run the installation task promptly after getting the token.

#### Install Runner Using Task

Once you've set the `GITHUB_RUNNER_REPO_URL` and `GITHUB_RUNNER_TOKEN` environment variables in your `windsor.yaml` file, install the runner:

```bash
task runner:install-github-runner -- $UBUNTU_GITHUB_RUNNER_0_NAME
```

This task will automatically:

- Download the latest GitHub Actions runner (or use the version specified in `GITHUB_RUNNER_VERSION`)
- Extract the runner files
- Configure the runner for your repository using the token
- Install it as a systemd service running as the `runner` user
- Start the service

The runner will now start automatically on VM boot and connect to GitHub.

#### Manual Installation (Alternative)

If you prefer to install the runner manually or need to troubleshoot, you can access the VM and follow the standard installation process:

```bash
# Access the VM as the runner user
incus exec $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME -- su - $RUNNER_USER

# Create directory for runner
mkdir -p ~/actions-runner && cd ~/actions-runner

# Get the latest runner version
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//')

# Download runner
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-*.tar.gz

# Configure runner (use values from your windsor.yaml or get fresh token from GitHub)
./config.sh --url $GITHUB_RUNNER_REPO_URL --token $GITHUB_RUNNER_TOKEN

# Install as systemd service
## Managing and Maintaining Runners

### Auto-Start Configuration

VMs are configured with `boot.autostart=true` during launch, which ensures they start automatically when the IncusOS host boots. To modify this setting:

```bash
# Enable auto-start
incus config set $INCUS_REMOTE_NAME:<vm-name> boot.autostart=true

# Disable auto-start
incus config set $INCUS_REMOTE_NAME:<vm-name> boot.autostart=false

# Check current setting
incus config show $INCUS_REMOTE_NAME:<vm-name> | grep boot.autostart
```

### Runner Service Management

```bash
# Access the Ubuntu VM
incus exec $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME -- bash

# Inside the VM, manage the service
sudo systemctl status actions.runner.*.service
sudo systemctl start actions.runner.*.service
sudo systemctl stop actions.runner.*.service
sudo systemctl restart actions.runner.*.service

# Enable service to start on boot
sudo systemctl enable actions.runner.*.service

# Disable service from starting on boot
sudo systemctl disable actions.runner.*.service
```

### Updating Runners

GitHub Actions runners should be updated periodically. The runner software can update itself, but you may need to manually update in some cases.

```bash
# Access the Ubuntu VM
incus exec $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME -- bash

# Navigate to runner directory (as runner user)
sudo -u $RUNNER_USER bash
cd ~/actions-runner

# Stop the service
sudo ./svc.sh stop

# Update the runner
./run.sh

# The runner will prompt to update if needed
# Or download latest version manually:
# curl -o actions-runner-linux-x64-2.X.X.X.tar.gz -L \
#   https://github.com/actions/runner/releases/download/v2.X.X.X/actions-runner-linux-x64-2.X.X.X.tar.gz
# tar xzf actions-runner-linux-x64-*.tar.gz

# Restart the service
sudo ./svc.sh start
```

### VM Maintenance

#### Stop a Runner VM

```bash
# Stop the VM (runner service will stop automatically)
incus stop $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME
```

#### Start a Runner VM

```bash
# Start the VM (runner service will start automatically if enabled)
incus start $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME
```

#### Restart a Runner VM

```bash
# Restart the VM
incus restart $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME
```

#### Snapshot a Runner VM

Create snapshots before major updates or changes:

```bash
# Create a snapshot
incus snapshot create $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME runner-snapshot-$(date +%Y%m%d)

# List snapshots
incus snapshot list $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME

# Restore from snapshot
incus snapshot restore $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME runner-snapshot-20240101

# Delete snapshot
incus snapshot delete $INCUS_REMOTE_NAME:$UBUNTU_GITHUB_RUNNER_0_NAME runner-snapshot-20240101
```

## Verification

Verify your runners are working correctly:

1. **Check Runner Status in GitHub**:
   - Navigate to **Settings** → **Actions** → **Runners**
   - Runners should appear with green "Idle" or "Active" status

2. **Test with a Simple Workflow**:
   Create a test workflow file (`.github/workflows/test-runner.yml`):

```yaml
name: Test Runner

on:
  workflow_dispatch:

jobs:
  test-ubuntu:
    runs-on: self-hosted
    steps:
      - name: Check runner OS
        run: uname -a
      
      - name: Test Docker
        run: docker ps
```

## Troubleshooting

### Runner Not Appearing in GitHub

- Verify the runner token is correct and hasn't expired
- Check network connectivity from VM to GitHub
- Review runner logs: `$RUNNER_HOME/actions-runner/_diag/Runner_*.log`
- Ensure firewall rules allow outbound connections to GitHub

### Runner Service Not Starting

```bash
# Check service status
sudo systemctl status actions.runner.*.service

# Check logs
sudo journalctl -u actions.runner.*.service -n 50

# Verify configuration (as runner user)
sudo -u $RUNNER_USER bash
cd ~/actions-runner
./config.sh --check
```

### VM Not Getting IP Address

- Verify network configuration: `incus network show $INCUS_REMOTE_NAME:$INCUS_NETWORK_NAME`
- Check if `instances` role is added to physical interface (see [Talos on IncusOS VMs](talos-incus-vm.md) for network setup)
- Restart the VM: `incus restart $INCUS_REMOTE_NAME:<vm-name>`
- Check DHCP server is running and has available IPs

### Runner Jobs Failing

- Check runner logs in `_diag` directory
- Verify required software is installed (Docker, build tools, etc.)
- Check disk space: `df -h`
- Verify network connectivity from runner to required services

### VM Not Auto-Starting

- Verify auto-start is enabled: `incus config show $INCUS_REMOTE_NAME:<vm-name> | grep boot.autostart`
- Enable if needed: `incus config set $INCUS_REMOTE_NAME:<vm-name> boot.autostart=true`
- Check IncusOS host logs if VMs don't start on host boot

## Next Steps

After successfully setting up your GitHub runners:

1. **Configure runner labels**: Add custom labels to identify runner capabilities
2. **Set up runner groups**: Organize runners into groups for better management
3. **Configure runner policies**: Set up policies for which workflows can use which runners
4. **Monitor runner usage**: Track runner utilization and costs
5. **Set up multiple runners**: Scale horizontally by adding more runner VMs
6. **Implement backup strategy**: Regular snapshots and configuration backups

## Additional Resources

- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Runner Configuration](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners)
- [IncusOS Setup](incusos-setup.md) - Setting up IncusOS
- [Talos on IncusOS VMs](talos-incus-vm.md) - Example of VM deployment on IncusOS
