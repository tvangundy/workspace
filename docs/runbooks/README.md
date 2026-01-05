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

## Available Runbooks

### 🚀 [Initialize Workspace](./workspace/init.md)
Step-by-step guide for initializing a new workspace using the workspace initialization task and Windsor CLI. This is typically the first step when starting a new project, covering workspace structure creation, directory setup, and Windsor CLI initialization with proper context configuration.

### 🔐 [Secrets Management](./secrets/secrets.md)
Complete guide for managing encrypted secrets using SOPS (Secrets Operations). Learn how to generate, encrypt, decrypt, and manage secrets within your workspace contexts, including integration with Windsor CLI.

### 🐳 [IncusOS Setup](./incusos/setup.md)
Complete guide for installing and configuring IncusOS on Intel NUC devices, including BIOS configuration, Secure Boot setup, boot media preparation, and connecting to the Incus server.

### ☸️ [Talos on IncusOS VMs](./incusos/talos-incus-vm.md)
Complete guide for deploying a Talos Linux Kubernetes cluster using virtual machines on an IncusOS system. Deploy 3 VMs (1 control plane, 2 workers) and configure them to form a complete Kubernetes cluster using manual configuration steps.

### ☸️ [Talos on IncusOS VMs with Terraform](./incusos/talos-incus-terraform.md)
Deploy a Talos Linux Kubernetes cluster using Infrastructure as Code with Terraform and the Incus provider. This approach uses Terraform to manage your cluster declaratively, making it easy to version control, reproduce, and manage your infrastructure. Deploy 3 VMs (1 control plane, 2 workers) and configure them to form a complete Kubernetes cluster using Terraform.

### 🏃 [GitHub Runner on IncusOS VMs](./incusos/github-runner.md)
Complete guide for setting up GitHub Actions runners using virtual machines on an IncusOS system. Deploy Ubuntu and Windows runner VMs, configure the GitHub Actions runner software, and manage runner lifecycle including auto-start, updates, and maintenance.

### 🐧 [Ubuntu Setup](./ubuntu/ubuntu-setup.md)
Complete guide for installing and configuring Ubuntu on Intel NUC devices, including BIOS configuration, boot media preparation, installation process, and post-installation setup for development and server workloads.

### 🔧 [Bootstrapping Nodes](./bootstrapping/README.md)
Instructions for bootstrapping Talos clusters and preparing devices for deployment, including image preparation and initial cluster configuration.

- **[Raspberry Pi](./bootstrapping/rpi.md)**: Bootstrapping Talos clusters on Raspberry Pi devices (ARM64)
- **[Intel NUC](./bootstrapping/nuc.md)**: Bootstrapping Talos clusters on Intel NUC devices (x86_64)
- **[Sidero Omni](./bootstrapping/omni.md)**: Bootstrapping Talos clusters using Sidero Omni for bare metal provisioning

### 🏠 [Home Assistant](./home-assistant/README.md)
Complete guide for deploying a home automation platform with container-based deployment, SSL/TLS configuration, persistent storage, and high-availability setup.

### 🏃 GitHub Actions Runners
Step-by-step guides for setting up self-hosted GitHub Actions runners on various platforms. These runbooks cover installing and configuring runners on Windows, Ubuntu, and macOS systems, enabling you to run CI/CD workflows on your own infrastructure.

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
