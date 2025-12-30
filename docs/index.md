---
title: "Home"
description: "Welcome to Workspaces"
---


# Welcome to Workspace

A curated collection of infrastructure implementations and automation solutions. This workspace provides comprehensive runbooks that demonstrate real-world applications of modern cloud technologies, container orchestration, and infrastructure-as-code practices. Each runbook is designed to be both educational and immediately useful, providing practical solutions that can be adapted for your own infrastructure needs.

## Getting Started

1. Review the [Installation Guide](install.md)
2. Explore [runbooks](#runbooks)

## Runbooks

The [runbooks](./runbooks/README.md) provide comprehensive, step-by-step guides that walk you through building complete deployments from the ground up. These instructional guides break down the implementation process into clear, actionable steps, making them ideal for learning and adapting infrastructure patterns to your own environment.

### Workspace Composition: Runbooks and Taskfiles

This workspace is built on the principle that **runbooks** and **taskfiles** work together to create a powerful, repeatable infrastructure deployment system. Understanding how they complement each other is key to getting the most out of this workspace.

#### How Workspaces Are Structured

A workspace in this repository consists of:

1. **Runbooks** (`/docs/runbooks/`): Step-by-step instructional guides that document the **what** and **why** of each deployment step
2. **Taskfiles** (`/tasks/`): Executable automation scripts that provide the **how** - the actual commands and operations needed to complete each step

Together, they form a complete system where:
- **Runbooks** provide the knowledge and context
- **Taskfiles** provide the automation and repeatability

#### How Taskfiles Enhance Runbooks

Taskfiles bring several key benefits that make runbooks more powerful and practical:

**1. Consistency and Repeatability**

Instead of manually typing complex commands with different syntax across platforms, taskfiles provide a single, consistent interface:

```bash
# Instead of remembering platform-specific commands:
# macOS: diskutil unmountDisk /dev/disk4
# Linux: umount /dev/sdX

# You simply run:
task device:unmount-disk
```

The taskfile handles platform differences internally, ensuring the same command works everywhere.

**2. Error Prevention**

Taskfiles include validation and error checking that prevent common mistakes:

- **Variable validation**: Ensures required environment variables are set before execution
- **Pre-flight checks**: Verifies prerequisites (file existence, disk availability, network connectivity)
- **Safe defaults**: Provides sensible defaults while allowing customization
- **Clear error messages**: When something fails, you get actionable error messages instead of cryptic command-line errors

**3. Complex Operations Made Simple**

Many infrastructure tasks involve multiple steps, conditional logic, and error handling. Taskfiles encapsulate this complexity:

```bash
# Writing a disk image involves:
# - Validating inputs
# - Unmounting disks
# - Writing the image with progress monitoring
# - Verifying the write
# - Handling errors gracefully
# - Supporting parallel operations

# All handled by a single command:
task device:write-disk -- 3  # Write to 3 disks in parallel
```

**4. Context-Aware Execution**

Taskfiles integrate with the Windsor CLI context system, automatically using the correct configuration:

- Environment variables are loaded from `contexts/<context>/windsor.yaml`
- File paths are resolved relative to the current context
- Multiple contexts can be managed without manual path manipulation

**5. Discoverability**

Taskfiles make it easy to discover available operations:

```bash
# See all available tasks
task --list-all

# Get help for a specific namespace
task device:help

# Understand what a task does
task device:write-disk --dry
```

**6. Documentation Through Code**

Taskfiles serve as executable documentation. The task definitions show exactly what operations are performed, making it easier to:
- Understand what each step does
- Debug issues when something goes wrong
- Customize behavior by modifying the taskfile
- Learn the underlying commands by examining the task implementation

#### Example: Runbook + Taskfile Integration

Here's how a runbook step and its corresponding taskfile work together:

**In the Runbook** (documentation):
```markdown
## Step 3: Prepare the Boot Media

Write the Talos image to your USB memory device:

```bash
task device:write-disk
```

This will write the image to the disk specified in `USB_DISK` environment variable.
```

**In the Taskfile** (automation):
```yaml
write-disk:
  desc: Writes the Talos image to one or more USB drives
  cmds:
    - |
      # Validates USB_DISK is set
      # Checks image file exists
      # Unmounts the disk safely
      # Writes with progress monitoring
      # Verifies the write completed
      # Handles errors gracefully
```

The runbook explains **what** to do and **why**, while the taskfile provides the **how** with all the complexity handled automatically.

#### Benefits for Users

This integration provides several advantages:

- **Faster execution**: No need to look up command syntax or remember complex flags
- **Fewer errors**: Validation and error checking catch issues early
- **Better learning**: You can see what commands are actually run, helping you learn
- **Easier customization**: Modify taskfiles to adapt to your specific needs
- **Cross-platform**: Same commands work on macOS, Linux, and other platforms
- **Reproducible**: Anyone following the runbook gets the same results

Runbooks in this workspace leverage taskfiles extensively, so you'll see commands like `task device:write-disk` throughout the documentation. These taskfile commands encapsulate complex operations, making the runbooks easier to follow while ensuring consistent, reliable execution.

### Available Runbooks

- **[Workspace Initialization](./runbooks/workspace/init.md)**: Guide for initializing a new workspace
- **[Secrets Management](./runbooks/secrets/secrets.md)**: Guide for managing secrets with SOPS
- **[Incus Setup](./runbooks/incus/incus-setup.md)**: Complete guide for installing and configuring IncusOS on Intel NUC devices
- **[Bootstrapping Nodes](./runbooks/bootstrapping/README.md)**: Instructions for bootstrapping Talos clusters on Raspberry Pi and Intel NUC devices
- **[Home Assistant](./runbooks/home-assistant/README.md)**: Complete guide for deploying a home automation platform
- **[Ubuntu Setup](./runbooks/ubuntu/ubuntu-setup.md)**: Complete guide for installing and configuring Ubuntu on Intel NUC devices
- **GitHub Actions Runners**: Guides for setting up self-hosted runners on Ubuntu, Windows, and macOS

## Getting Help

- [GitHub Issues](https://github.com/tvangundy/workspace/issues)
- [GitHub Discussions](https://github.com/tvangundy/workspace/discussions)
- [Documentation Site](https://tvangundy.github.io)

## Contact

For questions or collaboration:
- [LinkedIn](https://linkedin.com/in/tvangundy)
- [GitHub](https://github.com/tvangundy)
- [Email](mailto:tvangundy@gmail.com)
