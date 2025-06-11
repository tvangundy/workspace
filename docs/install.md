---
title: "Installation"
description: "Installation Guide"
---
# Installation Guide

Get started with the project examples by following these installation steps. You'll need a few basic tools installed on your development workstation to run the examples and explore the documentation.

## Prerequisites

Before you begin, ensure you have the following installed:

#### 1. Docker and Docker Compose
- [Install Docker](https://docs.docker.com/get-docker/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)
- Verify installation:

```bash
docker --version
docker compose version
```

#### 2. Aqua
- [Install Aqua](https://aquaproj.github.io/docs/overview/quick-start)
- Verify installation:

```bash
aqua --version
```

#### 3. Git
- [Install Git](https://git-scm.com/downloads)
- Verify installation:

```bash
git --version
```

#### 4. Windsor CLI
- Follow the [Windsor CLI installation guide](https://windsorcli.github.io/install/)
- Verify installation:

```bash
windsor --version
```

## Workspace Setup

Now that you have all the prerequisites installed, let's set up your workspace. This will create a local development environment with all the necessary tools and configurations to run the examples.

#### 1. Clone the Repository
```bash
git clone https://github.com/tvangundy/workspace.git
cd workspace
```

#### 2. Install Dependencies
```bash
aqua install
```

#### 3. Run Task
```bash
task
```
