---
title: "Home"
description: "Welcome to Workspaces"
---


# Welcome to Workspace

A curated collection of infrastructure implementations and automation solutions. This workspace provides comprehensive runbooks that demonstrate real-world applications of modern cloud technologies, container orchestration, and infrastructure-as-code practices. Each runbook is designed to be both educational and immediately useful, providing practical solutions that can be adapted for your own infrastructure needs.

## Getting Started

1. Review the [Installation Guide](install.md)
2. Explore [runbooks](#runbooks)

## Workspace Composition: Runbooks and Taskfiles

This workspace is built on the principle that **runbooks** and **taskfiles** work together to create a powerful, repeatable infrastructure deployment system. Understanding how they complement each other is key to getting the most out of this workspace.

### What Is a Workspace?

A workspace is both a **collection of artifacts** and a **methodology** for building and managing infrastructure. From a code perspective, a workspace consists of:

1. **Runbooks** (`/docs/runbooks/`): Step-by-step instructional guides that document the **what** and **why** of each deployment step
2. **Taskfiles** (`/tasks/`): Executable automation scripts that provide the **how** - the actual commands and operations needed to complete each step
3. **Configurations** (`/contexts/`): Context-specific settings and configurations that define how the workspace operates in different environments
4. **Secrets**: Securely managed credentials and sensitive data, integrated through the Windsor CLI context system

But a workspace is more than just code—it's a **way of working** that includes storing your state, configurations, and context so you can pick up where you left off. 

This persistence means you can:

- **Resume work later**: All your configurations, secrets, and context are preserved
- **Share and collaborate**: Others can use the same workspace structure and pick up the work
- **Version and iterate**: Track changes to your infrastructure approach over time
- **Reproduce environments**: Recreate the same setup across different machines or teams

Together, these components form a complete system where:
- **Runbooks** provide the knowledge and context
- **Taskfiles** provide the automation and repeatability
- **Configurations and secrets** provide the environment-specific context
- **The workspace methodology** ensures everything is stored and can be resumed later

## Runbooks

The [runbooks](./runbooks/README.md) provide comprehensive, step-by-step guides that walk you through building complete deployments from the ground up. These instructional guides break down the implementation process into clear, actionable steps, making them ideal for learning and adapting infrastructure patterns to your own environment.

### Available Runbooks

- **[Workspace Initialization](./runbooks/workspace/init.md)**: Guide for initializing a new workspace
- **[Secrets Management](./runbooks/secrets/secrets.md)**: Guide for managing secrets with SOPS
- **[IncusOS Setup](./runbooks/incusos/incusos-setup.md)**: Complete guide for installing and configuring IncusOS on Intel NUC devices
- **[GitHub Runners on IncusOS VMs](./runbooks/incusos/github-runner.md)**: Set up GitHub Actions runners using Ubuntu and Windows VMs on IncusOS
- **[Talos on IncusOS VMs](./runbooks/talos/talos-incus-vm.md)**: Deploy a Talos Kubernetes cluster using VMs on IncusOS
- **[Bootstrapping Nodes](./runbooks/bootstrapping/README.md)**: Instructions for bootstrapping Talos clusters on Raspberry Pi and Intel NUC devices
- **[Home Assistant](./runbooks/home-assistant/README.md)**: Complete guide for deploying a home automation platform
- **[Ubuntu Setup](./runbooks/ubuntu/ubuntu-setup.md)**: Complete guide for installing and configuring Ubuntu on Intel NUC devices
- **[Self Hosted Runners](./runbooks/runners/ubuntu-runner-setup.md)**: Guides for setting up self-hosted runners on Ubuntu


## Taskfiles

This workspace uses [Taskfile](https://taskfile.dev) to organize and automate common operations. Tasks are organized into namespaces and placed in the `./tasks` folder, making it easy to discover and execute common operations.

Tasks are organized into namespaces and stored in the `./tasks` folder. Each namespace has its own `Taskfile.yaml` that defines the available tasks for that domain. This pattern keeps related tasks grouped together, makes it easy to discover functionality, and allows you to add new namespaces as needed.

### Available Taskfiles

- **workspace**: Workspace initialization and management tasks for setting up new workspaces
- **sops**: SOPS encryption and decryption tasks for managing secrets securely
- **device**: Device management tasks for disk operations, mounting, and hardware interactions
- **docker**: Docker-related tasks for container management and operations
- **vhs**: VHS terminal recording tasks for creating animated terminal recordings
- **talos**: Talos cluster tasks for Kubernetes cluster management and operations
- **incus**: Incus container and VM management tasks
- **runner**: GitHub Actions runner tasks for setting up and managing self-hosted runners
- **dev**: Development environment tasks for creating and managing Incus-based development containers and VMs

### Taskfile Organization

Tasks are organized into namespaces using the `namespace:task` syntax. Tasks are executed using the `task <Namespace>:<taskname>` syntax, where each namespace groups related functionality. 

For example: `task sops:decrypt -- <file>` or `task device:write-disk`

### Common Commands

- **View available tasks**: `task <namespace>:help` (e.g., `task device:help`)
- **Open documentation**: `task help` (opens https://tvangundy.github.io)
- **Dry run**: `task <namespace>:<task> --dry` (preview commands without executing)

## How Taskfiles Enhance Runbooks

Taskfiles bring several key benefits that make runbooks more powerful and practical:

**1. Consistency and Repeatability**

Instead of remembering platform-specific commands (like `diskutil unmountDisk` on macOS or `umount` on Linux), taskfiles provide a single, consistent interface. You simply run `task device:unmount-disk` and the taskfile handles platform differences internally, ensuring the same command works everywhere.

**2. Error Prevention**

Taskfiles include validation and error checking that prevent common mistakes:

- **Variable validation**: Ensures required environment variables are set before execution
- **Pre-flight checks**: Verifies prerequisites (file existence, disk availability, network connectivity)
- **Safe defaults**: Provides sensible defaults while allowing customization
- **Clear error messages**: When something fails, you get actionable error messages instead of cryptic command-line errors

**3. Complex Operations Made Simple**

Many infrastructure tasks involve multiple steps, conditional logic, and error handling. Taskfiles encapsulate this complexity. For example, writing a disk image involves:

- Validating inputs
- Writing with progress monitoring
- Verifying the write
- Handling errors gracefully
- Supporting parallel operations
- Unmounting disks

All handled by a single command:

```bash
task device:write-disk -- 3  # Write to 3 disks in parallel
```

**4. Context-Aware Execution**

Taskfiles integrate with the Windsor CLI context system, automatically using the correct configuration:

- Environment variables are loaded from `contexts/<context>/windsor.yaml`
- Secrets are securely managed through the Windsor CLI, eliminating the need to manually handle sensitive credentials
- File paths are resolved relative to the current context
- Multiple contexts can be managed without manual path manipulation

**5. Discoverability**

Taskfiles make it easy to discover available operations:

**See available namespaces:**
```bash
task
```

Output:
```
Namespace sensitive tasks

    task <namespace>:help

Available namespaces

workspace, device, sops, docker, vhs, talos, incus, runner, dev
```

**See all available tasks:**
```bash
task --list-all
```

**Get help for a specific namespace:**
```bash
task device:help
```

**Full transparency with dry run:**

The `--dry` flag shows exactly what commands will be executed without running them. For example:

```bash
task device:write-disk --dry
```

The `--dry` flag is particularly valuable for learning and adoption. It shows exactly what commands will be executed at the tool level, revealing the underlying operations without actually running them. This transparency helps users understand how taskfiles work, learn the underlying commands, and build confidence before executing tasks in production environments.

**6. Documentation Through Code**

Taskfiles serve as executable documentation. The task definitions show exactly what operations are performed, making it easier to:
- Understand what each step does
- Debug issues when something goes wrong
- Customize behavior by modifying the taskfile
- Learn the underlying commands by examining the task implementation

## Example: Runbook + Taskfile Integration

Here's how a runbook step and its corresponding taskfile work together:

**In the Runbook** (documentation):

#### Step 3: Prepare the Boot Media

Write the Talos image to your USB memory device:

```bash
task device:write-disk
```

This will write the image to the disk specified in `USB_DISK` environment variable.

**In the Taskfile**:
```yaml
write-disk:
  desc: Writes the Talos image to one or more USB drives
  cmds:
    - |
      # Validates USB_DISK is set
      # Checks image file exists
      # Mounts the disk safely
      # Writes with progress monitoring
      # Verifies the write completed
      # Handles errors gracefully
      # Unmounts the disk safely
```

The runbook explains **what** to do and **why**, while the taskfile provides the **how** with all the complexity handled automatically.

### Benefits for Users

This integration provides several advantages:

- **Faster execution**: No need to look up command syntax or remember complex flags
- **Fewer errors**: Validation and error checking catch issues early
- **Better learning**: You can see what commands are actually run, helping you learn
- **Easier customization**: Modify taskfiles to adapt to your specific needs
- **Cross-platform**: Same commands work on macOS, Linux, and other platforms
- **Reproducible**: Anyone following the runbook gets the same results

Runbooks in this workspace leverage taskfiles extensively, so you'll see commands like `task device:write-disk` throughout the documentation. These taskfile commands encapsulate complex operations, making the runbooks easier to follow while ensuring consistent, reliable execution.
