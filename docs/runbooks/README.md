---
title: "Runbooks"
description: "Step-by-step runbooks for building deployments from the ground up"
---
# Runbooks

Welcome to the runbooks section! This folder contains comprehensive, step-by-step guides that walk you through building complete deployments from the ground up. Each runbook is designed to help new users understand and implement the infrastructure patterns demonstrated in the examples folder.

## Purpose

The runbooks serve as instructional guides that break down the implementation process into clear, actionable steps. While the examples folder contains working reference implementations that are used for regression testing and serve as the "final product," the runbooks focus on the **how** and **why** behind each step, making them ideal for:

- **New users** learning to build infrastructure from scratch
- **Developers** who want to understand the implementation details
- **Teams** adapting these patterns to their own environments
- **Anyone** who prefers a guided, step-by-step approach

## How Runbooks Relate to Examples

The examples and runbooks work together:

- **Examples** : Are production-ready, tested implementations that serve as reference code and are used for regression testing. These are the "what" - the complete, working solution.

- **Runbooks** : Provide the "how" - detailed, step-by-step instructions that guide you through building a deployment that matches the corresponding example implementation.

By following a runbook, you'll end up with a deployment that implements the same patterns and achieves the same results as the corresponding example in the examples folder.


## Available Runbooks

The following runbooks are available:

### 🚀 [Initialize Workspace](./workspace/init.md)
Step-by-step guide for initializing a new workspace using the workspace initialization task and Windsor CLI. This is typically the first step when starting a new project, covering workspace structure creation, directory setup, and Windsor CLI initialization with proper context configuration.

### 🔧 [Bootstrapping Nodes](./bootstrapping/README.md)
Instructions for bootstrapping Talos clusters and preparing devices for deployment, including image preparation and initial cluster configuration.

### 🏠 [Home Assistant](./home-assistant/README.md)
Complete guide for deploying a home automation platform with container-based deployment, SSL/TLS configuration, persistent storage, and high-availability setup.

### 🏃 GitHub Actions Runners
Step-by-step guides for setting up self-hosted GitHub Actions runners on various platforms. These runbooks cover installing and configuring runners on Windows, Ubuntu, and macOS systems, enabling you to run CI/CD workflows on your own infrastructure.

- **[Ubuntu Runner Setup](./runners/ubuntu-runner-setup.md)**: Configure Ubuntu-based runners on Raspberry Pi (ARM64) or Intel NUC (x86_64) devices
- **[Windows Runner Setup](./runners/windows-runner-setup.md)**: Set up Windows-based runners on Intel NUC (x86_64) devices
- **[macOS Runner Setup](./runners/macos-runner-setup.md)**: Configure macOS-based runners on Apple Silicon (ARM64) Mac devices


### More Runbooks Coming Soon

Additional runbooks are being developed for:

- **Ethereum**: Blockchain development environment setup
- **WireGuard**: Secure VPN solution deployment
- **Tailscale**: Modern VPN with mesh networking
- **AWS Web Cluster**: Scalable web application infrastructure
- **Sidero Omni**: Bare metal Kubernetes provisioning
- **Hybrid Cloud**: Multi-cloud infrastructure deployment

## Getting Started

1. **Review the prerequisites**: Ensure you have all required tools installed by following the [Installation Guide](../install.md)

2. **Choose a runbook**: Select a runbook that matches your needs

3. **Follow step-by-step**: Each runbook provides detailed instructions from initial setup through final deployment

4. **Reference the example**: Compare your implementation with the corresponding example in the `/examples/` folder to verify your deployment matches the reference implementation

5. **Customize as needed**: Once you understand the pattern, adapt it to your specific requirements

## Tips for Success

- **Read the entire runbook first**: Understanding the full process before starting helps avoid common pitfalls
- **Follow steps in order**: Each step builds on the previous one
- **Check prerequisites**: Ensure all required tools and access are available before beginning
- **Test incrementally**: Verify each step works before moving to the next
- **Consult the example**: When in doubt, refer to the working example implementation

## Getting Help

- **Documentation**: [Documentation Site](https://tvangundy.github.io)
- **Issues**: [GitHub Issues](https://github.com/tvangundy/workspace/issues)
- **Discussions**: [GitHub Discussions](https://github.com/tvangundy/workspace/discussions)
