---
title: "Device Tasks"
description: "Device management and Talos cluster configuration tasks"
---
# Device Tasks (`device:`)

Device management for preparing physical devices, managing disk images, and configuring Talos clusters.

## Image Management

- `task device:download-image` - Download the Talos image
- `task device:decompress-image` - Decompress the Talos image
- `task device:download-incus-image` - Download or move IncusOS image to the devices folder
- `task device:download-ubuntu-iso` - Download or move Ubuntu ISO to the devices folder

## Disk Operations

- `task device:list-disks` - List available USB disks/SD cards
- `task device:write-disk [-- <disk_count>]` - Write the Talos image to one or more USB drives
- `task device:write-ubuntu-iso` - Write the Ubuntu ISO to one or more USB drives
- `task device:write-incus-disk` - Write the IncusOS image to one or more USB drives
- `task device:unmount-disk [-- <disk_count>]` - Unmount one or more USB disks
- `task device:eject-disk [-- <disk_count>]` - Eject one or more USB disks
- `task device:format-xfs` - Format USB disk as XFS (requires Linux)
- `task device:get-disks -- <control-plane-ip>` - Get disk information from a Talos node

## Talos Configuration

- `task device:generate-talosconfig -- <install-disk>` - Generate Talos configuration files
- `task device:apply-configuration -- <control-plane-ip> <worker-ip1> <worker-ip2> ...` - Apply Talos configuration to nodes
- `task device:set-endpoints -- <control-plane-ip>` - Set Talos API endpoints
- `task device:bootstrap-etc-cluster -- <control-plane-ip>` - Bootstrap the etcd cluster (run once on control plane)
- `task device:retrieve-kubeconfig -- <control-plane-ip>` - Retrieve Kubernetes kubeconfig file

## Cluster Management

- `task device:cluster-health -- <control-plane-ip>` - Check cluster health status
- `task device:talos-dashboard -- <control-plane-ip>` - Run the Talos dashboard

## Help

- `task device:help` - Show all device-related commands

## Taskfile Location

Task definitions are located in `tasks/device/Taskfile.yaml`.

