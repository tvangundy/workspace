---
title: "IncusOS Runbooks"
description: "Comprehensive guides for deploying and managing infrastructure on IncusOS"
---

# IncusOS Runbooks

Welcome to the IncusOS runbooks section! This folder contains comprehensive, step-by-step guides for deploying and managing infrastructure on [IncusOS](https://linuxcontainers.org/incus-os/docs/main/getting-started/), a dedicated operating system designed specifically for running Incus container and virtual machine management.

## What is IncusOS?

IncusOS is a minimal, purpose-built operating system that provides a streamlined platform for running Incus. It's optimized for container and VM management, making it ideal for:

- **Development environments**: Create isolated development containers and VMs
- **Testing and CI/CD**: Run automated tests and build pipelines
- **Kubernetes clusters**: Deploy and manage Kubernetes clusters on VMs
- **Infrastructure as Code**: Manage infrastructure using declarative configurations
- **Self-hosted services**: Run your own services in containers or VMs

## Available Runbooks

### 🚀 [IncusOS Setup](incusos-setup.md)
Complete guide for installing and configuring IncusOS on Intel NUC devices, including BIOS configuration, Secure Boot setup, boot media preparation, and connecting to the Incus server.

### ☸️ [Talos Cluster on IncusOS VMs](talos-incus-vm.md)
Complete guide for deploying a Talos Linux Kubernetes cluster using virtual machines on an IncusOS system. Deploy 3 VMs (1 control plane, 2 workers) and configure them to form a complete Kubernetes cluster.

### 💻 [Dev Containers - Remote (IncusOS)](dev-vm-remote.md)
Complete guide for setting up a remote development VM on IncusOS. Create a fully configured development environment with Docker, Git, and other developer tools, accessible remotely via SSH.

### 💻 [Dev Containers - Local (IncusOS/macOS)](dev-container-local-macos.md)
Complete guide for setting up a local development container on macOS using Colima with Incus runtime. Create a fully configured development environment with Docker, Git, and other developer tools running locally.

### 🏃 [GitHub Runner on IncusOS VMs](github-runner.md)
Complete guide for setting up GitHub Actions runners using virtual machines on an IncusOS system. Deploy Ubuntu and Windows runner VMs, configure the GitHub Actions runner software, and manage runner lifecycle including auto-start, updates, and maintenance.

## Getting Started

If you're new to IncusOS, we recommend starting with the [IncusOS Setup](incusos-setup.md) runbook to get your IncusOS server up and running. Once your server is configured, you can proceed with any of the deployment runbooks based on your needs:

- **For Kubernetes**: Start with [Talos Cluster on IncusOS VMs](talos-incus-vm.md)
- **For Development**: Choose between [Remote Dev VM](dev-vm-remote.md) or [Local Dev Container](dev-container-local-macos.md)
- **For CI/CD**: Use the [GitHub Runner](github-runner.md) guide

## Common Prerequisites

Most IncusOS runbooks require:

- **IncusOS system**: An IncusOS host with Incus installed and running (see [IncusOS Setup](incusos-setup.md))
- **Incus CLI client**: Installed and configured on your local machine
- **Incus remote configured**: Connected to your IncusOS server
- **Network access**: The IncusOS host must be on a network with available IP addresses
- **Workspace initialized**: Follow the [Initialize Workspace](../workspace/init.md) runbook if you haven't already

## Additional Resources

- [IncusOS Documentation](https://linuxcontainers.org/incus-os/docs/main/getting-started/)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Talos Documentation](https://www.talos.dev/)

