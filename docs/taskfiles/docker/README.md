---
title: "Docker Tasks"
description: "Docker container management and cleanup tasks"
---
# Docker Tasks (`docker:`)

Docker container management and cleanup.

## Overview

The `docker:` namespace provides utilities for managing Docker containers and cleaning up Docker resources. These tasks help maintain a clean Docker environment by removing unused containers and images.

## Tasks

### `clean`

Clean up Docker images and containers. Kills all running containers and prunes the entire Docker system.

**Usage:**

```bash
task docker:clean
```

**What it does:**

1. Kills all running containers (`docker kill $(docker ps -q)`)
2. Prunes the entire Docker system (`docker system prune -af`)

**Warning:** This command will:

- Stop and remove all running containers
- Remove all stopped containers
- Remove all unused images (not just dangling ones)
- Remove all unused networks
- Remove all unused volumes
- Remove all build cache

**Use with caution:** This is a destructive operation that removes all unused Docker resources.

**Example:**

```bash
# Clean up all Docker resources
task docker:clean
```

**Output:** Shows what was removed (containers, images, networks, volumes, build cache) and the amount of disk space reclaimed.

## Prerequisites

- Docker installed and running
- Docker daemon accessible (`docker ps` should work)

## Help

View all available Docker commands:

```bash
task docker:help
```

## Taskfile Location

Task definitions are located in `tasks/docker/Taskfile.yaml`.
