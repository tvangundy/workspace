---
title: "Runner Tasks"
description: "GitHub Actions runner setup and management tasks for initializing VMs, installing dependencies, and configuring runners"
---
# Runner Tasks (`runner:`)

GitHub Actions runner VM setup and management.

## Overview

The `runner:` namespace provides comprehensive tools for setting up and managing GitHub Actions self-hosted runners on Incus VMs. These tasks handle VM initialization, dependency installation, user creation, SSH setup, and runner configuration.

## Task Reference

| Task | Description |
|------|-------------|
| [`initialize`](#initialize) | Initialize a new Incus VM for GitHub Actions runner (runs all setup tasks in sequence) |
| [`install-aqua`](#install-aqua) | Install Aqua package manager on the runner VM |
| [`install-docker`](#install-docker) | Install Docker on the runner VM |
| [`create-runner-user`](#create-runner-user) | Create a dedicated runner user for GitHub Actions |
| [`setup-ssh`](#setup-ssh) | Set up SSH access for the runner user |
| [`install-windsor-cli`](#install-windsor-cli) | Install Windsor CLI on the runner VM |
| [`install-packages`](#install-packages) | Install additional packages commonly needed for GitHub Actions runners |
| [`install-github-runner`](#install-github-runner) | Install and configure GitHub Actions runner |
| [`clean-work-dir`](#clean-work-dir) | Clean the actions-runner/_work directory on the runner VM |
| [`shell`](#shell) | Open an interactive shell session in the runner VM |

## Initialization

### `initialize`

Initialize a new Incus VM for GitHub Actions runner. Runs all setup tasks in sequence.

**Usage:**

```bash
task runner:initialize -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**What it does:**

Runs the following tasks in sequence:

1. `install-aqua` - Install Aqua package manager
2. `install-docker` - Install Docker
3. `create-runner-user` - Create dedicated runner user
4. `setup-ssh` - Set up SSH access
5. `install-windsor-cli` - Install Windsor CLI

**Example:**

```bash
task runner:initialize -- github-runner-ubuntu
```

**Note:** After initialization, you'll still need to install the GitHub Actions runner software using `task runner:install-github-runner`.

## Setup Tasks

### `install-aqua`

Install Aqua package manager on the runner VM.

**Usage:**

```bash
task runner:install-aqua -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name

**What it does:**

1. Checks if Aqua is already installed (skips if present)
2. Downloads and installs Aqua using the official installer
3. Adds Aqua to PATH
4. Verifies installation

**Example:**

```bash
task runner:install-aqua -- github-runner-ubuntu
```

### `install-docker`

Install Docker on the runner VM.

**Usage:**

```bash
task runner:install-docker -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name

**What it does:**

1. Checks if Docker is already installed (skips if present)
2. Installs prerequisites (ca-certificates, curl, gnupg, lsb-release)
3. Adds Docker's official GPG key
4. Sets up Docker repository
5. Installs Docker Engine, CLI, containerd, buildx, and compose plugins
6. Starts and enables Docker service
7. Verifies installation

**Example:**

```bash
task runner:install-docker -- github-runner-ubuntu
```

### `create-runner-user`

Create a dedicated runner user for GitHub Actions.

**Usage:**

```bash
task runner:create-runner-user -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name
- `RUNNER_USER`: Username for the runner user

**What it does:**

1. Checks if user already exists (skips if present)
2. Creates user with home directory and bash shell
3. Adds user to `docker` group (if Docker is installed)
4. Adds user to `sudo` group
5. Configures passwordless sudo for automation

**Example:**

```bash
export RUNNER_USER=runner
task runner:create-runner-user -- github-runner-ubuntu
```

### `setup-ssh`

Set up SSH access for the runner user.

**Usage:**

```bash
task runner:setup-ssh -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name
- `RUNNER_USER`: Username for the runner user

**What it does:**

1. Installs OpenSSH server if not present
2. Starts and enables SSH service
3. Creates `.ssh` directory for runner user
4. Sets correct permissions

**Example:**

```bash
task runner:setup-ssh -- github-runner-ubuntu
```

**Note:** After running this task, you'll need to add your SSH public key manually. The task provides instructions for doing this.

### `install-windsor-cli`

Install Windsor CLI on the runner VM.

**Usage:**

```bash
task runner:install-windsor-cli -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name

**Optional Environment Variables:**

- `WINDSOR_CLI_VERSION`: Windsor CLI version (default: `v0.8.1`)

**What it does:**

1. Checks if Windsor CLI is already installed (skips if present)
2. Detects platform and architecture
3. Downloads and installs Windsor CLI to `/usr/local/bin`
4. Verifies installation

**Example:**

```bash
# Use default version
task runner:install-windsor-cli -- github-runner-ubuntu

# Use specific version
export WINDSOR_CLI_VERSION=v0.9.0
task runner:install-windsor-cli -- github-runner-ubuntu
```

### `install-packages`

Install additional packages commonly needed for GitHub Actions runners.

**Usage:**

```bash
task runner:install-packages -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name

**What it does:**

Installs the following packages:

- `build-essential` - Compilation tools
- `git` - Version control
- `curl`, `wget` - HTTP clients
- `python3`, `python3-pip` - Python runtime
- `nodejs`, `npm` - Node.js runtime
- `default-jre`, `default-jdk` - Java runtime
- `unzip` - Archive extraction
- `software-properties-common` - Package management utilities
- `jq`, `yq` - JSON/YAML processors
- `rsync` - File synchronization
- `openssh-client` - SSH client

**Example:**

```bash
task runner:install-packages -- github-runner-ubuntu
```

## GitHub Actions

### `install-github-runner`

Install and configure GitHub Actions runner.

**Usage:**

```bash
task runner:install-github-runner -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name
- `GITHUB_RUNNER_REPO_URL`: GitHub repository or organization URL
- `GITHUB_RUNNER_TOKEN`: GitHub runner registration token
- `RUNNER_USER`: Username for the runner user
- `RUNNER_HOME`: Home directory path for the runner user

**Optional Environment Variables:**

- `GITHUB_RUNNER_VERSION`: Specific runner version (e.g., `"2.XXX.X"`). If not set, uses latest
- `GITHUB_RUNNER_ARCH`: Runner architecture - `"x64"` or `"arm64"` (default: `"x64"`)

**What it does:**

1. Validates required environment variables
2. Determines latest runner version if not specified
3. Creates `actions-runner` directory as runner user
4. Downloads runner package for the specified architecture
5. Extracts the runner package
6. Configures runner with repository URL and token
7. Installs runner as systemd service (runs as runner user)
8. Starts the runner service

**Example:**

```bash
export GITHUB_RUNNER_REPO_URL=https://github.com/user/repo
export GITHUB_RUNNER_TOKEN=your-registration-token
export RUNNER_USER=runner
export RUNNER_HOME=/home/runner

task runner:install-github-runner -- github-runner-ubuntu
```

**Getting the Registration Token:**

1. Go to GitHub repository → Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Copy the registration token (or use the setup script which includes the token)

**Note:** The runner service is installed to run automatically on system boot.

## Maintenance

### `clean-work-dir`

Clean the actions-runner/_work directory on the runner VM.

**Usage:**

```bash
task runner:clean-work-dir -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name
- `RUNNER_USER`: Username for the runner user
- `RUNNER_HOME`: Home directory path for the runner user

**What it does:**

1. Checks if work directory exists
2. Removes all contents from `actions-runner/_work/test/test`
3. Preserves hidden files/directories like `.windsor`

**Example:**

```bash
task runner:clean-work-dir -- github-runner-ubuntu
```

**Warning:** This removes all work artifacts. Only run when you're sure you don't need the work directory contents.

### `shell`

Open an interactive shell session in the runner VM.

**Usage:**

```bash
task runner:shell -- <vm-name>
```

**Parameters:**

- `<vm-name>`: Name of the VM instance (required)

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name

**Example:**

```bash
task runner:shell -- github-runner-ubuntu
```

**Note:** Type `exit` to leave the shell.

## Environment Variables

The following environment variables are commonly used:

- `INCUS_REMOTE_NAME`: Incus remote name (required for all tasks)
- `RUNNER_USER`: Username for the runner user (required for user-related tasks)
- `RUNNER_HOME`: Home directory path for the runner user (default: `/home/<RUNNER_USER>`)
- `GITHUB_RUNNER_REPO_URL`: GitHub repository or organization URL (required for `install-github-runner`)
- `GITHUB_RUNNER_TOKEN`: GitHub runner registration token (required for `install-github-runner`, should be stored as a secret)
- `GITHUB_RUNNER_VERSION`: Specific runner version (optional, defaults to latest)
- `GITHUB_RUNNER_ARCH`: Runner architecture - `"x64"` or `"arm64"` (optional, default: `"x64"`)
- `WINDSOR_CLI_VERSION`: Windsor CLI version (optional, default: `v0.8.1`)

## Prerequisites

- Incus VM instance created and running
- Network access to the VM
- GitHub repository or organization with Actions enabled
- Admin access to add self-hosted runners

## Workflow Example

Complete setup workflow:

```bash
# 1. Initialize the VM (runs all setup tasks)
task runner:initialize -- github-runner-ubuntu

# 2. Install additional packages (optional)
task runner:install-packages -- github-runner-ubuntu

# 3. Install GitHub Actions runner
export GITHUB_RUNNER_REPO_URL=https://github.com/user/repo
export GITHUB_RUNNER_TOKEN=your-token
task runner:install-github-runner -- github-runner-ubuntu

# 4. Verify runner is online (check GitHub repository → Settings → Actions → Runners)
```

## Help

View all available runner commands:

```bash
task runner:help
```

## Taskfile Location

Task definitions are located in `tasks/runner/Taskfile.yaml`.
