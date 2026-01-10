---
title: "Workspace Tasks"
description: "Workspace initialization and management tasks for setting up and cleaning workspace repositories"
---
# Workspace Tasks (`workspace:`)

Workspace initialization and management.

## Overview

The `workspace:` namespace provides tools for initializing and managing workspace repositories. These tasks handle cloning workspace repositories, pulling updates, and cleaning up Docker resources.

## Task Reference

| Task | Description |
|------|-------------|
| [`initialize`](#initialize) | Initialize a new workspace by cloning the workspace repository |
| [`clean`](#clean) | Clean up Docker images and containers (convenience task) |

## Tasks

### `initialize`

Initialize a new workspace by cloning the workspace repository.

**Usage:**

```bash
task workspace:initialize [-- <workspace-name> <workspace-global-path>]
```

**Parameters:**

- `<workspace-name>` (optional): Name for the workspace. Default: `test-workspace`
- `<workspace-global-path>` (optional): Global path where workspace should be created. Default: `../<workspace-name>`

**What it does:**

1. Parses workspace name and path from arguments or uses defaults
2. Creates the workspace directory if it doesn't exist
3. If directory exists and is a git repository:
   - Pulls latest changes using `git pull --ff-only`
4. If directory exists but is not a git repository:
   - Errors out (refuses to overwrite non-empty non-git directories)
5. If directory doesn't exist:
   - Clones the workspace repository from `https://github.com/tvangundy/workspace.git`

**Example:**

```bash
# Use defaults (test-workspace in ../test-workspace)
task workspace:initialize

# Specify custom name and path
task workspace:initialize -- my-workspace ~/workspaces/my-workspace

# Initialize in current directory's parent
task workspace:initialize -- my-project ..
```

**Output:** Shows initialization status and workspace location.

**Note:** This clones the public workspace repository. For private workspace setups, you may need to modify the repository URL in the Taskfile.

### `clean`

Clean up Docker images and containers. This is a convenience task that calls Docker cleanup commands.

**Usage:**

```bash
task workspace:clean
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
task workspace:clean
```

**Note:** This is the same as `task docker:clean`. The task exists in the workspace namespace for convenience.

## Prerequisites

### For `initialize`:

- Git installed
- Network access to GitHub
- Write permissions to the target directory
- For existing repositories: Git credentials configured

### For `clean`:

- Docker installed and running
- Docker daemon accessible

## Workflow Example

Typical workspace setup:

```bash
# 1. Initialize workspace
task workspace:initialize -- my-project ~/projects/my-project

# 2. Change to workspace directory
cd ~/projects/my-project

# 3. Follow workspace-specific setup instructions
# (Usually found in the workspace's README.md)
```

## Help

View all available workspace commands:

```bash
task workspace:help
```

## Taskfile Location

Task definitions are located in `tasks/workspace/Taskfile.yaml`.
