---
title: "Dev Tasks"
description: "Development environment management tasks for creating and managing development containers and VMs on Incus"
---
# Dev Tasks (`dev:`)

Development environment management for creating and managing development containers and VMs on Incus.

## Overview

The `dev:` namespace provides comprehensive tools for creating, managing, and interacting with development environments running in Incus containers or virtual machines. These tasks handle instance lifecycle management, workspace synchronization, SSH access, and environment setup.

## Task Reference

| Task | Description |
|------|-------------|
| [`create`](#create) | Create a dev container or virtual machine instance with optional workspace synchronization |
| [`create:validate`](#createvalidate) | Validate input and check prerequisites for instance creation |
| [`create:instance`](#createinstance) | Create and launch the instance without environment setup |
| [`create:setup-env`](#createsetup-env) | Setup developer environment in an existing instance |
| [`start`](#start) | Start a dev instance |
| [`stop`](#stop) | Stop a dev instance |
| [`restart`](#restart) | Restart a dev instance |
| [`list`](#list) | List all dev instances on the configured remote |
| [`info`](#info) | Get detailed information about a dev instance |
| [`debug`](#debug) | Debug performance and resource usage of a dev instance |
| [`delete`](#delete) | Delete a dev instance (permanently removes instance and all data) |
| [`shell`](#shell) | Open an interactive shell in a dev instance |
| [`ssh`](#ssh) | SSH into a VM instance (VMs only, not containers) |
| [`ssh-info`](#ssh-info) | Show SSH connection information for an instance |
| [`exec`](#exec) | Execute a command in a dev instance |
| [`init-workspace`](#init-workspace) | Initialize workspace contents in an existing VM |
| [`copy-workspace`](#copy-workspace) | Copy entire workspace to dev-vm (replaces existing) |
| [`add-workspace`](#add-workspace) | Add workspace to dev-vm (copies workspace to user's home directory) |
| [`sync-workspace`](#sync-workspace) | Sync workspace changes to dev-vm using rsync (incremental updates) |
| [`fix-docker`](#fix-docker) | Fix Docker socket permissions in the container |
| [`fix-compose`](#fix-compose) | Fix Docker Compose file to add privileged mode to all services |

## Instance Creation

### `create`

Create a dev container or virtual machine instance with optional workspace synchronization.

**Usage:**

```bash
task dev:create [-- <type> <image> [--name <name>]]
```

**Parameters:**

- `<type>` (optional): Instance type - `container` or `vm` (defaults to `DEV_INSTANCE_TYPE` or `container`)
- `<image>` (optional): Base image to use, e.g., `ubuntu/24.04` (defaults to `DEV_IMAGE` or `ubuntu/24.04`)
- `--name <name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME` or `dev-<type>`)

**Examples:**

```bash
# Use environment variable defaults
task dev:create

# Create a VM with Ubuntu 24.04
task dev:create -- vm ubuntu/24.04

# Create a container with custom name
task dev:create -- container ubuntu/24.04 --name my-dev-container

# Create a VM with custom name
task dev:create -- vm ubuntu/24.04 --name my-dev-vm
```

**What it does:**

1. Validates prerequisites and environment variables
2. Creates and launches the instance
3. Sets up the developer environment (for remote deployments):
   - Installs essential developer tools (git, curl, vim, etc.)
   - Installs Incus (for Ubuntu 24.04+)
   - Creates user matching host user
   - Installs Aqua package manager
   - Installs Docker (if not present)
   - Configures SSH access
   - Sets up workspace directory

**Note:** Workspace setup is only performed for remote deployments (`INCUS_REMOTE_NAME != local`).

### `create:validate`

Validate input and check prerequisites for instance creation. This is automatically called by `create` but can be run independently.

**Usage:**

```bash
task dev:create:validate [-- <type> <image> [--name <name>]]
```

**Parameters:** Same as `create`

### `create:instance`

Create and launch the instance without environment setup. This is automatically called by `create` but can be run independently.

**Usage:**

```bash
task dev:create:instance [-- <type> <image> [--name <name>]]
```

**Parameters:** Same as `create`

### `create:setup-env`

Setup developer environment in an existing instance. Automatically called by `create` for remote deployments.

**Usage:**

```bash
task dev:create:setup-env [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

## Instance Management

### `start`

Start a dev instance.

**Usage:**

```bash
task dev:start [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Example:**

```bash
task dev:start -- my-dev-vm
```

### `stop`

Stop a dev instance.

**Usage:**

```bash
task dev:stop [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

### `restart`

Restart a dev instance.

**Usage:**

```bash
task dev:restart [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

### `list`

List all dev instances on the configured remote.

**Usage:**

```bash
task dev:list
```

**Output:** Shows all instances with their status, IP addresses, and resource usage.

### `info`

Get detailed information about a dev instance.

**Usage:**

```bash
task dev:info [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Output:** Shows instance configuration, resources, network information, and status.

### `debug`

Debug performance and resource usage of a dev instance.

**Usage:**

```bash
task dev:debug [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Output:** Shows CPU, memory, disk, and network usage statistics.

### `delete`

Delete a dev instance. **Warning:** This permanently removes the instance and all its data.

**Usage:**

```bash
task dev:delete [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Example:**

```bash
task dev:delete -- my-dev-vm
```

## Access

### `shell`

Open an interactive shell in a dev instance (similar to `docker exec -it`).

**Usage:**

```bash
task dev:shell [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Example:**

```bash
task dev:shell -- my-dev-vm
```

### `ssh`

SSH into a VM instance. Connects directly via SSH using the instance's IP address.

**Usage:**

```bash
task dev:ssh [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Note:** This command only works for VM instances, not containers. Use `shell` for containers.

**Example:**

```bash
task dev:ssh -- my-dev-vm
```

### `ssh-info`

Show SSH connection information for an instance.

**Usage:**

```bash
task dev:ssh-info [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Output:** Shows SSH host, port, username, and connection command.

### `exec`

Execute a command in a dev instance (similar to `docker exec`).

**Usage:**

```bash
task dev:exec -- <instance-name> -- <command>
```

**Parameters:**

- `<instance-name>`: Instance name (required)
- `<command>`: Command to execute (required)

**Example:**

```bash
task dev:exec -- my-dev-vm -- ls -la
task dev:exec -- my-dev-vm -- apt-get update
```

## Workspace Management

### `init-workspace`

Initialize workspace contents in an existing VM. Copies the workspace to the user's home directory.

**Usage:**

```bash
task dev:init-workspace [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Note:** This is useful for adding workspace to a VM that was created without workspace setup.

### `copy-workspace`

Copy entire workspace to dev-vm. Replaces existing workspace in the user's home directory.

**Usage:**

```bash
task dev:copy-workspace [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Warning:** This replaces the entire workspace directory. Use `sync-workspace` for incremental updates.

### `add-workspace`

Add workspace to dev-vm. Copies workspace to the user's home directory (same as during creation).

**Usage:**

```bash
task dev:add-workspace [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

### `sync-workspace`

Sync workspace changes to dev-vm. Uploads only changed files using rsync for efficient synchronization.

**Usage:**

```bash
task dev:sync-workspace [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**Note:** This is more efficient than `copy-workspace` for regular updates as it only transfers changed files.

## Docker Maintenance

### `fix-docker`

Fix Docker socket permissions in the container. This is useful when Docker socket permissions get reset or when you encounter permission denied errors.

**Usage:**

```bash
task dev:fix-docker [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**What it does:**

1. Checks if instance exists and is running
2. Sets Docker socket permissions to 666 (world-readable/writable)
3. Sets Docker socket group ownership to `docker`
4. Verifies Docker is accessible

**Example:**

```bash
task dev:fix-docker
task dev:fix-docker -- my-dev
```

**Note:** Socket permissions may reset after container restarts. This task should be run whenever you encounter Docker permission errors.

### `fix-compose`

Fix Docker Compose file to add `privileged: true` to all services. Required for Docker-in-Docker scenarios in Incus containers on Colima.

**Usage:**

```bash
task dev:fix-compose [-- <instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name (defaults to `DEV_INSTANCE_NAME`)

**What it does:**

1. Locates the Docker Compose file at `.windsor/docker-compose.yaml` in the workspace
2. Checks each service for `privileged: true` setting
3. Adds `privileged: true` to services that don't have it
4. Reports which services were updated

**Example:**

```bash
task dev:fix-compose
task dev:fix-compose -- my-dev
```

**Note:** This is required because Windsor may regenerate the compose file without privileged mode. Run this after `windsor up` generates the compose file, but before containers are created.

## Environment Variables

The following environment variables can be set in your `windsor.yaml` configuration:

- `DEV_INSTANCE_TYPE`: Default instance type (`container` or `vm`). Default: `container`
- `DEV_IMAGE`: Default base image. Default: `ubuntu/24.04`
- `DEV_INSTANCE_NAME`: Default instance name. Default: `dev-<type>`
- `INCUS_REMOTE_NAME`: Incus remote name (required). Examples: `local`, `nuc`, `remote-server`
- `DEV_SHARE_WORKSPACE`: Whether to share workspace during creation. Default: `true` for remote, `false` for local

## Prerequisites

- Incus installed and configured
- `INCUS_REMOTE_NAME` environment variable set
- For remote deployments: SSH access configured
- For workspace synchronization: rsync installed

## Help

View all available dev commands:

```bash
task dev:help
```

## Taskfile Location

Task definitions are located in `tasks/dev/Taskfile.yaml`.
