---
title: "VM Tasks"
description: "Ubuntu virtual machine management tasks for creating and managing VMs on Incus using Terraform"
---
# VM Tasks (`vm:`)

Ubuntu virtual machine management for creating and managing VMs on Incus using Terraform.

## Overview

The `vm:` namespace provides tasks for creating and managing Ubuntu VMs on Incus. Use `task vm:instantiate` to create a VM; use the **Incus** CLI for start/stop/restart, info, exec, and SSH (e.g. `incus exec $INCUS_REMOTE_NAME:<instance-name> -- bash`).

## Task Reference

| Task | Description |
|------|-------------|
| [`instantiate`](#instantiate) | Create a VM instance using Terraform with complete developer environment setup |
| [`instantiate:parse-args`](#instantiateparse-args) | Parse CLI arguments for instantiate |
| [`instantiate:initialize-context`](#instantiateinitialize-context) | Initialize Windsor context for instantiate |
| [`instantiate:verify-remote`](#instantiateverify-remote) | Verify remote connection exists |
| [`instantiate:check-vm-image`](#instantiatecheck-vm-image) | Ensure VM image is available on remote |
| [`instantiate:create-vm`](#instantiatecreate-vm) | Create VM using Terraform and setup developer environment |
| [`instantiate:setup-incus`](#instantiatesetup-incus) | Setup Incus client on the VM and configure remote connection |
| [`instantiate:validate-vm`](#instantiatevalidate-vm) | Validate VM setup and functionality |
| [`instantiate:setup-ssh`](#instantiatesetup-ssh) | Setup SSH access for the user on the VM |
| [`instantiate:init-workspace`](#instantiateinit-workspace) | Initialize workspace on the VM if VM_INIT_WORKSPACE is true |
| [`instantiate:install-tools`](#instantiateinstall-tools) | Install tools jq, Homebrew, aqua, docker, and windsor |
| [`instantiate:cleanup-if-needed`](#instantiatecleanup-if-needed) | Cleanup VM if --keep flag was not set |
| [`generate-tfvars`](#generate-tfvars) | Generate terraform.tfvars from environment variables |
| [`terraform:init`](#terraforminit) | Initialize Terraform for the VM |
| [`terraform:plan`](#terraformplan) | Show Terraform plan for the VM |
| [`terraform:apply`](#terraformapply) | Apply Terraform configuration to create the VM |
| [`terraform:destroy`](#terraformdestroy) | Destroy the VM using Terraform |
| [`list`](#list) | List all VM instances |
| [`destroy`](#destroy) | Destroy a VM using Terraform |
| [`delete`](#delete) | Delete VM directly via Incus (bypasses Terraform) |
| [`help`](#help) | Show vm commands |

**Note:** VM start/stop/restart, info, shell, exec, and SSH are done via the **Incus** CLI: `incus start/stop/restart/info/exec $INCUS_REMOTE_NAME:<instance-name>`. For SSH, use the VM's IP (e.g. from `incus list`) with your normal SSH client.

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

### `list`

List all VM instances on the configured remote.

**Usage:**

```bash
task vm:list
```

**Output:** Shows all instances with their status, IP addresses, and resource usage.

### `destroy`

Destroy a VM using Terraform. **Warning:** This permanently removes the VM and all its data.

**Usage:**

```bash
# Destroy VM using default name from environment
task vm:destroy

# Or specify the VM name explicitly
task vm:destroy -- <vm-name>
```

### `delete`

Delete VM directly via Incus (bypasses Terraform). Use when Terraform state is lost or for manual cleanup.

**Usage:**

```bash
task vm:delete [-- <instance-name>]
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

