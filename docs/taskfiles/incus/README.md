---
title: "Incus Tasks"
description: "Incus container and VM management tasks"
---
# Incus Tasks (`incus:`)

Incus container and VM management, including Talos VM deployment.

## Daemon Management

- `task incus:start-daemon` - Start the Incus daemon (handles macOS/Colima, snap, systemd, and direct binary)
- `task incus:stop-daemon` - Stop the Incus daemon

## Instance Management

- `task incus:create-instance [<instance-name>]` - Create an Incus instance (defaults to `UBUNTU_GITHUB_RUNNER_0_NAME` if no name provided)
- `task incus:delete-instance [<instance-name>]` - Delete an Incus instance (defaults to `UBUNTU_GITHUB_RUNNER_0_NAME` if no name provided)

## Talos VM Deployment

- `task incus:download-talos-image` - Download the Talos cloud image for VMs
- `task incus:create-physical-network` - Create a physical network for direct attachment to the host network
- `task incus:launch-talos-vm -- <vm-name> <vm-ip>` - Launch a Talos VM on IncusOS

## Utilities

- `task incus:web-ui` - Open the Incus Web UI in your browser

## Help

- `task incus:help` - Show all Incus-related commands

## Environment Variables

- `INCUS_REMOTE_NAME` - Incus remote name
- `UBUNTU_GITHUB_RUNNER_0_NAME` - Default instance name for GitHub runners

## Taskfile Location

Task definitions are located in `tasks/incus/Taskfile.yaml`.

