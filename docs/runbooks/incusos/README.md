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

#### 🚀 [IncusOS Server](server.md)
Complete guide for installing and configuring IncusOS on Intel NUC devices. Covers BIOS configuration, Secure Boot setup, boot media preparation using the IncusOS customizer, installation process, and connecting to the Incus server via CLI. This is the foundational setup required before using any other IncusOS runbooks.

#### ☸️ [Talos Kubernetes Cluster](tc.md)
Deploy a Talos Linux Kubernetes cluster using Infrastructure as Code with Terraform and the Incus provider. This approach uses Terraform to manage your cluster declaratively, making it easy to version control, reproduce, and manage your infrastructure. Includes workspace setup, environment variable configuration, Terraform variable generation, Talos image download and import, network bridge creation, Terraform initialization and application, IP address management, kubeconfig retrieval, and cluster verification. Also covers cluster destruction and management procedures.

#### 🐧 [Ubuntu Virtual Machines](vm.md)
Create and manage Ubuntu virtual machines on a remote IncusOS server. This runbook covers creating generic VMs, development VMs, and GitHub Actions runner VMs. All are just named instances of Ubuntu VMs created using the `vm:` task namespace. Includes workspace initialization, Terraform-based VM creation, developer tools installation, Docker setup, SSH configuration for direct network access, workspace syncing capabilities, and VM lifecycle management. Provides isolated, persistent Ubuntu environments with direct SSH access from your local network, suitable for development work, CI/CD runners, or any other workload.

## Getting Started

If you're new to IncusOS, we recommend starting with the [IncusOS Server](server.md) runbook to get your IncusOS server up and running. Once your server is configured, you can proceed with any of the deployment runbooks based on your needs:

- **For Kubernetes**: Use the [Talos Kubernetes Cluster](tc.md) guide
- **For Development or CI/CD**: Use the [Ubuntu Virtual Machines](vm.md) guide (covers both development VMs and GitHub Actions runner VMs)
- **For Application Deployment**: See the [Application Deployment Runbooks](../apps/README.md) for guides on deploying applications like Mailu, Home Assistant, and more

## Common Prerequisites

Most IncusOS runbooks require:

- **IncusOS system**: An IncusOS host with Incus installed and running (see [IncusOS Server](server.md))
- **Incus CLI client**: Installed and configured on your local machine
- **Incus remote configured**: Connected to your IncusOS server
- **Network access**: The IncusOS host must be on a network with available IP addresses
- **Workspace initialized**: Follow the [Initialize Workspace](../workspace/init.md) runbook if you haven't already

## Additional Resources

- [IncusOS Documentation](https://linuxcontainers.org/incus-os/docs/main/getting-started/)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Talos Documentation](https://www.talos.dev/)

