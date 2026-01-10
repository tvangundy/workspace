---
title: "Device Tasks"
description: "Device management and Talos cluster configuration tasks for preparing physical devices, managing disk images, and configuring Talos clusters"
---
# Device Tasks (`device:`)

Device management for preparing physical devices, managing disk images, and configuring Talos clusters.

## Overview

The `device:` namespace provides tools for managing physical devices, preparing boot media, downloading and writing disk images, and configuring Talos Linux clusters. These tasks are essential for bootstrapping Talos clusters on bare-metal hardware.

## Task Reference

| Task | Description |
|------|-------------|
| [`download-image`](#download-image) | Download the Talos image from the Image Factory |
| [`decompress-image`](#decompress-image) | Decompress the Talos image (placeholder) |
| [`download-incus-image`](#download-incus-image) | Download or move IncusOS image to the devices folder |
| [`download-ubuntu-iso`](#download-ubuntu-iso) | Download or move Ubuntu ISO to the devices folder |
| [`list-disks`](#list-disks) | List available USB disks/SD cards on macOS |
| [`write-disk`](#write-disk) | Write the Talos image to one or more USB drives in parallel |
| [`write-ubuntu-iso`](#write-ubuntu-iso) | Write the Ubuntu ISO to one or more USB drives in parallel |
| [`write-incus-disk`](#write-incus-disk) | Write the IncusOS image to one or more USB drives in parallel |
| [`unmount-disk`](#unmount-disk) | Unmount one or more USB disks |
| [`eject-disk`](#eject-disk) | Eject one or more USB disks (automatically unmounts first) |
| [`format-xfs`](#format-xfs) | Format USB disk as XFS (requires Linux, placeholder) |
| [`get-disks`](#get-disks) | Get disk information from a Talos node |
| [`generate-talosconfig`](#generate-talosconfig) | Generate Talos configuration files for a cluster |
| [`apply-configuration`](#apply-configuration) | Apply Talos configuration to cluster nodes |
| [`set-endpoints`](#set-endpoints) | Set Talos API endpoints in the talosconfig file |
| [`bootstrap-etc-cluster`](#bootstrap-etc-cluster) | Bootstrap the etcd cluster (run once on control plane) |
| [`retrieve-kubeconfig`](#retrieve-kubeconfig) | Retrieve Kubernetes kubeconfig file from the cluster |
| [`cluster-health`](#cluster-health) | Check cluster health status |
| [`talos-dashboard`](#talos-dashboard) | Run the Talos dashboard for monitoring cluster nodes |

## Image Management

### `download-image`

Download the Talos image from the Image Factory.

**Usage:**

```bash
task device:download-image
```

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name (set using `windsor context set <context>`)
- `RPI_IMAGE_ARCH`: Image architecture (e.g., `metal-arm64`, `metal-amd64`)
- `RPI_IMAGE_SCHEMATIC_ID`: Schematic ID from Image Factory
- `RPI_IMAGE_VERSION`: Talos image version (e.g., `v1.11.5`)

**What it does:**

1. Creates directory structure: `contexts/<context>/devices/<arch>/`
2. Downloads the compressed image (`.raw.xz`) from Image Factory
3. Decompresses the image to `.raw` format
4. Saves to: `contexts/<context>/devices/<arch>/<arch>.raw`

**Output:** Path to the downloaded image file.

### `decompress-image`

Decompress the Talos image. Currently a placeholder.

**Usage:**

```bash
task device:decompress-image
```

**Note:** This functionality is typically handled automatically by `download-image`.

### `download-incus-image`

Download or move IncusOS image to the devices folder.

**Usage:**

```bash
task device:download-incus-image
```

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `INCUS_IMAGE_FILE`: Path to the IncusOS image file

**Example:**

```bash
# Set environment variable
export INCUS_IMAGE_FILE=~/Downloads/IncusOS_202512250102.img

# Download/copy the image
task device:download-incus-image
```

**What it does:**

1. Creates directory: `contexts/<context>/devices/incus/`
2. Copies the image file to `contexts/<context>/devices/incus/incusos.img`

### `download-ubuntu-iso`

Download or move Ubuntu ISO to the devices folder.

**Usage:**

```bash
task device:download-ubuntu-iso
```

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `UBUNTU_ISO_FILE`: Path to the Ubuntu ISO file

**Example:**

```bash
# Set environment variable
export UBUNTU_ISO_FILE=~/Downloads/ubuntu-24.04-desktop-amd64.iso

# Download/copy the ISO
task device:download-ubuntu-iso
```

**What it does:**

1. Creates directory: `contexts/<context>/devices/ubuntu/`
2. Copies the ISO file to `contexts/<context>/devices/ubuntu/ubuntu.iso`

## Disk Operations

### `list-disks`

List available USB disks/SD cards on macOS.

**Usage:**

```bash
task device:list-disks
```

**Output:** Shows all connected disk devices with their identifiers.

**Note:** On Linux, use `lsblk` or `fdisk -l` directly.

### `write-disk`

Write the Talos image to one or more USB drives in parallel.

**Usage:**

```bash
task device:write-disk [-- <disk_count>]
```

**Parameters:**

- `<disk_count>` (optional): Number of consecutive disks to write to, starting from `USB_DISK`. Default: `1`

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `RPI_IMAGE_ARCH`: Image architecture (must match downloaded image)
- `USB_DISK`: First disk device (e.g., `/dev/disk4`)

**Example:**

```bash
# Write to single disk
export USB_DISK=/dev/disk4
task device:write-disk

# Write to 3 consecutive disks (disk4, disk5, disk6)
task device:write-disk -- 3
```

**What it does:**

1. Validates disk is not mounted
2. Unmounts the disk if necessary
3. Writes the raw image to the disk(s) using `dd`
4. Monitors progress and shows completion status
5. Verifies the write by comparing disk contents with source image

**Important Notes:**

- **Warning:** This will overwrite all data on the target disk(s)
- Ensure disks are unmounted before writing
- The write process can take 15-30 minutes depending on disk speed
- Progress is shown every 30 seconds during the write
- All disks are written in parallel for efficiency

### `write-ubuntu-iso`

Write the Ubuntu ISO to one or more USB drives in parallel.

**Usage:**

```bash
task device:write-ubuntu-iso [-- <disk_count>]
```

**Parameters:**

- `<disk_count>` (optional): Number of consecutive disks to write to. Default: `1`

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `USB_DISK`: First disk device (e.g., `/dev/disk4`)

**Prerequisites:**

- Run `task device:download-ubuntu-iso` first to prepare the ISO

### `write-incus-disk`

Write the IncusOS image to one or more USB drives in parallel.

**Usage:**

```bash
task device:write-incus-disk [-- <disk_count>]
```

**Parameters:**

- `<disk_count>` (optional): Number of consecutive disks to write to. Default: `1`

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `USB_DISK`: First disk device (e.g., `/dev/disk4`)

**Prerequisites:**

- Run `task device:download-incus-image` first to prepare the image

### `unmount-disk`

Unmount one or more USB disks.

**Usage:**

```bash
task device:unmount-disk [-- <disk_count>]
```

**Parameters:**

- `<disk_count>` (optional): Number of consecutive disks to unmount. Default: `1`

**Environment Variables (Required):**

- `USB_DISK`: First disk device (e.g., `/dev/disk4`)

**Example:**

```bash
# Unmount single disk
task device:unmount-disk

# Unmount 3 consecutive disks
task device:unmount-disk -- 3
```

### `eject-disk`

Eject one or more USB disks. Automatically unmounts disks first.

**Usage:**

```bash
task device:eject-disk [-- <disk_count>]
```

**Parameters:**

- `<disk_count>` (optional): Number of consecutive disks to eject. Default: `1`

**Environment Variables (Required):**

- `USB_DISK`: First disk device (e.g., `/dev/disk4`)

**Dependencies:** Automatically runs `unmount-disk` first.

### `format-xfs`

Format USB disk as XFS (requires Linux).

**Usage:**

```bash
task device:format-xfs
```

**Note:** This is a placeholder task with manual instructions. Use `mkfs.xfs` or `mkfs.ext4` directly on Linux.

### `get-disks`

Get disk information from a Talos node.

**Usage:**

```bash
task device:get-disks -- <control-plane-ip>
```

**Parameters:**

- `<control-plane-ip>`: IP address of the control plane node

**Example:**

```bash
task device:get-disks -- 192.168.2.31
```

## Talos Configuration

### `generate-talosconfig`

Generate Talos configuration files for a cluster.

**Usage:**

```bash
task device:generate-talosconfig -- <install-disk>
```

**Parameters:**

- `<install-disk>`: Disk identifier where Talos will be installed (e.g., `/dev/sda`)

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `CLUSTER_NAME`: Name of the cluster
- `CONTROL_PLANE_IP`: IP address of the control plane node

**Example:**

```bash
task device:generate-talosconfig -- /dev/sda
```

**What it does:**

1. Creates directory: `contexts/<context>/clusters/<cluster-name>/`
2. Generates `controlplane.yaml` and `worker.yaml` configuration files
3. Generates `talosconfig` file and moves it to the configured location

**Output Files:**

- `contexts/<context>/clusters/<cluster-name>/controlplane.yaml`
- `contexts/<context>/clusters/<cluster-name>/worker.yaml`
- `contexts/<context>/.talos/talosconfig` (moved from generated location)

### `apply-configuration`

Apply Talos configuration to cluster nodes.

**Usage:**

```bash
task device:apply-configuration -- <control-plane-ip> [<worker-ip1> <worker-ip2> ...]
```

**Parameters:**

- `<control-plane-ip>`: IP address of the control plane node (required)
- `<worker-ip1>`, `<worker-ip2>`, etc.: IP addresses of worker nodes (optional)

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `CLUSTER_NAME`: Name of the cluster
- `WINDSOR_PROJECT_ROOT`: Windsor project root directory
- `TALOSCONFIG`: Path to talosconfig file

**Example:**

```bash
# Apply to control plane only
task device:apply-configuration -- 192.168.2.31

# Apply to control plane and 2 workers
task device:apply-configuration -- 192.168.2.31 192.168.2.111 192.168.2.125
```

**What it does:**

1. Validates node IP addresses and reachability
2. Applies `controlplane.yaml` to the control plane node
3. Applies `worker.yaml` to each worker node (if specified)

**Note:** Nodes must be running Talos (booted from the image) for this to work.

### `set-endpoints`

Set Talos API endpoints in the talosconfig file.

**Usage:**

```bash
task device:set-endpoints -- <control-plane-ip>
```

**Parameters:**

- `<control-plane-ip>`: IP address of the control plane node

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `CLUSTER_NAME`: Name of the cluster

### `bootstrap-etc-cluster`

Bootstrap the etcd cluster. **Run this once on the control plane node.**

**Usage:**

```bash
task device:bootstrap-etc-cluster -- <control-plane-ip>
```

**Parameters:**

- `<control-plane-ip>`: IP address of the control plane node

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `CLUSTER_NAME`: Name of the cluster

**Warning:** Only run this once per cluster. Running it multiple times can corrupt the etcd cluster.

### `retrieve-kubeconfig`

Retrieve Kubernetes kubeconfig file from the cluster.

**Usage:**

```bash
task device:retrieve-kubeconfig -- <control-plane-ip>
```

**Parameters:**

- `<control-plane-ip>`: IP address of the control plane node

**Environment Variables (Required):**

- `WINDSOR_CONTEXT`: Windsor context name
- `CLUSTER_NAME`: Name of the cluster
- `KUBECONFIG_FILE`: Path where kubeconfig will be saved

**Example:**

```bash
export KUBECONFIG_FILE=~/.kube/config
task device:retrieve-kubeconfig -- 192.168.2.31
```

## Cluster Management

### `cluster-health`

Check cluster health status.

**Usage:**

```bash
task device:cluster-health -- <control-plane-ip>
```

**Parameters:**

- `<control-plane-ip>`: IP address of the control plane node

**Example:**

```bash
task device:cluster-health -- 192.168.2.31
```

### `talos-dashboard`

Run the Talos dashboard for monitoring cluster nodes.

**Usage:**

```bash
task device:talos-dashboard -- <control-plane-ip>
```

**Parameters:**

- `<control-plane-ip>`: IP address of the control plane node

**Example:**

```bash
task device:talos-dashboard -- 192.168.2.31
```

**Note:** This starts an interactive dashboard. Press Ctrl+C to exit.

## Environment Variables

The following environment variables are commonly used:

- `WINDSOR_CONTEXT`: Windsor context name (required for most tasks)
- `RPI_IMAGE_ARCH`: Talos image architecture (e.g., `metal-arm64`, `metal-amd64`)
- `RPI_IMAGE_SCHEMATIC_ID`: Image Factory schematic ID
- `RPI_IMAGE_VERSION`: Talos image version (e.g., `v1.11.5`)
- `USB_DISK`: USB disk device (e.g., `/dev/disk4`)
- `CLUSTER_NAME`: Cluster name
- `CONTROL_PLANE_IP`: Control plane node IP address
- `TALOSCONFIG`: Path to talosconfig file
- `KUBECONFIG_FILE`: Path to kubeconfig file
- `INCUS_IMAGE_FILE`: Path to IncusOS image file
- `UBUNTU_ISO_FILE`: Path to Ubuntu ISO file

## Prerequisites

- Talos CLI (`talosctl`) installed
- Access to Image Factory for downloading images
- Physical access to target devices for disk operations
- Network access to cluster nodes for configuration tasks

## Help

View all available device commands:

```bash
task device:help
```

## Taskfile Location

Task definitions are located in `tasks/device/Taskfile.yaml`.
