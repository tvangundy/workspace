---
title: "Taskfiles"
description: "Task automation for workspace operations"
---

# Taskfiles

[Taskfiles](https://taskfile.dev/) automate common infrastructure operations. Tasks provide a standardized way to perform operations without needing to remember complex command-line syntax or configuration details.

Tasks are organized into namespaces, each focusing on a specific area of infrastructure management. This organization makes it easy to discover and use the right tool for each task.

For example, to create a virtual machine:
```bash
task vm:instantiate -- <remote-name> <remote-ip> [<vm-name>] [--runner] [--workspace] [--windsor-up]
```

## Namespace Overview

- **`device:`** - Physical device preparation, disk image management, and Talos cluster configuration for bare-metal deployments
- **`sops:`** - Secrets management using SOPS with AWS KMS, including Terraform infrastructure for key and state management
- **`tc:`** - Talos Kubernetes cluster management for creating and managing three-node Talos clusters on Incus using Terraform
- **`vm:`** - Ubuntu virtual machine management for creating and managing Ubuntu VMs on Incus using Terraform, including development environments and GitHub Actions runners (`--runner`)
- **`workspace:`** - Workspace initialization, cloning, and general workspace maintenance

## Task Namespaces

### 🖥️ Device (`device:`)

Device management for preparing physical devices, managing disk images, and configuring Talos clusters.

**Image Management:**

- `task device:download-talos-image` - Download the Talos image
- `task device:prepare-incus-image` - Copy IncusOS image from Downloads to the devices folder
- `task device:download-ubuntu-img` - Download or move Ubuntu image to the devices folder
- `task device:prepare-bios` - Copy BIOS update files to the devices folder
- `task device:write-bios-disk` - Format USB as FAT32 and copy BIOS files (for Intel NUC BIOS updates)

**Disk Operations:**

- `task device:list-disks` - List available USB disks/SD cards
- `task device:write-talos-disk [-- <disk_count>]` - Write the Talos image to one or more USB drives
- `task device:write-ubuntu-img` - Write the Ubuntu image to one or more USB drives
- `task device:write-incus-disk` - Write the IncusOS image to one or more USB drives
- `task device:unmount-disk [-- <disk_count>]` - Unmount one or more USB disks
- `task device:eject-disk [-- <disk_count>]` - Eject one or more USB disks
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

### ☸️ Talos Cluster (`tc:`)

Talos Kubernetes cluster management for creating and managing three-node Talos Linux clusters on Incus using Terraform.

**Cluster Creation:**
- `task tc:instantiate -- <remote-name> <remote-ip> [<cluster-name>] [--destroy]` - Create and bootstrap a three-node Talos Kubernetes cluster using Terraform

**Cluster Management:**
- `task tc:list` - List all cluster VMs
- `task tc:destroy [-- <cluster-name>]` - Destroy the Talos cluster using Terraform
- `task tc:delete [-- <cluster-name>]` - Delete cluster VMs directly via Incus (bypasses Terraform)

**Help:**
- `task tc:help` - Show all tc commands

**Note:** Cluster VM start/stop/console and health checks use the **`talos:`** namespace and **Incus** CLI: `task talos:health-controlplane`, `task talos:health-worker`, `incus start/stop/restart/console $INCUS_REMOTE_NAME:<vm-name>`.

### 🖥️ Ubuntu VM (`vm:`)

Ubuntu virtual machine management for creating and managing Ubuntu VMs on Incus using Terraform.

**Instance Creation:**
- `task vm:instantiate -- <remote-name> <remote-ip> [<vm-name>] [--runner] [--workspace] [--windsor-up]` - Create an Ubuntu VM instance using Terraform with complete developer environment setup

**Terraform Operations:**
- `task vm:generate-tfvars` - Generate terraform.tfvars from environment variables
- `task vm:terraform:init` - Initialize Terraform
- `task vm:terraform:plan` - Show Terraform plan
- `task vm:terraform:apply` - Apply Terraform configuration
- `task vm:terraform:destroy` - Destroy the VM using Terraform

**Instance Management:**
- `task vm:list` - List all Ubuntu VM instances
- `task vm:destroy [-- <instance-name>]` - Destroy an Ubuntu VM using Terraform
- `task vm:delete [-- <instance-name>]` - Delete VM directly via Incus (bypasses Terraform)

**Help:**
- `task vm:help` - Show all vm commands

**Note:** VM start/stop/restart, info, shell, and exec are done via the **Incus** CLI: `incus start/stop/restart/info/exec $INCUS_REMOTE_NAME:<instance-name>`.

### 📁 Workspace (`workspace:`)

Workspace initialization and management.

**Operations:**

- `task workspace:instantiate -- <workspace-name> <workspace-path>` - Instantiate a new workspace by cloning the workspace repository
- `task workspace:overwrite -- <src-workspace-path> <dst-workspace-path>` - Overwrite `tasks/` and `bin/` in destination with contents from source
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
task vm:instantiate -- nuc 192.168.2.100 my-vm --runner
task vm:instantiate -- nuc 192.168.2.100 my-vm --workspace --windsor-up
```

## Taskfile Location

All task definitions are located in the `tasks/` directory, organized by namespace:

- `tasks/device/Taskfile.yaml`
- `tasks/docker/Taskfile.yaml`
- `tasks/incus/Taskfile.yaml`
- `tasks/sops/Taskfile.yaml`
- `tasks/talos/Taskfile.yaml`
- `tasks/tc/Taskfile.yaml` (Talos Kubernetes cluster management)
- `tasks/vm/Taskfile.yaml` (VM management, development environments, and `--runner` GitHub Actions runner setup)
- `tasks/vhs/Taskfile.yaml`
- `tasks/workspace/Taskfile.yaml`

## Additional Resources

- [Taskfile Documentation](https://taskfile.dev/)
- [Windsor CLI Documentation](https://windsorcli.github.io/)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Talos Documentation](https://www.talos.dev/)

