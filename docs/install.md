---
title: "Installation"
description: "Installation Guide"
---
# Installation Guide

Get started with the workspace by installing the required tools and setting up your development environment. This guide covers the essential prerequisites and workspace initialization steps.

## Prerequisites

Before you begin, install these core tools on your development workstation. These are the foundational tools needed to work with the workspace, runbooks, and taskfiles.

### Core Tools

#### Git
Version control for cloning the workspace repository and managing your infrastructure code.

- [Install Git](https://git-scm.com/downloads)
- Verify installation:

```bash
git --version
```

#### Aqua
Declarative CLI version manager that automatically installs and manages tool versions defined in `aqua.yaml`. Aqua will install additional tools like Terraform, kubectl, talosctl, incus, and others based on the workspace configuration.

- [Install Aqua](https://aquaproj.github.io/docs/install)
- Verify installation:

```bash
aqua --version
```

#### Taskfile
Task runner for executing workspace operations. Taskfile provides the `task` command used throughout the runbooks.

- [Install Taskfile](https://taskfile.dev/installation/)
- Verify installation:

```bash
task --version
```

#### Windsor CLI
Command-line interface for managing workspace contexts, configurations, and environment variables. Windsor integrates with Terraform, Kubernetes, and other infrastructure tools.

- [Install Windsor CLI](https://windsorcli.github.io/latest/install/)
- Verify installation:

```bash
windsor --version
```

#### Docker and Docker Compose
Required for local development containers, container management, and many infrastructure deployments.

- [Install Docker](https://docs.docker.com/get-docker/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)
- Verify installation:

```bash
docker --version
docker compose version
```

## Workspace Setup

After installing the prerequisites, set up your workspace to get started with the runbooks and taskfiles.

### Step 1. Clone the Repository

Clone the workspace repository to your local machine:

```bash
git clone https://github.com/tvangundy/workspace.git
cd workspace
```

### Step 2. Install Tool Dependencies

Install all tools defined in the workspace `aqua.yaml` file. This includes Terraform, kubectl, talosctl, incus, helm, flux, and other tools used by the runbooks:

```bash
aqua install
```

This command reads the `aqua.yaml` file and installs all specified tools to the correct versions.

### Step 3. Verify Installation

Verify that the tools are accessible:

```bash
task --version
windsor --version
aqua list
```

### Step 4. Initialize Your First Workspace

Follow the [Initialize Workspace](./runbooks/workspace/init.md) runbook to create your first workspace context. This sets up the directory structure and configuration needed for working with infrastructure deployments.

## Next Steps

Now that your workspace is set up, you're ready to start working with the documentation:

- **Explore Runbooks**: Browse the available [runbooks](./runbooks/README.md) for step-by-step guides on deploying infrastructure
- **Learn About Taskfiles**: Review the [Taskfiles documentation](./taskfiles/README.md) to understand how to execute common operations
- **Choose a Runbook**: Start with a runbook that matches your needs:
  - **Development**: [Local Development Container](./runbooks/incusos/dev-container-local.md) or [Remote Development VM](./runbooks/incusos/dev-vm-remote.md)
  - **Kubernetes**: [Talos Cluster on IncusOS (Manual)](./runbooks/incusos/talos-incus-vm.md), [Talos Cluster on IncusOS (Terraform)](./runbooks/incusos/talos-incus-terraform.md), or [Bootstrapping Nodes](./runbooks/bootstrapping/README.md)
  - **CI/CD**: [GitHub Runner Setup](./runbooks/incusos/github-runner.md)

Each runbook includes detailed prerequisites, step-by-step instructions, and verification steps to guide you through the deployment process.
