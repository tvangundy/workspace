# Project Examples

A collection of practical implementations, automation solutions, and infrastructure projects. This workspace provides examples and real-world implementations that can be used as a reference for your own projects.

## What You'll Find Here

- Real-world implementation examples
- Infrastructure automation solutions
- Security and networking configurations
- Reference architectures and patterns

## Getting Started

1. Review the [Installation Guide](./docs/install) to set up your environment
2. Explore the 'examples' folder to find an implementation that interests you
3. Follow the example-specific instructions in its README.md

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
├── examples/             # Implementation examples
│   ├── aws-web-cluster/
│   ├── ethereum/
│   ├── home-assistant/
│   ├── hybrid-cloud/
│   ├── sidero-omni/
│   ├── tailscale/
│   └── wireguard/
├── mkdocs.yml           # MkDocs configuration
├── overrides/           # MkDocs theme customizations
└── Taskfile.yml         # Task definitions
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
