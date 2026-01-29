---
title: "VM Tasks"
description: "Ubuntu virtual machine management tasks for creating and managing VMs on Incus using Terraform"
---
# VM Tasks (`vm:`)

Ubuntu virtual machine management for creating and managing VMs on Incus using Terraform.

## Overview

The `vm:` namespace provides tools for creating and managing Ubuntu virtual machines on Incus using Terraform. The primary entry point is `vm:instantiate`. For VM info, start, stop, restart, shell, SSH, and exec, use the Incus CLI (e.g. `incus info $INCUS_REMOTE_NAME:<vm>`, `incus exec $INCUS_REMOTE_NAME:<vm> -- bash`).

## Task Reference

| Task | Description |
|------|-------------|
| [`instantiate`](#instantiate) | Create a VM instance using Terraform with complete developer environment setup |
| [`instantiate:parse-args`](#instantiateparse-args) | Parse CLI arguments for instantiate |
| [`instantiate:initialize-context`](#instantiateinitialize-context) | Initialize Windsor context for instantiate |
| [`instantiate:verify-remote`](#instantiateverify-remote) | Verify remote connection exists |
| [`instantiate:check-vm-image`](#instantiatecheck-vm-image) | Ensure VM image is available on remote |
| [`instantiate:create-vm`](#instantiatecreate-vm) | Create VM using Terraform and setup developer environment |
| [`instantiate:setup-ssh`](#instantiatesetup-ssh) | Setup SSH access for the user on the VM |
| [`instantiate:setup-incus`](#instantiatesetup-incus) | Setup Incus client on the VM and configure remote connection |
| [`instantiate:install-tools`](#instantiateinstall-tools) | Install tools jq, Homebrew, aqua, docker, and windsor |
| [`instantiate:init-workspace`](#instantiateinit-workspace) | Initialize workspace on the VM if VM_INIT_WORKSPACE is true |
| [`instantiate:validate-vm`](#instantiatevalidate-vm) | Validate VM setup and functionality |
| [`instantiate:cleanup-if-needed`](#instantiatecleanup-if-needed) | Cleanup VM if --keep flag was not set |
| [`generate-tfvars`](#generate-tfvars) | Generate terraform.tfvars from environment variables |
| [`terraform:init`](#terraforminit) | Initialize Terraform for the VM |
| [`terraform:plan`](#terraformplan) | Show Terraform plan for the VM |
| [`terraform:apply`](#terraformapply) | Apply Terraform configuration to create the VM |
| [`terraform:destroy`](#terraformdestroy) | Destroy the VM using Terraform |
| [`list`](#list) | List all VM instances |
| [`destroy`](#destroy) | Destroy a VM using Terraform |

## Instance Creation

### `instantiate`

Create an Ubuntu virtual machine instance using Terraform with complete developer environment setup. This is the primary way to create a new VM.

**Usage:**

```bash
task vm:instantiate -- <remote-name> [<vm-name>] [--keep] [--no-workspace] [--windsor-up]
```

**Parameters:**

- `<remote-name>` (required): Name of the Incus remote (e.g., `nuc`, `local`)
- `<vm-name>` (optional): Name for the VM (default: `vm`)
- `--keep`, `--no-cleanup` (optional): Keep VM running after creation (default: delete VM if used in test context)
- `--no-workspace` (optional): Skip workspace initialization (default: initialize workspace if `VM_INIT_WORKSPACE=true`)
- `--windsor-up` (optional): Run `windsor init` and `windsor up` after workspace setup

**What it does:**

1. Parses CLI arguments and sets up environment
2. Initializes Windsor context for the VM
3. Verifies remote connection exists and is reachable
4. Ensures VM image is available on the remote
5. Creates VM using Terraform
6. Sets up SSH access for the user
7. Sets up Incus client on the VM and configures remote connection
8. Installs developer tools (jq, Homebrew, Aqua, Docker, Windsor CLI)
9. Optionally initializes workspace contents
10. Validates VM setup and functionality
11. Optionally cleans up VM (unless `--keep` is used)

**Examples:**

```bash
# Create a VM on remote 'nuc' with default name 'vm'
task vm:instantiate -- nuc

# Create a VM with custom name
task vm:instantiate -- nuc my-vm

# Create a VM and keep it running
task vm:instantiate -- nuc my-vm --keep

# Create a VM without workspace initialization
task vm:instantiate -- nuc my-vm --no-workspace

# Create a VM and run windsor up after workspace setup
task vm:instantiate -- nuc my-vm --windsor-up
```

**Note:** Environment setup (developer tools, Docker, etc.) is only performed for remote deployments (`INCUS_REMOTE_NAME != local`).

### `instantiate:parse-args`

Parse CLI arguments for the instantiate task. This is automatically called by `instantiate` but can be run independently for testing.

**Usage:**

```bash
task vm:instantiate:parse-args
```

### `instantiate:initialize-context`

Initialize Windsor context for instantiate. Creates or updates `windsor.yaml` with appropriate environment variables.

**Usage:**

```bash
task vm:instantiate:initialize-context
```

### `instantiate:verify-remote`

Verify that the Incus remote connection exists and is reachable.

**Usage:**

```bash
task vm:instantiate:verify-remote
```

### `instantiate:check-vm-image`

Ensure the VM image is available on the remote. Downloads the image if it's not already present.

**Usage:**

```bash
task vm:instantiate:check-vm-image
```

### `instantiate:create-vm`

Create VM using Terraform and setup developer environment. This includes:
- Generating terraform.tfvars
- Initializing Terraform
- Applying Terraform configuration
- Setting up developer environment (for remote deployments)

**Usage:**

```bash
task vm:instantiate:create-vm
```

### `instantiate:setup-ssh`

Setup SSH access for the user on the VM. Creates user matching host user, copies SSH keys, and configures SSH server.

**Usage:**

```bash
task vm:instantiate:setup-ssh
```

### `instantiate:setup-incus`

Setup Incus client on the VM and configure remote connection. This allows the VM to manage other VMs on the remote Incus server.

**Usage:**

```bash
task vm:instantiate:setup-incus
```

### `instantiate:install-tools`

Install developer tools including jq, Homebrew, Aqua, Docker, and Windsor CLI.

**Usage:**

```bash
task vm:instantiate:install-tools
```

### `instantiate:init-workspace`

Initialize workspace on the VM if `VM_INIT_WORKSPACE` is true. Copies workspace contents to the user's home directory.

**Usage:**

```bash
task vm:instantiate:init-workspace
```

### `instantiate:validate-vm`

Validate VM setup and functionality. Checks that all components are working correctly.

**Usage:**

```bash
task vm:instantiate:validate-vm
```

### `instantiate:cleanup-if-needed`

Cleanup VM if `--keep` flag was not set. This is typically used in test contexts.

**Usage:**

```bash
task vm:instantiate:cleanup-if-needed
```

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

### `destroy`

Destroy a VM using Terraform. **Warning:** This permanently removes the VM and all its data.

**Usage:**

```bash
# Destroy VM using default name from environment
task vm:destroy

# Or specify the VM name explicitly
task vm:destroy -- <vm-name>
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
- `--keep`, `--no-cleanup` (optional): Keep VM running after test (default: destroy VM)
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
# Run full test suite (creates VM, validates setup, then destroys it)
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

