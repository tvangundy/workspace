# Workspace

Build, deploy, and manage infrastructure with **repeatable, maintainable workflows** that you can save, share, and resume anytime. The main strength of this approach is standardizing on the [Windsor CLI](https://github.com/windsorcli/cli) flow, which provides consistent context management, secure secret handling, and unified configuration across all your infrastructure work. This workspace provides comprehensive **runbooks** and **taskfiles** that transform complex infrastructure operations into simple, executable steps—whether you're deploying to the cloud or bare-metal.

## What You'll Find Here

- **📚 Runbooks**: Step-by-step guides that walk you through building complete deployments from the ground up
- **⚡ Taskfiles**: Automated commands that handle complexity while maintaining full transparency
- **🔒 Security-first approach**: Built-in secret management and secure configuration practices
- **🔄 Real-world patterns**: Production-tested implementations you can adapt immediately
- **🛠️ Multi-tool support**: Native integration with Terraform, Kubernetes, Incus, Docker, and more


## 🚀 Ready to Get Started?

**Start here:** Read the [complete documentation](./docs/index.md) to understand how runbooks and taskfiles work together, explore available runbooks and taskfiles, and learn how to adopt this workspace for your infrastructure needs.

👉 **[Open Documentation →](./docs/index.md)** | [View Online](https://tvangundy.github.io)


## Runbooks

**Runbooks** (`/docs/runbooks/`) are comprehensive, step-by-step instructional guides that teach you how to build infrastructure deployments from the ground up. Each runbook leverages taskfiles extensively—you'll see commands like `task device:write-talos-disk` throughout the documentation—which encapsulate complex operations, making the guides easier to follow while ensuring consistent, reliable execution. 

Follow these guides step-by-step to understand each part of the process and create your own implementation.

Each runbook provides detailed instructions from initial setup through final deployment, making them ideal for:
- **New users** learning to build infrastructure from scratch
- **Developers** who want to understand the implementation details
- **Teams** adapting these patterns to their own environments
- **Anyone** who prefers a guided, step-by-step approach

For more details on how runbooks and taskfiles work together, see the [Runbooks and Taskfiles sections](./docs/index.md#runbooks) in the [full documentation](./docs/index.md).

## Taskfiles

This workspace uses [Taskfile](https://taskfile.dev) to organize and run common commands. **Taskfiles are the execution engine behind all runbooks** - every step in a runbook that requires action is performed through a taskfile command. When you follow a runbook, you'll execute commands like `task device:write-talos-disk`, `task runner:initialize`, or `task incus:launch-vm` to complete each step.

This design means runbooks focus on explaining **what** to do and **why**, while taskfiles handle the **how** - encapsulating complex operations, platform-specific commands, error handling, and validation into simple, repeatable commands. The details aren't lost: every taskfile command can be run with the `--dry` flag to reveal the detailed subcommands that will be executed, providing full transparency into what's happening under the hood. This separation makes runbooks easier to follow while ensuring consistent, reliable execution across different environments.

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

## Acknowledgments

- Contributors
- Open source projects used in implementations
