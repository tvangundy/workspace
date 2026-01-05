---
title: "Home"
description: "Welcome to Workspaces"
---


# Welcome to Workspace

A workspace is a **repeatable environment** for building and managing infrastructure using standardized runbooks, taskfiles, and configurations. Workspaces bundle everything needed to deploy and manage infrastructure—from Terraform modules and Kubernetes manifests to secrets and environment variables—into a version-controlled, shareable package that works consistently across cloud and bare-metal deployments.

## Why Workspaces?

**🚀 Speed and Consistency**: Quickly bring infrastructure up using runbooks. Standardized workflows help teams share knowledge and collaborate effectively.

**🔄 Repeatability and Persistence**: Deploy infrastructure, save to disk or S3, then retrieve and resume exactly where you left off for maintenance or upgrades.

**🛠️ Tool Adoption and Abstraction**: Adopt new tools quickly while maintaining legacy systems. **Runbooks** provide step-by-step guidance, while **taskfiles** abstract complex tasks . Modify underlying tools without impacting workflows, with flexibility across cloud providers and bare-metal. Native support for Terraform, Kubernetes, Incus, Docker, and more.

**🔒 Security Built-In**: Security is fundamental, not an afterthought. [Windsor CLI](https://github.com/windsorcli/cli) provides encrypted secret management with SOPS, context-based isolation, secure credential handling, and environment variable protection. Secrets are never stored in plain text.

**📦 Complexity Reduction**: By standardizing how infrastructure work is done, workspaces reduce complexity and make it easier to understand, maintain, and evolve your infrastructure over time.

Comprehensive runbooks demonstrate real-world applications of modern cloud technologies, container orchestration, and infrastructure-as-code practices. Each runbook is both educational and immediately useful, providing practical solutions you can adapt for your own infrastructure needs.

## Who Needs Workspaces?

Workspaces are ideal for **infrastructure engineers**, **DevOps teams**, **system administrators**, and **developers** who work with infrastructure. They're particularly valuable for:

- **Teams collaborating on infrastructure**: When multiple people need to work on the same infrastructure projects, workspaces provide a shared, standardized approach that makes collaboration seamless
- **Organizations managing multiple environments**: Workspaces make it easy to maintain consistency across development, staging, and production environments
- **Those deploying to both cloud and bare-metal**: Workspaces abstract away the differences, allowing you to use the same workflows regardless of deployment target
- **Teams adopting new tools while maintaining legacy systems**: Workspaces help you integrate modern tools without disrupting existing infrastructure
- **Anyone needing repeatable, maintainable infrastructure**: If you've ever struggled to remember how you set something up six months ago, or needed to recreate an environment from scratch, workspaces solve that problem
- **Those conducting experiments and research**: Workspaces excel at quickly bringing up systems to evaluate performance tradeoffs, compare tool selections, and conduct experimental or research-oriented efforts. Spin up a test environment, run your experiments, and easily tear it down or save it for later analysis


## Workspace Composition: Runbooks and Taskfiles

Built on the principle that **runbooks** and **taskfiles** work together to create a powerful, repeatable infrastructure deployment system. Understanding how they complement each other is key to maximizing productivity.

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
- **[IncusOS Setup](./runbooks/incusos/setup.md)**: Complete guide for installing and configuring IncusOS on Intel NUC devices
- **[GitHub Runners on IncusOS VMs](./runbooks/incusos/github-runner.md)**: Set up GitHub Actions runners using Ubuntu and Windows VMs on IncusOS
- **[Talos on IncusOS VMs](./runbooks/incusos/talos-incus-vm.md)**: Deploy a Talos Kubernetes cluster using VMs on IncusOS
- **[Bootstrapping Nodes](./runbooks/bootstrapping/README.md)**: Instructions for bootstrapping Talos clusters on Raspberry Pi and Intel NUC devices
- **[Home Assistant](./runbooks/home-assistant/README.md)**: Complete guide for deploying a home automation platform
- **[Ubuntu Setup](./runbooks/ubuntu/ubuntu-setup.md)**: Complete guide for installing and configuring Ubuntu on Intel NUC devices
- **[Self Hosted Runners](./runbooks/runners/ubuntu-runner-setup.md)**: Guides for setting up self-hosted runners on Ubuntu


## Taskfiles

[Taskfile](https://taskfile.dev) organizes and automates common operations through namespaced tasks (e.g., `dev:`, `talos:`, `docker:`) stored in the `./tasks` folder. Each namespace has its own `Taskfile.yaml` that groups related tasks together, making it easy to discover functionality and add new capabilities as needed.

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

Tasks are organized into namespaces using the `namespace:task` syntax (e.g., `task sops:decrypt -- <file>` or `task device:write-disk`). Use `task <namespace>:help` to view available tasks, `task help` to open documentation, or `task <namespace>:<task> --dry` to preview commands without executing.

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

Runbooks leverage taskfiles extensively, so you'll see commands like `task device:write-disk` throughout the documentation. These taskfile commands encapsulate complex operations, making the runbooks easier to follow while ensuring consistent, reliable execution.
