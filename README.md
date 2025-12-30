# Workspace

A collection of practical implementations, automation solutions, and infrastructure projects. This workspace provides **runbooks** (step-by-step guides to build your own deployments) for infrastructure deployments.

## What You'll Find Here

- **Runbooks**: Step-by-step guides that walk you through building complete deployments from the ground up
- Real-world implementation patterns
- Infrastructure automation solutions
- Security and networking configurations
- Reference architectures and patterns

## Getting Started

1. Review the [Installation Guide](./docs/install.md) to set up your environment
2. **Follow a runbook**: Choose a [runbook](./docs/runbooks/README.md) that matches your needs and follow it step-by-step to build your deployment
3. **Customize as needed**: Once you understand the pattern, adapt it to your specific requirements

## Using Taskfile

This workspace uses [Taskfile](https://taskfile.dev) to organize and run common commands. Tasks are organized into namespaces and placed in the `./tasks` folder, making it easy to discover and execute common operations.

### Namespace Syntax

Tasks are organized into namespaces using the `namespace:task` syntax. For example:

```bash
# Run a task from the sops namespace
task sops:decrypt -- <file>

# Run a task from the device namespace
task device:list-disks

```

### Viewing Available Tasks

To see available tasks in a namespace, use the `help` command:

```bash
task <namespace>:help
```

For example:
```bash
task workspace:help
task sops:help
task device:help
```

### Quick Access to Documentation

Run `task help` to open the documentation site in your browser:

```bash
task help
```

This will automatically open https://tvangundy.github.io in your default browser, providing quick access to all documentation and runbooks.

### Dry Run Mode

To see what command would be executed without actually running it, use the `--dry` flag:

```bash
task <namespace>:<task> --dry
```

This is particularly useful for understanding what a task does before executing it, or for debugging task definitions.

### Task Organization

Tasks are organized into namespaces and stored in the `./tasks` folder. Each namespace has its own `Taskfile.yaml`:

```
tasks/
├── sops/          # SOPS encryption/decryption tasks
├── device/        # Device management tasks
├── docker/        # Docker-related tasks
├── vhs/           # VHS terminal recording tasks
├── talos/         # Talos cluster tasks
└── incus/         # Incus tasks
```

This pattern keeps related tasks grouped together and makes it easy to add new namespaces as needed.

## Runbooks

This workspace provides comprehensive runbooks that guide you through building infrastructure deployments step-by-step:

- **Runbooks** (`/docs/runbooks/`): Instructional guides that teach you **how** to build deployments. Follow these step-by-step to understand each part of the process and create your own implementation.

Each runbook provides detailed instructions from initial setup through final deployment, making them ideal for:
- **New users** learning to build infrastructure from scratch
- **Developers** who want to understand the implementation details
- **Teams** adapting these patterns to their own environments
- **Anyone** who prefers a guided, step-by-step approach

Runbooks in this workspace leverage taskfiles extensively, so you'll see commands like `task device:write-disk` throughout the documentation. These taskfile commands encapsulate complex operations, making the runbooks easier to follow while ensuring consistent, reliable execution. For more details on how runbooks and taskfiles work together, see the [Runbooks section](https://tvangundy.github.io/#runbooks) in the documentation.

## Repository Structure

```
├── docs/                 # Documentation
│   ├── runbooks/         # Runbook guides
│   │   ├── bootstrapping/  # Node bootstrapping guides
│   │   ├── home-assistant/ # Home Assistant deployment guide
│   │   ├── incus/          # Incus setup guide
│   │   ├── runners/        # GitHub Actions runner setup guides
│   │   ├── secrets/        # Secrets management guide
│   │   └── workspace/      # Workspace initialization guide
│   └── install.md        # Installation guide
├── tasks/               # Namespaced task definitions
│   ├── sops/            # SOPS encryption/decryption tasks
│   ├── device/          # Device management tasks
│   ├── docker/          # Docker-related tasks
│   ├── vhs/             # VHS terminal recording tasks
│   ├── talos/           # Talos cluster tasks
│   └── incus/           # Incus tasks
├── contexts/            # Windsor context configurations
└── Taskfile.yml         # Main task definitions with namespace includes
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

Please ensure your contributions:
- Follow the existing code style
- Include appropriate tests
- Update documentation as needed
- Provide clear commit messages

## Versioning

This repository follows [Semantic Versioning](https://semver.org/). See the [releases page](https://github.com/tvangundy/workspace/releases) for version history.

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file included in the root of this repository.

## Getting Help

- **Quick access**: Run `task help` to open the documentation site in your browser
- Documentation: [Documentation Site](https://tvangundy.github.io)
- Issues: [GitHub Issues](https://github.com/tvangundy/workspace/issues)
- Discussions: [GitHub Discussions](https://github.com/tvangundy/workspace/discussions)

## Acknowledgments

- Contributors
- Open source projects used in implementations
