---
title: "Home"
description: "Welcome to Workspaces"
---


# Welcome to Workspace

A curated collection of production-ready infrastructure implementations and automation solutions. These examples demonstrate real-world applications of modern cloud technologies, container orchestration, and infrastructure-as-code practices. Each project is designed to be both educational and immediately useful, providing practical solutions that can be adapted for your own infrastructure needs.

## Examples
This collection of example projects comes from the [workspace repository](https://github.com/tvangundy/workspace) and features infrastructure automation, technical solutions, and more. Each example represents real-world solutions that can be easily adapted for your own projects. The collection continues to grow as new technologies and approaches are explored. Feel free to use these examples as a starting point.

*Note: All examples are currently under development.*

### 🏠 [Home Assistant](./examples/home-assistant.md)
A complete home automation setup with container-based deployment, SSL/TLS configuration, persistent storage management, add-on integration, monitoring and logging, high-availability setup, and backup/restore procedures.

### 🔒 [WireGuard](./examples/wireguard.md)
A secure VPN solution featuring automated key management, client configuration, DNS integration, NAT traversal, and security best practices.

### 🌐 [Tailscale](./examples/tailscale.md)
A modern VPN solution offering zero-configuration setup, mesh networking, access control lists, MagicDNS integration, and cross-platform support.

### ⚙️ [Sidero Omni](./examples/sidero-omni.md)
A bare metal Kubernetes solution providing automated provisioning, hardware management, cluster lifecycle management, resource optimization, and high availability.

### ☁️ [AWS Web Cluster](./examples/aws-web-cluster.md)
A scalable web application infrastructure with multi-AZ deployment, auto-scaling configuration, load balancing, database replication, and monitoring/alerting.

### ⛓️ [Ethereum](./examples/ethereum.md)
A blockchain development environment including local development chain, smart contract deployment, testing framework, monitoring tools, and gas optimization.

### 🔄 [Hybrid Cloud](./examples/hybrid-cloud.md)
A multi-cloud infrastructure featuring cross-cloud deployment, unified monitoring, data synchronization, security policies, and cost optimization.

## Deployment Recipes

The [deployment recipes](deployments/index.md) provide comprehensive, step-by-step guides that walk you through building complete deployments from the ground up. These instructional guides break down the implementation process into clear, actionable steps, making them ideal for learning and adapting infrastructure patterns to your own environment.

### How Deployment Recipes and Examples Work Together

- **Deployment Recipes** (`/docs/deployments/`): Step-by-step instructional guides that teach you **how** to build your own deployment. Follow these recipes to understand each step of the process and create your own implementation.

- **Examples** (`/examples/`): Working, production-ready deployments that serve as reference implementations. Use these to **compare** your implementation against a tested, working solution. The examples are also used for regression testing to ensure patterns remain functional.

By following a deployment recipe, you'll build your own deployment step-by-step. You can then compare your implementation with the corresponding example to verify it matches the reference implementation and understand any differences.

### Available Deployment Recipes

- **[Bootstrapping Nodes](./deployments/bootstrapping/README.md)**: Instructions for bootstrapping Talos clusters on Raspberry Pi and Intel NUC devices
- **[Home Assistant](./deployments/home-assistant/README.md)**: Complete guide for deploying a home automation platform
- **[GitHub Actions Runners](./deployments/runners/)**: Guides for setting up self-hosted runners on Ubuntu, Windows, and macOS

## Getting Started

1. Review the [Installation Guide](install.md)
2. Explore the [Examples](examples/index.md)
3. Explore deployment [recipes](deployments/index.md)

## Getting Help

- [GitHub Issues](https://github.com/tvangundy/workspace/issues)
- [GitHub Discussions](https://github.com/tvangundy/workspace/discussions)
- [Documentation Site](https://tvangundy.github.io)

## Contact

For questions or collaboration:
- [LinkedIn](https://linkedin.com/in/tvangundy)
- [GitHub](https://github.com/tvangundy)
- [Email](mailto:tvangundy@gmail.com)
