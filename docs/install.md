---
title: "Installation"
description: "Installation Guide"
---
# Installation Guide

Get started with the workspace by following these installation steps. You'll need a few basic tools installed on your development workstation to work with the runbooks and explore the documentation.

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

Now that you have all the prerequisites installed, let's set up your workspace. This will create a local development environment with all the necessary tools and configurations to work with the runbooks.

#### Clone the Repository
```bash
git clone https://github.com/tvangundy/workspace.git
cd workspace
```

#### Install Dependencies
```bash
aqua install
```

#### Get Started with Runbooks

Explore the available [runbooks](./runbooks/README.md) to find step-by-step guides for building infrastructure deployments. Each runbook provides detailed instructions from initial setup through final deployment.
