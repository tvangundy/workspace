---
title: "Initialize Workspace"
description: "Step-by-step guide for initializing a new workspace"
---

# Initialize Workspace

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

Initializing a workspace involves three main steps:

1. **Create the workspace structure** using the `workspace:initialize` task
2. **Populate the workspace** using Windsor CLI's `init` command

## Step 1: Initialize Workspace Structure

Use the `workspace:initialize` task to create the initial workspace structure. This task takes two arguments:

- `<workspace-name>`: The name of your workspace
- `<workspace-global-path>`: The full path where the workspace should be created

### Command Syntax

```bash
task workspace:initialize -- <workspace-name> <workspace-global-path>
```

This command creates the workspace structure at the specified path.

## Step 2: Change to Workspace Directory

Navigate to the workspace directory that was created:

```bash
cd <workspace-global-path>
```

## Step 3: Initialize with Windsor CLI

Once you're in the workspace directory, use Windsor CLI to populate the folder with the necessary configuration files and structure for your chosen context.

### Command Syntax

```bash
windsor init <context>
```

## Next Steps

After initializing your workspace:

1. Review the generated configuration files in the `contexts/` directory
2. Customize the configuration to match your requirements
3. Use `windsor up` to start your deployment
4. Refer to other runbooks for specific deployment scenarios

## Troubleshooting

### Workspace Already Exists

If the workspace path already exists, you may need to:
- Choose a different path
- Remove the existing directory if it's safe to do so

### Windsor Not Generating Files Locally

If `windsor init` runs but doesn't generate files in your workspace directory:

- **Check for parent `.windsor` folders**: Windsor searches up the directory tree for `.windsor` folders. If one exists in a parent directory, Windsor will use that environment instead of creating a new one.

  ```bash
  # Check for .windsor folders in parent directories
  find <workspace-path> -name ".windsor" -type d
  ```

- **Solution**: Create your workspace in a location that is not nested under another workspace. Ensure no parent directory contains a `.windsor` folder.

### Windsor Context Not Found

If Windsor reports that a context is not found:
- Verify the context name is correct
- Check that the context configuration exists in your Windsor setup
- Review the [Windsor CLI documentation](https://windsorcli.github.io/latest/) for context management

### Permission Errors

If you encounter permission errors:
- Ensure you have write permissions to the workspace path
- Check that the directory structure can be created

## Related Documentation

- [Windsor CLI Installation Guide](../install.md#windsor-cli)
- [Home Assistant Runbook](../home-assistant/README.md) - Example of workspace initialization in practice
- [Windsor CLI Documentation](https://windsorcli.github.io/latest/)
