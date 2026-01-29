---
title: "Taskfiles"
description: "Task automation for workspace operations"
---

# Taskfiles

[Taskfiles](https://taskfile.dev/) automate common infrastructure operations. Tasks provide a standardized way to perform operations without needing to remember complex command-line syntax or configuration details.

Tasks are organized into namespaces, each focusing on a specific area of infrastructure management. This organization makes it easy to discover and use the right tool for each task.

For example, to create a virtual machine:
```bash
task vm:instantiate -- <remote-name> [<vm-name>] [--keep] [--no-workspace] [--windsor-up]
```

## Namespace Overview

- **`device:`** - Physical device preparation, disk image management, and Talos cluster configuration for bare-metal deployments
- **`docker:`** - Docker container cleanup and system maintenance
- **`incus:`** - Incus daemon management and instance operations, including Talos VM deployment
- **`sops:`** - Secrets management using SOPS with AWS KMS, including Terraform infrastructure for key and state management
- **`talos:`** - Talos Linux cluster health monitoring and cluster lifecycle management
- **`tc:`** - Talos Kubernetes cluster management for creating and managing three-node Talos clusters on Incus using Terraform
- **`vm:`** - Ubuntu virtual machine management for creating and managing Ubuntu VMs on Incus using Terraform, including development environments
- **`runner:`** - GitHub Actions runner management for creating and managing self-hosted runners on Incus VMs
- **`vhs:`** - Terminal session recording and GIF generation for documentation
- **`workspace:`** - Workspace initialization, cloning, and general workspace maintenance

## Task Namespaces

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

### ☸️ Talos Cluster (`tc:`)

Talos Kubernetes cluster management for creating and managing three-node Talos Linux clusters on Incus using Terraform.

**Cluster Creation:**
- `task tc:instantiate -- <remote-name> [<cluster-name>] [--keep]` - Create and bootstrap a three-node Talos Kubernetes cluster using Terraform

**Terraform Operations:**
- `task tc:generate-tfvars` - Generate terraform.tfvars from environment variables
- `task tc:terraform:init` - Initialize Terraform
- `task tc:terraform:plan` - Show Terraform plan
- `task tc:terraform:apply` - Apply Terraform configuration
- `task tc:terraform:destroy` - Destroy the cluster using Terraform

**Cluster Management:**
- `task tc:list` - List all cluster VMs
- `task tc:info` - Get detailed information about the cluster
- `task tc:console -- <vm-name>` - Access VM console
- `task tc:start` - Start all cluster VMs
- `task tc:stop` - Stop all cluster VMs
- `task tc:restart` - Restart all cluster VMs
- `task tc:destroy` - Destroy the Talos cluster using Terraform

**Health Checks:**
- `task tc:health-controlplane` - Health check the control plane node
- `task tc:health-worker` - Health check all worker nodes
- `task tc:health-worker-0` - Health check worker-0
- `task tc:health-worker-1` - Health check worker-1

**Testing:**
- `task tc:test -- <remote-name> [--keep]` - Test complete cluster setup and validate cluster

**Help:**
- `task tc:help` - Show all tc commands

### 🖥️ Ubuntu VM (`vm:`)

Ubuntu virtual machine management for creating and managing Ubuntu VMs on Incus using Terraform.

**Instance Creation:**
- `task vm:instantiate -- <remote-name> [<vm-name>] [--keep] [--no-workspace] [--windsor-up]` - Create an Ubuntu VM instance using Terraform with complete developer environment setup

**Terraform Operations:**
- `task vm:generate-tfvars` - Generate terraform.tfvars from environment variables
- `task vm:terraform:init` - Initialize Terraform
- `task vm:terraform:plan` - Show Terraform plan
- `task vm:terraform:apply` - Apply Terraform configuration
- `task vm:terraform:destroy` - Destroy the VM using Terraform

**Instance Management:**
- `task vm:start [-- <instance-name>]` - Start an Ubuntu VM instance
- `task vm:stop [-- <instance-name>]` - Stop an Ubuntu VM instance
- `task vm:restart [-- <instance-name>]` - Restart an Ubuntu VM instance
- `task vm:list` - List all Ubuntu VM instances
- `task vm:info [-- <instance-name>]` - Get detailed information about an Ubuntu VM instance
- `task vm:debug [-- <instance-name>]` - Debug performance and resource usage
- `task vm:destroy [-- <instance-name>]` - Destroy an Ubuntu VM using Terraform

**Access:**
- `task vm:shell [-- <instance-name>]` - Open an interactive shell in the instance
- `task vm:ssh [-- <instance-name>]` - SSH into an Ubuntu VM instance
- `task vm:ssh-info [-- <instance-name>]` - Show SSH connection information
- `task vm:exec -- <instance-name> -- <command>` - Execute a command in the instance

**Workspace Management:**
- `task vm:init-workspace [-- <instance-name>]` - Initialize workspace contents in an existing VM
- `task vm:copy-workspace [-- <instance-name>]` - Copy entire workspace (replaces existing)
- `task vm:add-workspace [-- <instance-name>]` - Add workspace to instance (merges with existing)
- `task vm:sync-workspace [-- <instance-name>]` - Sync workspace changes using rsync (uploads only changed files)


**Testing:**
- `task vm:test -- <remote-name> [--keep] [--no-workspace]` - Test complete setup and validate VM

**Help:**
- `task vm:help` - Show all vm commands

### 🏃 GitHub Actions Runner (`runner:`)

GitHub Actions runner management for creating and managing self-hosted runners on Incus VMs.

**Runner Creation:**
- `task runner:instantiate -- <remote-name> [<runner-name>] [--keep]` - Create a GitHub Actions runner VM with complete setup

**Runner Management:**
- `task runner:status [-- <runner-name>]` - Check status of GitHub Actions runner service
- `task runner:destroy [-- <runner-name>]` - Destroy runner VM and remove it from GitHub repository

**Help:**
- `task runner:help` - Show all runner commands

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

- `VM_INSTANCE_NAME` - Default VM instance name
- `VM_IMAGE` - Default image (e.g., ubuntu/24.04)
- `VM_MEMORY` - Default memory allocation
- `VM_CPU` - Default CPU cores
- `INCUS_REMOTE_NAME` - Incus remote name

**Task Arguments:**
Tasks accept arguments using the `--` separator:
```bash
task vm:instantiate -- nuc my-vm --keep
task runner:instantiate -- nuc my-runner
task tc:instantiate -- nuc my-cluster --keep
task device:apply-configuration -- 192.168.1.100 192.168.1.101 192.168.1.102
```

## Taskfile Location

All task definitions are located in the `tasks/` directory, organized by namespace:

- `tasks/device/Taskfile.yaml`
- `tasks/docker/Taskfile.yaml`
- `tasks/incus/Taskfile.yaml`
- `tasks/sops/Taskfile.yaml`
- `tasks/talos/Taskfile.yaml`
- `tasks/tc/Taskfile.yaml` (Talos Kubernetes cluster management)
- `tasks/vm/Taskfile.yaml` (VM management and development environments)
- `tasks/runner/Taskfile.yaml` (GitHub Actions runner management)
- `tasks/vhs/Taskfile.yaml`
- `tasks/workspace/Taskfile.yaml`

## Additional Resources

- [Taskfile Documentation](https://taskfile.dev/)
- [Windsor CLI Documentation](https://windsorcli.github.io/)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Talos Documentation](https://www.talos.dev/)

