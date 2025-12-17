# Workspace

A collection of practical implementations, automation solutions, and infrastructure projects. This workspace provides both **runbooks** (step-by-step guides to build your own) and **working examples** (reference implementations you can compare against) for infrastructure deployments.

## What You'll Find Here

- **Runbooks**: Step-by-step guides that walk you through building complete deployments from the ground up
- **Working Examples**: Production-ready implementations that serve as reference code and are used for regression testing
- Real-world implementation examples
- Infrastructure automation solutions
- Security and networking configurations
- Reference architectures and patterns

## Getting Started

1. Review the [Installation Guide](./docs/install.md) to set up your environment
2. **Choose your approach**:
   - **Learn by building**: Follow a [runbook](./docs/runbooks/README.md) to build your own deployment step-by-step
   - **Use as reference**: Explore the [examples](./docs/examples/index.md) folder to find working implementations you can adapt
3. **Compare and verify**: If you followed a runbook, compare your implementation with the corresponding example to verify it matches the reference

## Using Taskfile

This workspace uses [Taskfile](https://taskfile.dev) to organize and run common commands. Tasks are organized into namespaces and placed in the `./tasks` folder, making it easy to discover and execute common operations.

### Namespace Syntax

Tasks are organized into namespaces using the `namespace:task` syntax. For example:

```bash
# Run a task from the sops namespace
task sops:decrypt -- <file>

# Run a task from the device namespace
task device:list-disks

# Run a task from the docker namespace
task docker:clean
```

### Viewing Available Tasks

To see available tasks in a namespace, use the `help` command:

```bash
task <namespace>:help
```

For example:
```bash
task sops:help
task device:help
```

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
└── talos/         # Talos cluster tasks
```

This pattern keeps related tasks grouped together and makes it easy to add new namespaces as needed.

## Examples vs. Runbooks

This workspace provides two complementary resources:

- **Runbooks** (`/docs/runbooks/`): Instructional guides that teach you **how** to build deployments. Follow these step-by-step to understand each part of the process and create your own implementation.

- **Examples** (`/examples/`): Working, production-ready deployments that serve as reference implementations. Use these to **compare** your implementation against a tested, working solution. The examples are also used for regression testing to ensure patterns remain functional.

By following a runbook, you'll build your own deployment step-by-step. You can then compare your implementation with the corresponding example to verify it matches the reference implementation and understand any differences.


## How to use the examples

Each example directory contains a Taskfile.yml and a README.md. To get started, read the README.md for specific instructions and run the 'task' command to execute predefined tasks.

### File Structure for each example

```
examples/
└── < example-name >/      # Example directory
    ├── Taskfile.yml       # Task definitions for the example
    ├── README.md          # Example-specific documentation
    └── ...                # Additional example files
```

### Required Components

#### 1. Taskfile.yml
   - Define common tasks (setup, run, test, clean)
   - Include clear task descriptions
   - Use consistent task naming across examples

#### 2. README.md
   - Overview of the example
   - Prerequisites and requirements
   - Quick start guide
   - Links to detailed documentation

#### 3. Documentation
   - Create a markdown file in `docs/examples/`
   - Include detailed setup instructions
   - Document configuration options
   - Provide troubleshooting guidance

## Repository Structure

```
├── docs/                 # Documentation
│   ├── runbooks/         # Runbook guides
│   │   ├── bootstrapping/  # Node bootstrapping guides
│   │   ├── home-assistant/ # Home Assistant deployment guide
│   │   ├── runners/        # GitHub Actions runner setup guides
│   │   └── README.md       # Runbooks overview
│   ├── examples/         # Example documentation
│   │   ├── aws-web-cluster.md
│   │   ├── ethereum.md
│   │   ├── home-assistant.md
│   │   ├── hybrid-cloud.md
│   │   ├── index.md
│   │   ├── sidero-omni.md
│   │   ├── tailscale.md
│   │   └── wireguard.md
│   └── install.md        # Installation guide
├── examples/             # Working reference implementations
│   ├── aws-web-cluster/
│   ├── ethereum/
│   ├── home-assistant/
│   ├── hybrid-cloud/
│   ├── sidero-omni/
│   ├── tailscale/
│   └── wireguard/
├── tasks/               # Namespaced task definitions
│   ├── sops/            # SOPS encryption/decryption tasks
│   ├── device/          # Device management tasks
│   ├── docker/          # Docker-related tasks
│   ├── vhs/             # VHS terminal recording tasks
│   └── talos/           # Talos cluster tasks
├── mkdocs.yml           # MkDocs configuration
├── overrides/           # MkDocs theme customizations
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

- Documentation: [Documentation Site](https://tvangundy.github.io)
- Issues: [GitHub Issues](https://github.com/tvangundy/workspace/issues)
- Discussions: [GitHub Discussions](https://github.com/tvangundy/workspace/discussions)

## Acknowledgments

- Contributors
- Open source projects used in examples
