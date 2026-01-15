---
title: "GitHub Actions Runner on IncusOS VM"
description: "Complete guide for deploying a GitHub Actions runner on an Ubuntu VM on IncusOS"
---
# GitHub Actions Runner on IncusOS VM

This runbook guides you through deploying a GitHub Actions runner on an Ubuntu virtual machine running on an IncusOS system. This runbook leverages the standard Ubuntu VM creation process (see [Ubuntu Virtual Machines](../../incusos/vm.md)) and adds GitHub Actions runner-specific configuration.

## Overview

Deploying a GitHub Actions runner on an IncusOS VM involves:

- Creating a standard Ubuntu VM using the `vm:` task namespace
- Configuring GitHub runner-specific settings using environment variables
- Installing and configuring the GitHub Actions runner service
- Managing the runner VM lifecycle

This approach uses the standard VM creation workflow, making it consistent with other VM deployments while adding GitHub Actions runner-specific configuration.

## Prerequisites

- IncusOS server installed and running (see [IncusOS Server](../../incusos/server.md))
- Incus CLI client installed on your local machine
- Remote connection to your IncusOS server configured
- Workspace initialized and context set (see [Initialize Workspace](../../workspace/init.md))
- GitHub repository or organization access
- GitHub Actions runner token (obtained from GitHub repository/organization settings)

## Step 1: Install Tools

To fully leverage the Windsor environment and manage your runner VM, you will need several tools installed on your system. You may install these tools manually or using your preferred tools manager (_e.g._ Homebrew). The Windsor project recommends [aqua](https://aquaproj.github.io/).

Ensure your `aqua.yaml` includes the following packages required for this runbook. Add any missing packages to your existing `aqua.yaml`:

```yaml
packages:
- name: hashicorp/terraform@v1.10.3
- name: lxc/incus@v6.20.0
- name: docker/cli@v27.4.1
- name: docker/compose@v2.32.1
```

To install the tools specified in `aqua.yaml`, run:

```bash
aqua install
```

## Step 2: Configure Environment Variables

Add the following to your `contexts/<context>/windsor.yaml`:

```text
environment:
  # Use remote Incus server
  INCUS_REMOTE_NAME: your-remote-name
  
  # VM configuration (using standard VM_* variables)
  VM_INSTANCE_NAME: github-runner
  VM_MEMORY: 4GB  # 4GB recommended for CI/CD workloads
  VM_CPU: 4
  VM_AUTOSTART: true  # Keep runner available after host reboot
  VM_NETWORK_NAME: eno1  # Physical network interface for direct network access
  VM_DISK_SIZE: 50GB  # Sufficient for build artifacts and dependencies
  
  # Workspace initialization (optional, set to false for runner VM)
  VM_INIT_WORKSPACE: false
  
  # Use default Docker socket (VMs run Docker natively)
  DOCKER_HOST: unix:///var/run/docker.sock
  
  # Runner user configuration
  RUNNER_USER: "runner"
  RUNNER_HOME: "/home/runner"
  
  # GitHub Actions runner configuration
  GITHUB_RUNNER_REPO_URL: "https://github.com/<org-or-user>/<repo>"
  # Generate a random token-like string if sops is not available:
  #   openssl rand -hex 32  # For GITHUB_RUNNER_TOKEN
  # Or use sops if configured - replace the value below with:
  #   GITHUB_RUNNER_TOKEN: sops.GITHUB_RUNNER_TOKEN
  # Default value shown below:
  GITHUB_RUNNER_TOKEN: "<runner-token>"
  GITHUB_RUNNER_VERSION: "2.XXX.X"  # Optional: defaults to latest
  GITHUB_RUNNER_ARCH: "x64"  # Optional: defaults to "x64"
```

**Important Notes:**

- `INCUS_REMOTE_NAME` - The name of your Incus remote (configured via `incus remote add`)
- `VM_INSTANCE_NAME` - Name for the runner VM instance (defaults to `github-runner`)
- `VM_MEMORY` - Memory allocation (4GB recommended for CI/CD workloads)
- `VM_CPU` - CPU cores (4 cores recommended)
- `VM_NETWORK_NAME` - Physical network interface on your IncusOS server for direct network access (e.g., `eno1`, `eth0`, `enp5s0`)
- `VM_DISK_SIZE` - Disk size for build artifacts and dependencies (50GB recommended)
- `VM_AUTOSTART` - Set to `true` to keep the runner available after host reboot
- `GITHUB_RUNNER_REPO_URL` - The GitHub repository or organization URL where the runner will be registered
- `GITHUB_RUNNER_TOKEN` - The registration token from GitHub (see Step 3)

## Step 3: Get GitHub Runner Token

Before creating the VM, you need to obtain a GitHub Actions runner registration token:

1. Navigate to your GitHub repository or organization
2. Go to **Settings** → **Actions** → **Runners**
3. Click **New self-hosted runner**
4. Select the operating system (Linux) and architecture (x64)
5. Copy the registration token shown in the instructions

**Note**: The token is temporary and will expire. You'll need to use it during the runner installation process (Step 7).

Alternatively, you can store the token as a SOPS secret for better security:

1. Add `GITHUB_RUNNER_TOKEN` to your `contexts/<context>/secrets.yaml`
2. Encrypt the secrets file: `task sops:encrypt-secrets-file`
3. Update your `windsor.yaml` to use: `GITHUB_RUNNER_TOKEN: sops.GITHUB_RUNNER_TOKEN`

## Step 4: Verify Remote Connection

Before creating a VM, verify you can connect to your IncusOS server:

```bash
# List configured remotes
incus remote list

# Verify you can connect to your remote
incus list <remote-name>:

# Verify environment variables are set
windsor env | grep INCUS_REMOTE_NAME
```

**Expected output:**

- Your remote should appear in `incus remote list` with the name you configured
- `incus list <remote-name>:` should show existing instances (may be empty)
- `INCUS_REMOTE_NAME` should be set to your remote name

## Step 5: Create the Ubuntu VM

Create the Ubuntu VM using the standard VM creation workflow:

```bash
task vm:create --name github-runner
```

Or if you've set `VM_INSTANCE_NAME: github-runner` in your environment variables:

```bash
task vm:create
```

This will:

1. Generate `terraform.tfvars` from environment variables
2. Initialize Terraform
3. Apply the Terraform configuration to create the VM
4. **Automatically install developer tools** (git, build-essential, curl, vim, etc.)
5. **Create a user matching your host username** with the same UID/GID
6. **Copy your SSH keys** for immediate access
7. **Configure Git** with your existing settings
8. **Install Docker** for containerized CI/CD workloads
9. **Set up SSH server** for direct access

**Note**: The VM is created with Docker already installed, which is required for many CI/CD workflows.

**Confirmation:**
```bash
# Verify VM was created
task vm:list

# Check VM status
task vm:info -- github-runner

# Get VM IP address
task vm:info -- github-runner | grep -i ip

# Verify Docker is installed
task vm:exec -- github-runner -- docker --version
```

## Step 6: Initialize Runner Environment

Initialize the runner environment on the VM using the `vm:runner:` namespace tasks:

```bash
task vm:runner:initialize -- github-runner
```

This will:

1. Install aqua package manager
2. Install Docker (if not already installed)
3. Create the runner user account
4. Set up SSH access
5. Install Windsor CLI

**Note**: The VM created with `task vm:create` already has Docker installed, so this step will verify and configure it for the runner user.

## Step 7: Install GitHub Actions Runner

Install and configure the GitHub Actions runner on the VM:

```bash
task vm:runner:install-github-runner -- github-runner
```

This will:

1. Download the GitHub Actions runner binary
2. Extract it to the runner user's home directory
3. Configure the runner with your repository URL and token
4. Install the runner as a systemd service
5. Start the runner service

**Note**: The runner will automatically register with GitHub using the `GITHUB_RUNNER_REPO_URL` and `GITHUB_RUNNER_TOKEN` from your environment variables.

## Step 8: Verify Runner Status

Verify that the runner is registered and running:

### Check Runner in GitHub

1. Navigate to your GitHub repository or organization
2. Go to **Settings** → **Actions** → **Runners**
3. The runner should appear with a green status indicator
4. The runner name should match your VM name (e.g., `github-runner`)

### Check Runner Service on VM

```bash
# Check runner service status
task vm:exec -- github-runner -- sudo systemctl status actions.runner.*.service

# View runner logs
task vm:exec -- github-runner -- sudo journalctl -u actions.runner.*.service -f
```

### Test with a Workflow

Create a simple test workflow in your repository to verify the runner is working:

```yaml
name: Test Runner
on: [push]

jobs:
  test:
    runs-on: self-hosted
    steps:
      - name: Check runner
        run: |
          echo "Runner is working!"
          uname -a
          docker --version
```

Commit and push this workflow to trigger it on your self-hosted runner.

## Ongoing Management

### Access the Runner VM

You can access the runner VM in several ways:

```bash
# Via SSH (recommended - already configured)
task vm:ssh -- github-runner

# Via Incus shell
task vm:shell -- github-runner

# Via Incus exec (always works)
incus exec $INCUS_REMOTE_NAME:github-runner -- bash
```

### Manage Runner Service

```bash
# Stop runner service
task vm:exec -- github-runner -- sudo systemctl stop actions.runner.*.service

# Start runner service
task vm:exec -- github-runner -- sudo systemctl start actions.runner.*.service

# Restart runner service
task vm:exec -- github-runner -- sudo systemctl restart actions.runner.*.service

# Check runner service status
task vm:exec -- github-runner -- sudo systemctl status actions.runner.*.service
```

### Update Runner

To update the GitHub Actions runner to a newer version:

1. Update `GITHUB_RUNNER_VERSION` in your `windsor.yaml`
2. Regenerate environment variables: `windsor env`
3. Reinstall the runner: `task vm:runner:install-github-runner -- github-runner`

### VM Management

Manage the VM itself using the `vm:` task namespace:

```bash
# Start VM
task vm:start -- github-runner

# Stop VM
task vm:stop -- github-runner

# Restart VM
task vm:restart -- github-runner

# Get VM info
task vm:info -- github-runner

# List all VMs
task vm:list
```

## Destroying the Runner VM

To completely destroy the runner VM and remove all resources:

```bash
task vm:delete -- github-runner
```

**Warning**: This will:

1. **Stop the runner service** on the VM
2. **Unregister the runner** from GitHub (if still connected)
3. **Destroy the VM** and all its data
4. **Remove the runner** from GitHub's runner list

**Note**: Before destroying the VM, make sure to:
- Stop any running workflows that might be using the runner
- Remove the runner from GitHub if you want to clean up the runner list

## Troubleshooting

### Runner Not Appearing in GitHub

- Verify the runner token is correct and hasn't expired
- Check the runner service logs: `task vm:exec -- github-runner -- sudo journalctl -u actions.runner.*.service -n 50`
- Ensure the VM has network connectivity: `task vm:exec -- github-runner -- ping -c 3 8.8.8.8`

### Runner Service Not Starting

```bash
# Check service status
task vm:exec -- github-runner -- sudo systemctl status actions.runner.*.service

# View service logs
task vm:exec -- github-runner -- sudo journalctl -u actions.runner.*.service -n 100

# Check runner configuration
task vm:exec -- github-runner -- cat /home/runner/actions-runner/.runner
```

### Workflows Not Running on Runner

- Verify the workflow uses `runs-on: self-hosted`
- Check runner labels match workflow requirements
- Ensure the runner is online in GitHub: **Settings** → **Actions** → **Runners**

### VM Not Starting

```bash
# Check VM status
task vm:info -- github-runner

# View VM logs
incus console $INCUS_REMOTE_NAME:github-runner

# Check host resources
task vm:list
```

## Summary

This runbook has guided you through:

1. ✅ Configuring environment variables for the runner VM
2. ✅ Obtaining a GitHub Actions runner registration token
3. ✅ Configuring direct network attachment for the VM (optional)
4. ✅ Creating the Ubuntu VM using the standard `vm:` task namespace
5. ✅ Initializing the runner environment
6. ✅ Installing and configuring the GitHub Actions runner
7. ✅ Verifying the runner is registered and working

You now have a GitHub Actions runner running in an isolated VM on your IncusOS infrastructure, managed using the standard VM workflow, with full control over both the runner and the underlying VM.

## Related Runbooks

- [IncusOS Server](../../incusos/server.md): Initial IncusOS server installation
- [Ubuntu Virtual Machines](../../incusos/vm.md): Creating VMs for development, CI/CD runners, or other workloads (similar process)
- [Bare Metal Runner Setup](bare-metal-runner-setup.md): Setting up GitHub Actions runners on bare metal Ubuntu servers

## Additional Resources

- [GitHub Actions Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Terraform Incus Provider Documentation](https://registry.terraform.io/providers/lxc/incus/latest/docs)

