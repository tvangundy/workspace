---
title: "Runbooks"
description: "Step-by-step runbooks for building deployments from the ground up"
---
# Runbooks

Welcome to the runbooks section! This folder contains comprehensive, step-by-step guides that walk you through building complete deployments from the ground up. Each runbook is designed to help new users understand and implement infrastructure patterns.

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

### 🐳 [IncusOS Setup](./incusos/incusos-setup.md)
Complete guide for installing and configuring IncusOS on Intel NUC devices, including BIOS configuration, Secure Boot setup, boot media preparation, and connecting to the Incus server.

### 🏃 [GitHub Runners on IncusOS VMs](./incusos/github-runner.md)
Complete guide for setting up GitHub Actions runners using virtual machines on an IncusOS system. Deploy Ubuntu and Windows runner VMs, configure the GitHub Actions runner software, and manage runner lifecycle including auto-start, updates, and maintenance.

### 🐧 [Ubuntu Setup](./ubuntu/ubuntu-setup.md)
Complete guide for installing and configuring Ubuntu on Intel NUC devices, including BIOS configuration, boot media preparation, installation process, and post-installation setup for development and server workloads.

### ☸️ [Talos on IncusOS VMs](./talos/talos-incus-vm.md)
Complete guide for deploying a Talos Linux Kubernetes cluster using virtual machines on an IncusOS system. Deploy 3 VMs (1 control plane, 2 workers) and configure them to form a complete Kubernetes cluster.

### 🔧 [Bootstrapping Nodes](./bootstrapping/README.md)
Instructions for bootstrapping Talos clusters and preparing devices for deployment, including image preparation and initial cluster configuration.

- **[Raspberry Pi Bootstrapping](./bootstrapping/rpi-bootstrapping.md)**: Bootstrapping Talos clusters on Raspberry Pi devices (ARM64)
- **[Intel NUC Bootstrapping](./bootstrapping/nuc-bootstrapping.md)**: Bootstrapping Talos clusters on Intel NUC devices (x86_64)
- **[Sidero Omni Bootstrapping](./bootstrapping/omni-bootstrapping.md)**: Bootstrapping Talos clusters using Sidero Omni for bare metal provisioning

### 🏠 [Home Assistant](./home-assistant/README.md)
Complete guide for deploying a home automation platform with container-based deployment, SSL/TLS configuration, persistent storage, and high-availability setup.

### 🏃 GitHub Actions Runners
Step-by-step guides for setting up self-hosted GitHub Actions runners on various platforms. These runbooks cover installing and configuring runners on Windows, Ubuntu, and macOS systems, enabling you to run CI/CD workflows on your own infrastructure.

- **[Ubuntu Runner Setup](./runners/ubuntu-runner-setup.md)**: Configure Ubuntu-based runners on Raspberry Pi (ARM64) or Intel NUC (x86_64) devices
- **[Windows Runner Setup](./runners/windows-runner-setup.md)**: Set up Windows-based runners on Intel NUC (x86_64) devices
- **[macOS Runner Setup](./runners/macos-runner-setup.md)**: Configure macOS-based runners on Apple Silicon (ARM64) Mac devices


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
