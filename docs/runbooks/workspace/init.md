---
title: "Workspace"
description: "Step-by-step guide for initializing a new workspace"
---

# Workspace

This runbook walks you through initializing a new workspace using the workspace initialization task and Windsor CLI.



## Prerequisites

- [Windsor CLI](https://windsorcli.github.io/latest/install/) installed and configured
- Access to the workspace repository
- A context name for your workspace (e.g., `local`, `rpi`, `prod`)

## ⚠️ Important Warning

**Workspaces cannot be nested under another workspace.**

Windsor CLI searches up the directory tree for `.windsor` folders. If a `.windsor` folder is found in a parent directory, Windsor will assume that environment and **will not generate files locally** in your new workspace.

**Example of what NOT to do:**

```bash
# ❌ DON'T: Creating a workspace inside another workspace
/Users/$USER/Developer/existing-workspace/  # Has .windsor folder
  └── new-workspace/                        # Will use parent's .windsor
```

**Example of correct workspace structure:**

```bash
# ✅ DO: Create workspaces as siblings
/Users/$USER/Developer/
  ├── workspace-1/                          # Independent workspace
  ├── workspace-2/                          # Independent workspace
  └── workspace-3/                          # Independent workspace
```

Before initializing a new workspace, ensure that:

- The parent directory does not contain a `.windsor` folder
- The workspace path is not a subdirectory of an existing workspace
- Each workspace is created at the same directory level or in completely separate locations

## Overview

A workspace is fundamentally composed of two directories: `bin/` and `tasks/`. The `bin/` folder contains executable scripts and helpers, while the `tasks/` folder holds Taskfile definitions that orchestrate workflow automation. This design makes the environment easy to replicate—cloning or overwriting these directories brings the entire operational toolkit with it. It also keeps all workspace activities organized in one place, and allows each workspace to add or customize functionality by extending or replacing scripts and tasks without affecting others.

Initializing a workspace involves these steps:

1. **Create the workspace structure** using the `workspace:instantiate` task
2. **Populate the workspace** using Windsor CLI's `init` command

## Step 1: Initialize Workspace Structure

Use the `workspace:instantiate` task to create the initial workspace structure. This task takes two arguments:

- `<workspace-name>`: The name of your workspace
- `<workspace-path>`: The full path where the workspace should be created

### Command Syntax

```bash
task workspace:instantiate -- <workspace-name> <workspace-path>
```

This command creates the workspace structure at the specified path.

## Step 2: Initialize with Windsor CLI

Once you're in the workspace directory, use Windsor CLI to populate the folder with the necessary configuration files and structure for your chosen context.

### Command Syntax

```bash
cd <workspace-path>
windsor init <context>
```

## Next Steps

After initializing your workspace:

1. Review the generated configuration files in the `contexts/` directory
2. Customize the configuration to match your requirements
3. Use `windsor up` to start your deployment
4. Refer to other runbooks for specific deployment scenarios


## Related Documentation

- [Windsor CLI Documentation](https://windsorcli.github.io/latest/)
