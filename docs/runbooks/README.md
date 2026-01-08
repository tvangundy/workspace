---
title: "Runbooks"
description: "Step-by-step runbooks for building deployments from the ground up"
---
# Runbooks

Comprehensive, step-by-step guides for building complete deployments from the ground up. Each runbook helps you understand and implement infrastructure patterns through clear, actionable instructions.

## Purpose

The runbooks serve as instructional guides that break down the implementation process into clear, actionable steps, making them ideal for:

- **New users** learning to build infrastructure from scratch
- **Developers** who want to understand the implementation details
- **Teams** adapting these patterns to their own environments
- **Anyone** who prefers a guided, step-by-step approach

## Workspace Prerequisites

All runbooks assume you're starting with a **working workspace** that has been initialized and set up for running the Windsor CLI. This means:

- The workspace structure has been created with the proper directory layout
- Windsor CLI has been initialized with a context configuration
- The workspace is ready to execute Windsor CLI commands and taskfiles

If you're starting fresh or need to set up a new workspace, you'll need to complete these foundational steps first:

- **[Initialize Workspace](./workspace/init.md)**: Step-by-step guide for creating and initializing a new workspace with Windsor CLI. This is typically the first step when starting a new project.

- **[Secrets Management](./secrets/secrets.md)**: Complete guide for managing encrypted secrets using SOPS. You'll likely need this runbook frequently as you work with different deployments that require secure credential management.

For more information about Windsor CLI, including installation and detailed documentation, see the [Windsor CLI documentation](https://windsorcli.github.io/latest/).

## Available Runbooks

### 🚀 [Initialize Workspace](./workspace/init.md)
Step-by-step guide for initializing a new workspace using the workspace initialization task and Windsor CLI. This is typically the first step when starting a new project, covering workspace structure creation, directory setup, and Windsor CLI initialization with proper context configuration.

### 🔐 [Secrets Management](./secrets/secrets.md)
Complete guide for managing encrypted secrets using SOPS (Secrets Operations). Learn how to generate, encrypt, decrypt, and manage secrets within your workspace contexts, including integration with Windsor CLI.

### 🐳 [IncusOS Setup](./incusos/setup.md)
Complete guide for installing and configuring IncusOS on Intel NUC devices. Covers BIOS configuration, Secure Boot setup, boot media preparation using the IncusOS customizer, installation process, and connecting to the Incus server via CLI. This is the foundational setup required before using any other IncusOS runbooks.

### ☸️ [Talos Kubernetes Cluster](./incusos/talos-incus-terraform.md)
Deploy a Talos Linux Kubernetes cluster using Infrastructure as Code with Terraform and the Incus provider. This approach uses Terraform to manage your cluster declaratively, making it easy to version control, reproduce, and manage your infrastructure. Includes workspace setup, environment variable configuration, Terraform variable generation, Talos image download and import, network bridge creation, Terraform initialization and application, IP address management, kubeconfig retrieval, and cluster verification. Also covers cluster destruction and management procedures.

### 💻 [Remote Development Machines](./incusos/dev-machines.md)
Create and manage development virtual machines on a remote IncusOS server. Includes workspace initialization with Aqua tool management, VM creation with Ubuntu 24.04, Docker installation, SSH configuration for direct network access, workspace syncing capabilities, and VM lifecycle management. Ideal for persistent development work with isolated environments and direct SSH access from your local network.

### 🏃 [GitHub Actions Runner](./incusos/github-runner.md)
Set up GitHub Actions runners using Ubuntu virtual machines on an IncusOS system. Covers GitHub runner configuration, workspace and environment variable setup, secure token storage with SOPS, network configuration for direct VM attachment, Ubuntu VM creation and initialization, runner software installation and configuration, service setup for auto-start, and ongoing maintenance procedures for updates and cleanup.

### 🐧 [Ubuntu Setup](./ubuntu/ubuntu-setup.md)
Complete guide for installing and configuring Ubuntu on Intel NUC devices, including BIOS configuration, boot media preparation, installation process, and post-installation setup for development and server workloads.

### 🔧 [Bootstrapping Nodes](./bootstrapping/README.md)
Instructions for bootstrapping Talos clusters and preparing devices for deployment, including image preparation and initial cluster configuration.

- **[Raspberry Pi](./bootstrapping/rpi.md)**: Bootstrapping Talos clusters on Raspberry Pi devices (ARM64)
- **[Intel NUC](./bootstrapping/nuc.md)**: Bootstrapping Talos clusters on Intel NUC devices (x86_64)
- **[Sidero Omni](./bootstrapping/omni.md)**: Bootstrapping Talos clusters using Sidero Omni for bare metal provisioning

### 🏃 Self-Hosted GitHub Actions Runners
Step-by-step guides for setting up self-hosted GitHub Actions runners on various platforms. These runbooks cover installing and configuring runners on different operating systems, enabling you to run CI/CD workflows on your own infrastructure.

- **[Ubuntu Runner](./runners/ubuntu-runner-setup.md)**: Configure Ubuntu-based runners on Raspberry Pi (ARM64) or Intel NUC (x86_64) devices


## Getting Started

1. **Review the prerequisites**: Ensure you have all required tools installed by following the [Installation Guide](../install.md)

2. **Choose a runbook**: Select a runbook that matches your needs

3. **Follow step-by-step**: Each runbook provides detailed instructions from initial setup through final deployment

4. **Customize as needed**: Once you understand the pattern, adapt it to your specific requirements

## Tips for Success

- **Read the entire runbook first**: Understanding the full process before starting helps avoid common pitfalls
- **Follow steps in order**: Each step builds on the previous one
- **Check prerequisites**: Ensure all required tools and access are available before beginning
- **Test incrementally**: Verify each step works before moving to the next

## Getting Help

- **Documentation**: [Documentation Site](https://tvangundy.github.io)
- **Issues**: [GitHub Issues](https://github.com/tvangundy/workspace/issues)
- **Discussions**: [GitHub Discussions](https://github.com/tvangundy/workspace/discussions)
