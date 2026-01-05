---
title: "IncusOS Runbooks"
description: "Comprehensive guides for deploying and managing infrastructure on IncusOS"
---

# IncusOS Runbooks

Comprehensive, step-by-step guides for deploying and managing infrastructure on [IncusOS](https://linuxcontainers.org/incus-os/docs/main/getting-started/), a dedicated operating system designed specifically for running Incus container and virtual machine management. These runbooks cover everything from initial server setup to deploying Kubernetes clusters, development environments, and CI/CD runners.

## What is IncusOS?

IncusOS is a minimal, purpose-built operating system that provides a streamlined platform for running Incus. It's optimized for container and VM management, making it ideal for:

- **Development environments**: Create isolated development containers and VMs
- **Testing and CI/CD**: Run automated tests and build pipelines
- **Kubernetes clusters**: Deploy and manage Kubernetes clusters on VMs
- **Infrastructure as Code**: Manage infrastructure using declarative configurations
- **Self-hosted services**: Run your own services in containers or VMs

## Available Runbooks

#### 🚀 [IncusOS Server Setup](setup.md)
Complete guide for installing and configuring IncusOS on Intel NUC devices. Covers BIOS configuration, Secure Boot setup, boot media preparation using the IncusOS customizer, installation process, and connecting to the Incus server via CLI. This is the foundational setup required before using any other IncusOS runbooks.

#### ☸️ [Talos Kubernetes Cluster](talos-incus-vm.md)
Deploy a complete Talos Linux Kubernetes cluster using virtual machines on an IncusOS system. Includes workspace setup, Talos image download and configuration, network bridge creation, launching 3 VMs (1 control plane, 2 workers), Talos configuration with kernel modules and sysctls, cluster bootstrapping, kubeconfig retrieval, and cluster verification. Also covers cluster cleanup and destruction procedures.

#### ☸️ [Talos Kubernetes Cluster with Terraform](talos-incus-terraform.md)
Deploy a Talos Linux Kubernetes cluster using Infrastructure as Code with Terraform and the Incus provider. This approach uses Terraform to manage your cluster declaratively, making it easy to version control, reproduce, and manage your infrastructure. Includes workspace setup, environment variable configuration, Terraform variable generation, Talos image download and import, network bridge creation, Terraform initialization and application, IP address management, kubeconfig retrieval, and cluster verification. Also covers cluster destruction and management procedures.

#### 💻 [Remote Development VM](dev-vm-remote.md)
Create and manage development virtual machines on a remote IncusOS server. Includes workspace initialization with Aqua tool management, VM creation with Ubuntu 24.04, Docker installation, SSH configuration for direct network access, workspace syncing capabilities, and VM lifecycle management. Ideal for persistent development work with isolated environments and direct SSH access from your local network.

#### 💻 [Local Development Container](dev-container-local.md)
Set up development containers locally on macOS using Colima with Incus runtime. Covers Colima installation and configuration, environment setup for local containers, workspace initialization with real-time file sharing, Docker integration, and container management. Perfect for development with direct IDE integration and instant file synchronization without network overhead.

#### 🏃 [GitHub Actions Runner](github-runner.md)
Set up GitHub Actions runners using Ubuntu virtual machines on an IncusOS system. Covers GitHub runner configuration, workspace and environment variable setup, secure token storage with SOPS, network configuration for direct VM attachment, Ubuntu VM creation and initialization, runner software installation and configuration, service setup for auto-start, and ongoing maintenance procedures for updates and cleanup.

## Getting Started

If you're new to IncusOS, we recommend starting with the [IncusOS Setup](setup.md) runbook to get your IncusOS server up and running. Once your server is configured, you can proceed with any of the deployment runbooks based on your needs:

- **For Kubernetes**: Choose between [Talos Cluster on IncusOS VMs (Manual)](talos-incus-vm.md) or [Talos Cluster on IncusOS VMs (Terraform)](talos-incus-terraform.md)
- **For Development**: Choose between [Remote Dev VM](dev-vm-remote.md) or [Local Dev Container](dev-container-local.md)
- **For CI/CD**: Use the [GitHub Runner](github-runner.md) guide

## Common Prerequisites

Most IncusOS runbooks require:

- **IncusOS system**: An IncusOS host with Incus installed and running (see [IncusOS Setup](setup.md))
- **Incus CLI client**: Installed and configured on your local machine
- **Incus remote configured**: Connected to your IncusOS server
- **Network access**: The IncusOS host must be on a network with available IP addresses
- **Workspace initialized**: Follow the [Initialize Workspace](../workspace/init.md) runbook if you haven't already

## Additional Resources

- [IncusOS Documentation](https://linuxcontainers.org/incus-os/docs/main/getting-started/)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Talos Documentation](https://www.talos.dev/)

