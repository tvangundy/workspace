---
title: "Dev Tasks"
description: "Development environment management tasks"
---
# Dev Tasks (`dev:`)

Development environment management for creating and managing development containers and VMs on Incus.

## Instance Creation

- `task dev:create [-- <type> <image> [--name <name>]]` - Create a dev container or VM instance (defaults: `DEV_INSTANCE_TYPE`, `DEV_IMAGE`, `DEV_INSTANCE_NAME`)

## Instance Management

- `task dev:start [-- <instance-name>]` - Start a dev instance
- `task dev:stop [-- <instance-name>]` - Stop a dev instance
- `task dev:restart [-- <instance-name>]` - Restart a dev instance
- `task dev:list` - List all dev instances
- `task dev:info [-- <instance-name>]` - Get detailed information about a dev instance
- `task dev:debug [-- <instance-name>]` - Debug performance and resource usage
- `task dev:delete [-- <instance-name>]` - Delete a dev instance

## Access

- `task dev:shell [-- <instance-name>]` - Open an interactive shell in the instance
- `task dev:ssh [-- <instance-name>]` - SSH into a VM instance
- `task dev:ssh-info [-- <instance-name>]` - Show SSH connection information
- `task dev:exec -- <instance-name> -- <command>` - Execute a command in the instance

## Workspace Management

- `task dev:init-workspace [-- <instance-name>]` - Initialize workspace contents in an existing VM
- `task dev:copy-workspace [-- <instance-name>]` - Copy entire workspace (replaces existing)
- `task dev:add-workspace [-- <instance-name>]` - Add workspace to instance (same as during creation)
- `task dev:sync-workspace [-- <instance-name>]` - Sync workspace changes using rsync (uploads only changed files)

## Help

- `task dev:help` - Show all dev environment commands

## Environment Variables

- `DEV_INSTANCE_TYPE` - Default instance type (container or vm)
- `DEV_IMAGE` - Default image (e.g., ubuntu/24.04)
- `DEV_INSTANCE_NAME` - Default instance name
- `INCUS_REMOTE_NAME` - Incus remote name

## Taskfile Location

Task definitions are located in `tasks/dev/Taskfile.yaml`.

