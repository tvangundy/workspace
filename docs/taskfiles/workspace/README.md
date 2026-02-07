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
| [`instantiate`](#instantiate) | Instantiate a new workspace by cloning the workspace repository |
| [`overwrite`](#overwrite) | Overwrite `tasks/` and `bin/` in a destination workspace with contents from a source workspace |
| [`clean`](#clean) | Clean up Docker images and containers (convenience task) |

## Tasks

### `instantiate`

Instantiate a new workspace by cloning the workspace repository.

**Usage:**

```bash
task workspace:instantiate -- <workspace-name> <workspace-path>
```

**Parameters:**

- `<workspace-name>` (required): Name for the workspace
- `<workspace-path>` (required): Path where workspace should be created

**What it does:**

1. Parses workspace name and path from required arguments
2. Creates the workspace directory if it doesn't exist
3. If directory exists and is a git repository:
   - Pulls latest changes using `git pull --ff-only`
4. If directory exists but is not a git repository:
   - Errors out (refuses to overwrite non-empty non-git directories)
5. If directory doesn't exist:
   - Clones the workspace repository from `https://github.com/tvangundy/workspace.git`

**Example:**

```bash
# Specify workspace name and path (both required)
task workspace:instantiate -- my-workspace ~/workspaces/my-workspace

# Instantiate in current directory's parent
task workspace:instantiate -- my-project ..
```

**Output:** Shows initialization status and workspace location.

**Note:** This clones the public workspace repository (`https://github.com/tvangundy/workspace.git`). For private workspace setups, you may need to modify the repository URL in the Taskfile.

### `overwrite`

Overwrite `tasks/` and `bin/` in a destination workspace with contents from a source workspace. Use this to sync task definitions and scripts from one workspace (e.g. a template or upstream) into another.

**Usage:**

```bash
task workspace:overwrite -- <src-workspace-path> <dst-workspace-path>
```

**Parameters:**

- `<src-workspace-path>` (required): Path to the source workspace (must contain `tasks/` and `bin/` directories)
- `<dst-workspace-path>` (required): Path to the destination workspace where `tasks/` and `bin/` will be replaced

**What it does:**

1. Resolves paths (supports `.` for current directory)
2. Verifies source contains `tasks/` and `bin/` directories
3. Ensures source and destination are different paths
4. Removes existing `tasks/` and `bin/` in destination
5. Copies `tasks/` and `bin/` from source to destination

**Examples:**

```bash
# Overwrite from current directory into another workspace
task workspace:overwrite -- . ~/workspaces/my-workspace

# Overwrite from one workspace into another
task workspace:overwrite -- ~/forest-shadows ~/my-project
```

**Warning:** This destructively replaces `tasks/` and `bin/` in the destination. Any local changes in those directories will be lost.

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

### For `instantiate`:

- Git installed
- Network access to GitHub
- Write permissions to the target directory
- For existing repositories: Git credentials configured

### For `overwrite`:

- Source workspace must contain `tasks/` and `bin/` directories
- Write permissions to the destination workspace

### For `clean`:

- Docker installed and running
- Docker daemon accessible

## Workflow Example

Typical workspace setup:

```bash
# 1. Instantiate workspace
task workspace:instantiate -- my-project ~/projects/my-project

# 2. Change to workspace directory
cd ~/projects/my-project

# 3. (Optional) Overwrite tasks/bin from another workspace
task workspace:overwrite -- ~/forest-shadows ~/projects/my-project

# 4. Follow workspace-specific setup instructions
# (Usually found in the workspace's README.md)
```

## Help

View all available workspace commands:

```bash
task workspace:help
```

## Taskfile Location

Task definitions are located in `tasks/workspace/Taskfile.yaml`.
