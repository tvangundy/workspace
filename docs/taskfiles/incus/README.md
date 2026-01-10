---
title: "Incus Tasks"
description: "Incus container and VM management tasks, including daemon management, instance operations, and Talos VM deployment"
---
# Incus Tasks (`incus:`)

Incus container and VM management, including Talos VM deployment.

## Overview

The `incus:` namespace provides comprehensive tools for managing the Incus daemon, creating and managing instances, and deploying Talos VMs on IncusOS. These tasks handle daemon lifecycle, instance operations, network configuration, and VM deployment workflows.

## Task Reference

| Task | Description |
|------|-------------|
| [`start-daemon`](#start-daemon) | Start the Incus daemon (handles macOS/Colima, snap, systemd, direct binary) |
| [`stop-daemon`](#stop-daemon) | Stop the Incus daemon |
| [`create-instance`](#create-instance) | Create an Incus instance (defaults to `UBUNTU_GITHUB_RUNNER_0_NAME`) |
| [`delete-instance`](#delete-instance) | Delete an Incus instance (defaults to `UBUNTU_GITHUB_RUNNER_0_NAME`) |
| [`download-talos-image`](#download-talos-image) | Download the Talos cloud image for VMs (downloads, decompresses, converts to QCOW2) |
| [`create-physical-network`](#create-physical-network) | Create a physical network for direct attachment to the host network |
| [`launch-talos-vm`](#launch-talos-vm) | Launch a Talos VM on IncusOS |
| [`web-ui`](#web-ui) | Open the Incus Web UI in your browser |

## Daemon Management

### `start-daemon`

Start the Incus daemon. Handles multiple installation methods (macOS/Colima, snap, systemd, direct binary).

**Usage:**

```bash
task incus:start-daemon
```

**What it does:**

On **macOS** (with Colima):

1. Checks if Colima is running
2. Starts Colima with Incus runtime if not running
3. Verifies Incus daemon is accessible

On **Linux**:

1. Tries snap installation first (`sudo snap start incus`)
2. Falls back to systemd service (`sudo systemctl start incus`)
3. Falls back to direct `incusd` binary
4. Falls back to `incus admin init --auto`

**Example:**

```bash
# Start Incus daemon (automatically detects platform)
task incus:start-daemon
```

**Note:** May require `sudo` access on Linux systems.

### `stop-daemon`

Stop the Incus daemon.

**Usage:**

```bash
task incus:stop-daemon
```

**What it does:**

On **macOS** (with Colima):

1. Stops Colima (which stops the Incus daemon inside it)

On **Linux**:

1. Stops systemd service (`sudo systemctl stop incus`)
2. Or kills the incusd process directly

**Example:**

```bash
# Stop Incus daemon
task incus:stop-daemon
```

## Instance Management

### `create-instance`

Create an Incus instance. Defaults to `UBUNTU_GITHUB_RUNNER_0_NAME` if no name provided.

**Usage:**

```bash
task incus:create-instance [<instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name. Defaults to `UBUNTU_GITHUB_RUNNER_0_NAME` environment variable

**Environment Variables:**

- `UBUNTU_GITHUB_RUNNER_0_NAME`: Default instance name if not provided as argument

**Example:**

```bash
# Create instance with default name
task incus:create-instance

# Create instance with custom name
task incus:create-instance -- ubuntu-runner-0
```

**What it does:**

1. Launches Ubuntu 24.04 container from `images:ubuntu/24.04`
2. Uses the specified instance name or default from environment variable

**Note:** The instance is launched but not configured. Use runner tasks to set up GitHub Actions runners.

### `delete-instance`

Delete an Incus instance. Defaults to `UBUNTU_GITHUB_RUNNER_0_NAME` if no name provided.

**Usage:**

```bash
task incus:delete-instance [<instance-name>]
```

**Parameters:**

- `<instance-name>` (optional): Instance name. Defaults to `UBUNTU_GITHUB_RUNNER_0_NAME` environment variable

**Environment Variables:**

- `UBUNTU_GITHUB_RUNNER_0_NAME`: Default instance name if not provided as argument

**Example:**

```bash
# Delete instance with default name
task incus:delete-instance

# Delete instance with custom name
task incus:delete-instance -- ubuntu-runner-0
```

**What it does:**

1. Stops the instance if it's running
2. Deletes the instance
3. Reports success or failure

**Warning:** This permanently deletes the instance and all its data.

## Talos VM Deployment

### `download-talos-image`

Download the Talos cloud image for VMs. Downloads, decompresses, and converts to QCOW2 format.

**Usage:**

```bash
task incus:download-talos-image
```

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `TALOS_IMAGE_VERSION`: Talos image version (e.g., `v1.11.6`)
- `TALOS_IMAGE_ARCH`: Image architecture (e.g., `metal-amd64`)
- `TALOS_IMAGE_SCHEMATIC_ID`: Schematic ID from Image Factory

**Prerequisites:**

- `zstd` installed (for decompression)
- `qemu-img` installed (for format conversion)

**Installation:**

```bash
# macOS
brew install zstd qemu

# Linux
apt-get install zstd qemu-utils
```

**What it does:**

1. Creates directory: `contexts/<context>/devices/talos/`
2. Downloads compressed image (`.raw.zst`) from Image Factory
3. Decompresses to raw format (`.raw`)
4. Converts to QCOW2 format (`.qcow2`) required for Incus VMs
5. Skips steps if files already exist

**Output:** Path to final QCOW2 image: `contexts/<context>/devices/talos/talos-metal-amd64.qcow2`

**Example:**

```bash
export WINDSOR_CONTEXT=my-context
export TALOS_IMAGE_VERSION=v1.11.6
export TALOS_IMAGE_ARCH=metal-amd64
export TALOS_IMAGE_SCHEMATIC_ID=<your-schematic-id>

task incus:download-talos-image
```

### `create-physical-network`

Create a physical network for direct attachment to the host network. Allows VMs to get IP addresses directly from your network's DHCP server.

**Usage:**

```bash
task incus:create-physical-network
```

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name

**Optional Environment Variables:**

- `PHYSICAL_INTERFACE`: Physical network interface name (default: `eno1`)

**Prerequisites:**

- The physical interface must have the `instances` role assigned
- Run `incus admin os system network edit` to add the role if needed

**What it does:**

1. Checks if network already exists (skips if exists and is correct type)
2. Creates a physical network type using the specified interface
3. Verifies the network was created successfully

**Example:**

```bash
# Use default interface (eno1)
task incus:create-physical-network

# Use custom interface
export PHYSICAL_INTERFACE=eth0
task incus:create-physical-network
```

**Note:** VMs attached to this network will get IP addresses directly from your physical network's DHCP server.

### `launch-talos-vm`

Launch a Talos VM on IncusOS.

**Usage:**

```bash
task incus:launch-talos-vm -- <vm-name> <vm-ip>
```

**Parameters:**

- `<vm-name>`: Name for the VM (required)
- `<vm-ip>`: Expected IP address (informational - actual IP assigned by DHCP)

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `INCUS_REMOTE_NAME`: Incus remote name
- `TALOS_IMAGE_VERSION`: Talos image version
- `TALOS_IMAGE_ARCH`: Image architecture

**Optional Environment Variables:**

- `PHYSICAL_INTERFACE`: Physical network interface name (default: `eno1`)

**Prerequisites:**

- Talos image downloaded (`task incus:download-talos-image`)
- Physical network created (`task incus:create-physical-network`)

**What it does:**

1. Checks if VM already exists (skips if exists)
2. Imports Talos image if not already imported
3. Launches VM with:
   - 2GB memory, 2 CPUs
   - Physical network attachment
   - Secure Boot disabled (Talos doesn't support it)
   - Auto-start enabled
4. Waits for VM to start
5. Reports expected IP address

**Example:**

```bash
task incus:launch-talos-vm -- talos-cp 192.168.2.201
```

**Note:** The actual IP address will be assigned by DHCP and may differ from the specified `vm-ip`.

## Utilities

### `web-ui`

Open the Incus Web UI in your browser.

**Usage:**

```bash
task incus:web-ui
```

**Environment Variables (Required):**

- `INCUS_REMOTE_IP_0`: IP address of the Incus remote server

**What it does:**

1. Opens `https://<INCUS_REMOTE_IP_0>:8443/` in the default browser
2. Handles macOS, Linux, and other platforms

**Example:**

```bash
export INCUS_REMOTE_IP_0=192.168.2.100
task incus:web-ui
```

## Environment Variables

The following environment variables are commonly used:

- `INCUS_REMOTE_NAME`: Incus remote name (required for most tasks)
- `UBUNTU_GITHUB_RUNNER_0_NAME`: Default instance name for runner instances
- `WINDSOR_CONTEXT`: Windsor context name (required for Talos VM tasks)
- `TALOS_IMAGE_VERSION`: Talos image version (e.g., `v1.11.6`)
- `TALOS_IMAGE_ARCH`: Image architecture (e.g., `metal-amd64`)
- `TALOS_IMAGE_SCHEMATIC_ID`: Image Factory schematic ID
- `PHYSICAL_INTERFACE`: Physical network interface name (default: `eno1`)
- `INCUS_REMOTE_IP_0`: IP address of Incus remote server (for web UI)

## Prerequisites

- Incus installed and configured
- For Talos VMs: `zstd` and `qemu-img` installed
- For physical networks: Physical interface configured with `instances` role
- Network access to Incus remote server (for remote operations)

## Help

View all available Incus commands:

```bash
task incus:help
```

## Taskfile Location

Task definitions are located in `tasks/incus/Taskfile.yaml`.
