---
title: "VM Tasks"
description: "Ubuntu virtual machine management tasks for creating and managing VMs on Incus using Terraform"
---
# VM Tasks (`vm:`)

Ubuntu virtual machine management for creating and managing VMs on Incus using Terraform.

## Overview

The `vm:` namespace provides comprehensive tools for creating, managing, and interacting with Ubuntu virtual machines running on Incus. These tasks use Terraform for infrastructure-as-code management and handle VM lifecycle, workspace synchronization, SSH access, and environment setup including Docker, Homebrew, Aqua, and Windsor CLI.

## Task Reference

| Task | Description |
|------|-------------|
| [`create`](#create) | Create a VM instance using Terraform |
| [`create:validate`](#createvalidate) | Validate input and check prerequisites for instance creation |
| [`create:setup-env`](#createsetup-env) | Setup developer environment in the instance |
| [`generate-tfvars`](#generate-tfvars) | Generate terraform.tfvars from environment variables |
| [`terraform:init`](#terraforminit) | Initialize Terraform for the VM |
| [`terraform:plan`](#terraformplan) | Show Terraform plan for the VM |
| [`terraform:apply`](#terraformapply) | Apply Terraform configuration to create the VM |
| [`terraform:destroy`](#terraformdestroy) | Destroy the VM using Terraform |
| [`start`](#start) | Start a VM instance |
| [`stop`](#stop) | Stop a VM instance |
| [`restart`](#restart) | Restart a VM instance |
| [`list`](#list) | List all VM instances |
| [`info`](#info) | Get information about a VM instance |
| [`debug`](#debug) | Debug performance and resource usage of a VM instance |
| [`delete`](#delete) | Delete a VM using Terraform |
| [`shell`](#shell) | Open an interactive shell in a VM instance |
| [`ssh`](#ssh) | SSH into a VM instance |
| [`ssh-info`](#ssh-info) | Show SSH connection information for a VM instance |
| [`exec`](#exec) | Execute a command in a VM instance |
| [`init-workspace`](#init-workspace) | Initialize workspace contents in an existing VM |
| [`copy-workspace`](#copy-workspace) | Copy entire workspace to vm (replaces existing) |
| [`add-workspace`](#add-workspace) | Add workspace to vm (merges with existing) |
| [`sync-workspace`](#sync-workspace) | Sync workspace changes to vm using rsync |
| [`test`](#test) | Test VM setup by running through all runbook steps and validating the VM |

## Instance Creation

### `create`

Create an Ubuntu virtual machine instance using Terraform.

**Usage:**

```bash
task vm:create
```

**What it does:**

1. Validates prerequisites and environment variables
2. Generates `terraform.tfvars` from environment variables
3. Initializes Terraform
4. Applies Terraform configuration to create the VM
5. Sets up the developer environment (for remote deployments):
   - Installs essential developer tools (git, curl, vim, etc.)
   - Installs Incus (for Ubuntu 24.04+)
   - Creates user matching host user
   - Copies SSH keys
   - Configures Git and GitHub credentials
   - Installs Docker
   - Configures br_netfilter kernel module for Kubernetes networking
   - Installs Homebrew, Aqua, and Windsor CLI
   - Configures bashrc
   - Sets up SSH server
   - Optionally initializes workspace contents

**Note:** Environment setup is only performed for remote deployments (`INCUS_REMOTE_NAME != local`).

### `create:validate`

Validate input and check prerequisites for instance creation. This is automatically called by `create` but can be run independently.

**Usage:**

```bash
task vm:create:validate
```

### `create:setup-env`

Setup developer environment in an existing instance. Automatically called by `create` for remote deployments.

**Usage:**

```bash
task vm:create:setup-env -- <instance-name>
```

**Parameters:**

- `<instance-name>` (required): Instance name

**What it does:**

1. Waits for VM agent to be ready
2. Installs essential developer tools
3. Installs Incus
4. Creates user matching host user
5. Copies SSH keys
6. Configures Git and GitHub credentials
7. Installs Docker
8. Configures br_netfilter kernel module
9. Installs Homebrew, Aqua, and Windsor CLI
10. Configures bashrc
11. Sets up SSH server
12. Optionally initializes workspace contents (if `VM_INIT_WORKSPACE=true`)

## Terraform Operations

### `generate-tfvars`

Generate `terraform.tfvars` from environment variables.

**Usage:**

```bash
task vm:generate-tfvars
```

**What it does:**

1. Reads environment variables from Windsor context
2. Generates `terraform/vm/terraform.tfvars`
3. Includes configuration for VM resources, network, and storage

**Note:** The generated file is automatically created and should not be edited manually. Update environment variables in `contexts/<context>/windsor.yaml` instead.

### `terraform:init`

Initialize Terraform for the VM.

**Usage:**

```bash
task vm:terraform:init
```

### `terraform:plan`

Show Terraform plan for the VM.

**Usage:**

```bash
task vm:terraform:plan
```

### `terraform:apply`

Apply Terraform configuration to create VM.

**Usage:**

```bash
task vm:terraform:apply
```

### `terraform:destroy`

Destroy vm using Terraform.

**Usage:**

```bash
task vm:terraform:destroy
```

**Warning:** This permanently removes the VM and all its data.

## Instance Management

### `start`

Start an VM instance.

**Usage:**

```bash
task vm:start [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

### `stop`

Stop an VM instance.

**Usage:**

```bash
task vm:stop [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

### `restart`

Restart an VM instance.

**Usage:**

```bash
task vm:restart [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

### `list`

List all VM instances on the configured remote.

**Usage:**

```bash
task vm:list
```

**Output:** Shows all instances with their status, IP addresses, and resource usage.

### `info`

Get detailed information about an VM instance.

**Usage:**

```bash
task vm:info [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

**Output:** Shows instance configuration, resources, network information, and status.

### `debug`

Debug performance and resource usage of an VM instance.

**Usage:**

```bash
task vm:debug [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

**Output:** Shows CPU, memory, disk, network usage statistics, and performance diagnostics.

### `delete`

Delete an VM using Terraform. **Warning:** This permanently removes the VM and all its data.

**Usage:**

```bash
task vm:delete
```

## Access

### `shell`

Open an interactive shell in an VM instance (similar to `docker exec -it`).

**Usage:**

```bash
task vm:shell [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

**Example:**

```bash
task vm:shell -- VM
```

### `ssh`

SSH into an VM instance. Connects directly via SSH using the instance's IP address.

**Usage:**

```bash
task vm:ssh [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

**Example:**

```bash
task vm:ssh -- VM
```

### `ssh-info`

Show SSH connection information for an VM instance.

**Usage:**

```bash
task vm:ssh-info [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

**Output:** Shows SSH host, port, username, and connection command.

### `exec`

Execute a command in an VM instance (similar to `docker exec`).

**Usage:**

```bash
task vm:exec -- <command>
task vm:exec -- <instance-name> -- <command>
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)
- `<command>`: Command to execute (required)

**Example:**

```bash
task vm:exec -- ls -la ~/workspace-name
task vm:exec -- vm -- apt update
```

## Workspace Management

### `init-workspace`

Initialize workspace contents in an existing VM. Copies the workspace to the user's home directory.

**Usage:**

```bash
task vm:init-workspace [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

**Note:** This is useful for adding workspace to a VM that was created without workspace setup.

### `copy-workspace`

Copy entire workspace to VM. Replaces existing workspace in the user's home directory.

**Usage:**

```bash
task vm:copy-workspace [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

**Warning:** This replaces the entire workspace directory. Use `sync-workspace` for incremental updates.

### `add-workspace`

Add workspace to VM. Copies workspace to the user's home directory (same as during creation).

**Usage:**

```bash
task vm:add-workspace [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

### `sync-workspace`

Sync workspace changes to VM. Uploads only changed files using rsync for efficient synchronization.

**Usage:**

```bash
task vm:sync-workspace [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `VM_INSTANCE_NAME` or `vm`)

**Note:** This is more efficient than `copy-workspace` for regular updates as it only transfers changed files.

## Testing

### `test`

Test VM setup by running through all runbook steps and validating the VM. By default, initializes workspace. Use `--no-workspace` to skip. Use `--keep` to leave VM running after test.

**Usage:**

```bash
task vm:test -- <incus-remote-name> [--keep] [--no-workspace]
```

**Parameters:**

- `<incus-remote-name>` (required): Incus remote name
- `--keep`, `--no-cleanup` (optional): Keep VM running after test (default: delete VM)
- `--no-workspace` (optional): Skip workspace initialization (default: initialize workspace)

**What it does:**

1. Initializes Windsor context "test"
2. Validates remote connection
3. Generates terraform.tfvars
4. Ensures VM image is available
5. Creates VM using Terraform
6. Sets up developer environment
7. Optionally initializes workspace
8. Validates all components (Git, Docker, SSH, etc.)
9. Tests SSH access and GitHub connectivity
10. Optionally cleans up VM (unless `--keep` is used)

**Examples:**

```bash
# Run full test suite (creates VM, validates setup, then deletes it)
task vm:test -- nuc

# Keep VM after test
task vm:test -- nuc --keep

# Skip workspace initialization
task vm:test -- nuc --no-workspace

# Both options
task vm:test -- nuc --keep --no-workspace
```

## Environment Variables

The following environment variables can be set in your `contexts/<context>/windsor.yaml` configuration:

- `INCUS_REMOTE_NAME`: Incus remote name (required). Examples: `local`, `nuc`, `remote-server`
- `VM_INSTANCE_NAME`: Default instance name. Default: `VM`
- `VM_IMAGE`: Default image. Default: `ubuntu/24.04`
- `VM_MEMORY`: Memory allocation for the VM (e.g., `8GB`, `16GB`). Default: `8GB`
- `VM_CPU`: CPU count for the VM. Default: `4`
- `VM_DISK_SIZE`: Disk size for the VM root filesystem (e.g., `50GB`, `100GB`). Default: empty (uses storage pool default)
- `VM_NETWORK_NAME`: Physical network interface for direct network access (e.g., `eno1`, `enp5s0`). Leave empty to use default Incus network
- `VM_STORAGE_POOL`: Storage pool name. Default: `local`
- `VM_AUTOSTART`: Whether to start the VM automatically on host boot. Default: `false`
- `VM_INIT_WORKSPACE`: Whether to initialize workspace contents during creation. Default: `false` (or `true` in test task)
- `DOCKER_HOST`: Docker socket path. Default: `unix:///var/run/docker.sock`

## Prerequisites

- Incus installed and configured
- Terraform installed
- `INCUS_REMOTE_NAME` environment variable set
- For remote deployments: SSH access configured
- For workspace synchronization: rsync installed

## Help

View all available vm commands:

```bash
task vm:help
```

## Taskfile Location

Task definitions are located in `tasks/vm/Taskfile.yaml`.

## Related Documentation

- [VM Runbook](../../runbooks/incusos/vm.md) - Complete guide for creating and managing VMs
- [Terraform VM Configuration](../../../terraform/vm/) - Terraform module for VMs

