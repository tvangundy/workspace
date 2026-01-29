---
title: "Runner Tasks"
description: "GitHub Actions runner management tasks for creating and managing self-hosted runners on Incus VMs"
---
# Runner Tasks (`runner:`)

GitHub Actions runner management for creating and managing self-hosted runners on Incus VMs.

## Overview

The `runner:` namespace provides comprehensive tools for creating, managing, and interacting with GitHub Actions self-hosted runners running on Ubuntu VMs on Incus. These tasks handle the complete runner lifecycle including VM creation, user setup, runner installation, and GitHub registration.

## Task Reference

| Task | Description |
|------|-------------|
| [`instantiate`](#instantiate) | Create a GitHub Actions runner VM with complete setup |
| [`instantiate:parse-args`](#instantiateparse-args) | Parse CLI arguments for instantiate |
| [`instantiate:initialize-context`](#instantiateinitialize-context) | Initialize Windsor context and create windsor.yaml |
| [`instantiate:verify-remote`](#instantiateverify-remote) | Verify Incus remote exists and is reachable |
| [`instantiate:create-vm`](#instantiatecreate-vm) | Create VM using vm:instantiate task |
| [`instantiate:setup-runner-user`](#instantiatesetup-runner-user) | Setup runner user with SSH keys and Incus access |
| [`instantiate:install-github-runner`](#instantiateinstall-github-runner) | Install and configure GitHub Actions runner |
| [`instantiate:cleanup-if-needed`](#instantiatecleanup-if-needed) | Cleanup VM if --keep flag was not set |
| [`status`](#status) | Check status of GitHub Actions runner service |
| [`destroy`](#destroy) | Destroy runner VM and remove it from GitHub repository |

## Runner Creation

### `instantiate`

Create a GitHub Actions runner VM with complete setup. This is the primary way to create a new runner.

**Usage:**

```bash
task runner:instantiate -- <remote-name> [<runner-name>] [--keep]
```

**Parameters:**

- `<remote-name>` (required): Name of the Incus remote (e.g., `nuc`, `local`)
- `<runner-name>` (optional): Name for the runner VM (default: `runner`)
- `--keep`, `--no-cleanup` (optional): Keep VM running after creation (default: delete VM if used in test context)

**What it does:**

1. Parses CLI arguments and sets up environment
2. Initializes Windsor context and creates `windsor.yaml`
3. Verifies Incus remote exists and is reachable
4. Creates VM using `vm:instantiate` task (includes developer environment setup)
5. Sets up dedicated runner user with:
   - SSH keys matching the main user
   - Sudo access
   - Incus group membership for managing VMs
   - Incus remote configuration for the runner user
6. Installs and configures GitHub Actions runner:
   - Prompts for repository URL and registration token (if not in secrets)
   - Downloads and extracts runner binary
   - Configures runner with repository and token
   - Installs runner as systemd service
   - Starts the runner service
7. Optionally cleans up VM (unless `--keep` is used)

**Examples:**

```bash
# Create a runner on remote 'nuc' with default name 'runner'
task runner:instantiate -- nuc

# Create a runner with custom name
task runner:instantiate -- nuc my-runner

# Create a runner and keep it running
task runner:instantiate -- nuc my-runner --keep
```

**Note:** The first time you run this, you'll be prompted for:
- GitHub repository URL (e.g., `https://github.com/owner/repo`)
- GitHub registration token (obtained from repository settings)

These values are saved to `secrets.yaml` and encrypted with SOPS for future use.

### `instantiate:parse-args`

Parse CLI arguments for the instantiate task. This is automatically called by `instantiate` but can be run independently for testing.

**Usage:**

```bash
task runner:instantiate:parse-args
```

### `instantiate:initialize-context`

Initialize Windsor context and create `windsor.yaml` for the runner. Sets up default environment variables including `VM_AUTOSTART: true` for runner VMs.

**Usage:**

```bash
task runner:instantiate:initialize-context
```

### `instantiate:verify-remote`

Verify that the Incus remote exists and is reachable. This is automatically called by `instantiate`.

**Usage:**

```bash
task runner:instantiate:verify-remote
```

### `instantiate:create-vm`

Create VM using the `vm:instantiate` task. This creates a complete Ubuntu VM with developer environment setup.

**Usage:**

```bash
task runner:instantiate:create-vm
```

### `instantiate:setup-runner-user`

Setup dedicated runner user on the VM. This includes:
- Creating the runner user
- Copying SSH keys from main user
- Adding user to sudo, docker, and incus groups
- Configuring Incus remote access for the runner user
- Setting up proper permissions

**Usage:**

```bash
task runner:instantiate:setup-runner-user
```

### `instantiate:install-github-runner`

Install and configure GitHub Actions runner. This includes:
- Prompting for repository URL and token (if not in secrets)
- Saving secrets to `secrets.yaml` and encrypting with SOPS
- Downloading and extracting runner binary
- Configuring runner with repository and token
- Installing runner as systemd service
- Starting the runner service

**Usage:**

```bash
task runner:instantiate:install-github-runner
```

**Note:** If a runner with the same name already exists in the repository, it will be automatically removed before installing the new one.

### `instantiate:cleanup-if-needed`

Cleanup VM if `--keep` flag was not set. This is typically used in test contexts.

**Usage:**

```bash
task runner:instantiate:cleanup-if-needed
```

## Runner Management

### `status`

Check the status of the GitHub Actions runner service.

**Usage:**

```bash
task runner:status [-- <runner-name>]
```

**Parameters:**

- `<runner-name>` (optional): Runner VM name (default: `runner`)

**What it does:**

1. Connects to the runner VM
2. Checks if runner is installed
3. Shows systemd service status
4. Displays runner configuration (name, repository URL)

**Output:** Shows whether the runner service is running, the runner name, and the repository it's connected to.

**Example:**

```bash
# Check status of default runner
task runner:status

# Check status of specific runner
task runner:status -- my-runner
```

### `destroy`

Destroy the runner VM and remove it from the GitHub repository.

**Usage:**

```bash
task runner:destroy [-- <runner-name>]
```

**Parameters:**

- `<runner-name>` (optional): Runner VM name (default: `runner`)

**What it does:**

1. Connects to the runner VM
2. Stops the runner service
3. Uninstalls the runner service
4. Removes the runner from GitHub repository using the registration token
5. Destroys the VM using `vm:destroy`

**Warning:** This permanently removes the runner VM and unregisters it from GitHub. The runner will no longer be available for GitHub Actions workflows.

**Example:**

```bash
# Destroy default runner
task runner:destroy

# Destroy specific runner
task runner:destroy -- my-runner
```

## Environment Variables

The following environment variables can be set in your `contexts/<context>/windsor.yaml` configuration:

- `INCUS_REMOTE_NAME`: Incus remote name (required). Examples: `local`, `nuc`, `remote-server`
- `RUNNER_NAME`: Runner VM name. Default: `runner`
- `VM_INSTANCE_NAME`: VM instance name (usually same as `RUNNER_NAME`). Default: `runner`
- `VM_IMAGE`: VM image. Default: `ubuntu/24.04`
- `VM_MEMORY`: Memory allocation for the VM (e.g., `8GB`, `16GB`). Default: `8GB`
- `VM_CPU`: CPU count for the VM. Default: `4`
- `VM_AUTOSTART`: Whether to start the VM automatically on host boot. Default: `true` (for runner VMs)
- `VM_NETWORK_NAME`: Physical network interface for direct network access (e.g., `eno1`, `enp5s0`). Leave empty to use default Incus network
- `VM_STORAGE_POOL`: Storage pool name. Default: `local`

The following secrets should be stored in `contexts/<context>/secrets.yaml` and encrypted with SOPS:

- `GITHUB_RUNNER_REPO_URL`: GitHub repository URL (e.g., `https://github.com/owner/repo`)
- `GITHUB_RUNNER_TOKEN`: GitHub Actions runner registration token

**Note:** These secrets are automatically saved when you run `runner:instantiate` for the first time. They are referenced in `windsor.yaml` using SOPS syntax: `"${{ sops.GITHUB_RUNNER_REPO_URL }}"`

## Prerequisites

- Incus installed and configured
- Terraform installed
- `INCUS_REMOTE_NAME` environment variable set
- For remote deployments: SSH access configured
- GitHub repository access
- GitHub Actions runner registration token (obtained from repository settings)

## Help

View all available runner commands:

```bash
task runner:help
```

## Taskfile Location

Task definitions are located in `tasks/runner/Taskfile.yaml`.

## Related Documentation

- [VM Runner Setup Runbook](../../runbooks/apps/runners/vm-runner-setup.md) - Complete guide for setting up GitHub Actions runners
- [VM Tasks](../vm/README.md) - VM management tasks used by runner tasks
- [Secrets Management](../../runbooks/secrets/secrets.md) - Guide for managing secrets with SOPS

