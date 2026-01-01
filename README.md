# Workspace

A collection of practical implementations, automation solutions, and infrastructure projects. This workspace provides **runbooks** (step-by-step guides to build your own deployments) for infrastructure deployments.

> 📚 **For complete documentation**, including detailed guides on runbooks, taskfiles, and how they work together, see the [full documentation site](https://tvangundy.github.io) or the [documentation index](./docs/index.md).

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

For a comprehensive overview of how runbooks and taskfiles work together, see the [full documentation](./docs/index.md).

## Runbooks

This workspace provides comprehensive runbooks that guide you through building infrastructure deployments step-by-step:

- **Runbooks** (`/docs/runbooks/`): Instructional guides that teach you **how** to build deployments. Follow these step-by-step to understand each part of the process and create your own implementation.

Each runbook provides detailed instructions from initial setup through final deployment, making them ideal for:
- **New users** learning to build infrastructure from scratch
- **Developers** who want to understand the implementation details
- **Teams** adapting these patterns to their own environments
- **Anyone** who prefers a guided, step-by-step approach

Runbooks in this workspace leverage taskfiles extensively, so you'll see commands like `task device:write-disk` throughout the documentation. These taskfile commands encapsulate complex operations, making the runbooks easier to follow while ensuring consistent, reliable execution. 

For more details on how runbooks and taskfiles work together, including available runbooks and taskfiles, see the [Runbooks and Taskfiles sections](./docs/index.md#runbooks) in the [full documentation](./docs/index.md).

## Using Taskfile

This workspace uses [Taskfile](https://taskfile.dev) to organize and run common commands. **Taskfiles are the execution engine behind all runbooks** - every step in a runbook that requires action is performed through a taskfile command. When you follow a runbook, you'll execute commands like `task device:write-disk`, `task runner:initialize`, or `task incus:launch-vm` to complete each step.

This design means runbooks focus on explaining **what** to do and **why**, while taskfiles handle the **how** - encapsulating complex operations, platform-specific commands, error handling, and validation into simple, repeatable commands. This separation makes runbooks easier to follow while ensuring consistent, reliable execution across different environments.

For detailed information about using taskfiles, including namespace syntax, viewing available tasks, and available taskfile namespaces, see the [Taskfiles section](./docs/index.md#taskfiles) in the [full documentation](./docs/index.md).

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
