---
title: "Taskfiles"
description: "Task automation for workspace operations"
---

# Taskfiles

This workspace uses [Taskfile](https://taskfile.dev/) to automate common infrastructure operations. Tasks are organized into namespaces, each focusing on a specific area of infrastructure management.

## Overview

Tasks provide a standardized way to perform common operations without needing to remember complex command-line syntax or configuration details. Each namespace groups related functionality together.

## Available Task Namespaces

### 🔧 Dev (`dev:`)

Development environment management for creating and managing development containers and VMs on Incus.

**Instance Creation:**

- `task dev:create [-- <type> <image> [--name <name>]]` - Create a dev container or VM instance (defaults: `DEV_INSTANCE_TYPE`, `DEV_IMAGE`, `DEV_INSTANCE_NAME`)

**Instance Management:**

- `task dev:start [-- <instance-name>]` - Start a dev instance
- `task dev:stop [-- <instance-name>]` - Stop a dev instance
- `task dev:restart [-- <instance-name>]` - Restart a dev instance
- `task dev:list` - List all dev instances
- `task dev:info [-- <instance-name>]` - Get detailed information about a dev instance
- `task dev:debug [-- <instance-name>]` - Debug performance and resource usage
- `task dev:delete [-- <instance-name>]` - Delete a dev instance

**Access:**

- `task dev:shell [-- <instance-name>]` - Open an interactive shell in the instance
- `task dev:ssh [-- <instance-name>]` - SSH into a VM instance
- `task dev:ssh-info [-- <instance-name>]` - Show SSH connection information
- `task dev:exec -- <instance-name> -- <command>` - Execute a command in the instance

**Workspace Management:**

- `task dev:init-workspace [-- <instance-name>]` - Initialize workspace contents in an existing VM
- `task dev:copy-workspace [-- <instance-name>]` - Copy entire workspace (replaces existing)
- `task dev:add-workspace [-- <instance-name>]` - Add workspace to instance (same as during creation)
- `task dev:sync-workspace [-- <instance-name>]` - Sync workspace changes using rsync (uploads only changed files)

**Help:**

- `task dev:help` - Show all dev environment commands

### 🖥️ Device (`device:`)

Device management for preparing physical devices, managing disk images, and configuring Talos clusters.

**Image Management:**

- `task device:download-image` - Download the Talos image
- `task device:decompress-image` - Decompress the Talos image
- `task device:download-incus-image` - Download or move IncusOS image to the devices folder
- `task device:download-ubuntu-iso` - Download or move Ubuntu ISO to the devices folder

**Disk Operations:**

- `task device:list-disks` - List available USB disks/SD cards
- `task device:write-disk [-- <disk_count>]` - Write the Talos image to one or more USB drives
- `task device:write-ubuntu-iso` - Write the Ubuntu ISO to one or more USB drives
- `task device:write-incus-disk` - Write the IncusOS image to one or more USB drives
- `task device:unmount-disk [-- <disk_count>]` - Unmount one or more USB disks
- `task device:eject-disk [-- <disk_count>]` - Eject one or more USB disks
- `task device:format-xfs` - Format USB disk as XFS (requires Linux)
- `task device:get-disks -- <control-plane-ip>` - Get disk information from a Talos node

**Talos Configuration:**

- `task device:generate-talosconfig -- <install-disk>` - Generate Talos configuration files
- `task device:apply-configuration -- <control-plane-ip> <worker-ip1> <worker-ip2> ...` - Apply Talos configuration to nodes
- `task device:set-endpoints -- <control-plane-ip>` - Set Talos API endpoints
- `task device:bootstrap-etc-cluster -- <control-plane-ip>` - Bootstrap the etcd cluster (run once on control plane)
- `task device:retrieve-kubeconfig -- <control-plane-ip>` - Retrieve Kubernetes kubeconfig file

**Cluster Management:**

- `task device:cluster-health -- <control-plane-ip>` - Check cluster health status
- `task device:talos-dashboard -- <control-plane-ip>` - Run the Talos dashboard

**Help:**

- `task device:help` - Show all device-related commands

### 🐳 Docker (`docker:`)

Docker container management and cleanup.

**Management:**

- `task docker:clean` - Clean up Docker images and containers (kills all running containers and prunes system)

**Help:**

- `task docker:help` - Show Docker commands

### 📦 Incus (`incus:`)

Incus container and VM management, including Talos VM deployment.

**Daemon Management:**

- `task incus:start-daemon` - Start the Incus daemon (handles macOS/Colima, snap, systemd, and direct binary)
- `task incus:stop-daemon` - Stop the Incus daemon

**Instance Management:**

- `task incus:create-instance [<instance-name>]` - Create an Incus instance (defaults to `UBUNTU_GITHUB_RUNNER_0_NAME` if no name provided)
- `task incus:delete-instance [<instance-name>]` - Delete an Incus instance (defaults to `UBUNTU_GITHUB_RUNNER_0_NAME` if no name provided)

**Talos VM Deployment:**

- `task incus:download-talos-image` - Download the Talos cloud image for VMs
- `task incus:create-physical-network` - Create a physical network for direct attachment to the host network
- `task incus:launch-talos-vm -- <vm-name> <vm-ip>` - Launch a Talos VM on IncusOS

**Utilities:**

- `task incus:web-ui` - Open the Incus Web UI in your browser

**Help:**

- `task incus:help` - Show all Incus-related commands

### 🏃 Runner (`runner:`)

GitHub Actions runner VM setup and management.

**Initialization:**

- `task runner:initialize -- <vm-name>` - Initialize a new Incus VM for GitHub Actions runner

**Setup Tasks:**

- `task runner:install-aqua -- <vm-name>` - Install aqua package manager
- `task runner:install-docker -- <vm-name>` - Install Docker
- `task runner:create-runner-user -- <vm-name>` - Create a dedicated runner user
- `task runner:setup-ssh -- <vm-name>` - Set up SSH access for the runner user
- `task runner:install-windsor-cli -- <vm-name>` - Install Windsor CLI
- `task runner:install-packages -- <vm-name>` - Install additional packages commonly needed for runners

**GitHub Actions:**

- `task runner:install-github-runner -- <vm-name>` - Install and configure GitHub Actions runner

**Maintenance:**

- `task runner:clean-work-dir -- <vm-name>` - Clean the actions-runner/_work directory
- `task runner:shell -- <vm-name>` - Open an interactive shell session in the runner VM

**Help:**

- `task runner:help` - Show all runner tasks

**Note:** Requires `GITHUB_RUNNER_REPO_URL` and `GITHUB_RUNNER_TOKEN` environment variables.

### 🔐 SOPS (`sops:`)

Secrets management using SOPS (Secrets Operations) with AWS KMS.

**Context Setup:**

- `task sops:set-context` - Initialize the SOPS context with AWS S3 backend

**Terraform Operations:**

- `task sops:init` - Initialize Terraform for SOPS infrastructure
- `task sops:plan` - Plan deployment to AWS
- `task sops:apply` - Deploy SOPS resources to AWS (KMS key and state bucket)
- `task sops:output` - Print SOPS Terraform state
- `task sops:destroy` - Destroy the AWS SOPS infrastructure

**SOPS Operations:**

- `task sops:generate-secrets-file` - Generate a new secrets file template for the current context
- `task sops:encrypt-secrets-file` - Encrypt the secrets file using SOPS

**Help:**

- `task sops:help` - Show all SOPS-related commands

### ☸️ Talos (`talos:`)

Talos Linux cluster health checks and management.

**Health Checks:**

- `task talos:health-controlplane` - Check control plane node health
- `task talos:health-worker` - Check all worker nodes health
- `task talos:health-worker-0` - Check worker-0 node health
- `task talos:health-worker-1` - Check worker-1 node health
- `task talos:fetch-node-server-certificate` - Fetch server certificate from control plane node

**Cluster Management:**

- `task talos:cleanup` - Destroy the entire Talos cluster and clean up resources (stops and deletes all VMs)

**Help:**

- `task talos:help` - Show all Talos-related commands

**Environment Variables Used:**

- `CONTROL_PLANE_IP` - Control plane node IP address
- `WORKER_0_IP` - First worker node IP address
- `WORKER_1_IP` - Second worker node IP address
- `TALOSCONFIG` - Path to Talos configuration file
- `INCUS_REMOTE_NAME` - Incus remote name
- `CONTROL_PLANE_VM` - Control plane VM name
- `WORKER_0_VM` - First worker VM name
- `WORKER_1_VM` - Second worker VM name

### 🎬 VHS (`vhs:`)

Generate GIF animations from terminal session recordings using VHS (Video-to-Hardcopy-Software).

**GIF Generation:**

- `task vhs:make-windsor-init-gif` - Build Windsor init GIF
- `task vhs:make-windsor-up-gif` - Build Windsor up GIF
- `task vhs:make-port-forwarding-gif` - Build port forwarding GIF
- `task vhs:make-windsor-down-gif` - Build Windsor down GIF
- `task vhs:make-check-ha-pod-gif` - Build check Home Assistant pod GIF

**Help:**

- `task vhs:help` - Show all VHS-related commands

### 📁 Workspace (`workspace:`)

Workspace initialization and management.

**Operations:**

- `task workspace:initialize -- <workspace-name> <workspace-global-path>` - Initialize a new workspace by cloning the workspace repository
- `task workspace:clean` - Clean up Docker images and containers

**Help:**

- `task workspace:help` - Show workspace-related commands

## Getting Help

Each namespace provides its own help command:

- `task <namespace>:help` - Show help for a specific namespace

To see all available tasks:

- `task --list-all` - List all tasks across all namespaces

## Common Patterns

**Using Environment Variables:**

Many tasks support default values from environment variables. For example:

- `DEV_INSTANCE_TYPE` - Default instance type (container or vm)
- `DEV_IMAGE` - Default image (e.g., ubuntu/24.04)
- `DEV_INSTANCE_NAME` - Default instance name
- `INCUS_REMOTE_NAME` - Incus remote name

**Task Arguments:**
Tasks accept arguments using the `--` separator:
```bash
task dev:create -- container ubuntu/24.04 --name my-dev
task runner:shell -- github-runner-ubuntu
task device:apply-configuration -- 192.168.1.100 192.168.1.101 192.168.1.102
```

## Taskfile Location

All task definitions are located in the `tasks/` directory, organized by namespace:

- `tasks/dev/Taskfile.yaml`
- `tasks/device/Taskfile.yaml`
- `tasks/docker/Taskfile.yaml`
- `tasks/incus/Taskfile.yaml`
- `tasks/runner/Taskfile.yaml`
- `tasks/sops/Taskfile.yaml`
- `tasks/talos/Taskfile.yaml`
- `tasks/vhs/Taskfile.yaml`
- `tasks/workspace/Taskfile.yaml`

## Additional Resources

- [Taskfile Documentation](https://taskfile.dev/)
- [Windsor CLI Documentation](https://windsorcli.github.io/)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Talos Documentation](https://www.talos.dev/)

