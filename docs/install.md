---
title: "Installation"
description: "Installation Guide"
---
# Installation Guide

Get started with the project examples by following these installation steps. You'll need a few basic tools installed on your development workstation to run the examples and explore the documentation.

## Prerequisites

Before you begin, ensure you have the following installed:

#### Docker and Docker Compose
- [Install Docker](https://docs.docker.com/get-docker/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)
- Verify installation:

```bash
docker --version
docker compose version
```

#### Aqua
- [Install Aqua](https://aquaproj.github.io/docs/install)
- Verify installation:

```bash
aqua --version
```

#### Git
- [Install Git](https://git-scm.com/downloads)
- Verify installation:

```bash
git --version
```

#### Windsor CLI
- Follow the [Windsor CLI installation guide](https://windsorcli.github.io/latest/install/)
- Verify installation:

```bash
windsor --version
```

## Workspace Setup

Now that you have all the prerequisites installed, let's set up your workspace. This will create a local development environment with all the necessary tools and configurations to run the examples.

#### Clone the Repository
```bash
git clone https://github.com/tvangundy/workspace.git
cd workspace
```

#### Install Dependencies
```bash
aqua install
```

#### Change to the appropriate example folder and read the README.md

Available examples:

- [AWS Web Cluster](../examples/aws-web-cluster/README.md)
- [Ethereum](../examples/ethereum/README.md)
- [Home Assistant](../examples/home-assistant/README.md)
- [Hybrid Cloud](../examples/hybrid-cloud/README.md)
- [Sidero Omni](../examples/sidero-omni/README.md)
- [Tailscale](../examples/tailscale/README.md)
- [Wireguard](../examples/wireguard/README.md)
