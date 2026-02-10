# Bootstrapping Nodes

Bootstrapping is the foundational step in deploying Kubernetes clusters on bare metal or edge devices. This process involves preparing your hardware, installing the operating system, and configuring the initial cluster state. The bootstrapping method you choose depends on your infrastructure requirements, scale, and operational preferences.

## What is Bootstrapping?

Bootstrapping transforms raw hardware into a functional Kubernetes node by:

- **Installing the operating system**: Flashing a minimal, Kubernetes-optimized OS image to your device
- **Initial configuration**: Setting up network, storage, and basic system settings
- **Cluster formation**: Establishing the initial cluster state and control plane
- **Node registration**: Preparing nodes to join and participate in the cluster

This is the critical first step that enables all subsequent deployment operations. A properly bootstrapped node provides the foundation for running containerized workloads, managing infrastructure, and deploying applications.

## Bootstrapping Methods

This section covers Talos bootstrapping for bare metal and edge devices:

### Talos Bootstrapping

**Best for**: Single-node clusters, small deployments, edge devices, and development environments

Device-specific bootstrapping guides:

- **[Intel NUC BIOS Update](./nuc-bios.md)**: Update the BIOS on Intel NUC devices before installing Ubuntu or Talos
- **[IncusOS Server](./nuc-incusos.md)**: Install and configure IncusOS on Intel NUC for container and VM management
- **[Ubuntu on Intel NUC](./nuc-ubuntu.md)**: Install Ubuntu on Intel NUC for development or general-purpose computing
- **[Raspberry Pi Bootstrapping](./rpi-talos.md)**: Step-by-step guide for bootstrapping Talos on Raspberry Pi (ARM64) devices
- **[Intel NUC Bootstrapping](./nuc-talos.md)**: Step-by-step guide for bootstrapping Talos on Intel NUC (x86_64) devices

Talos Linux is a minimal, immutable Linux distribution designed specifically for Kubernetes. The Talos bootstrapping process involves:

- Downloading and flashing the Talos image to your device
- Interactive configuration using `talosctl`
- Manual cluster formation for smaller deployments
- Direct control over each node's configuration

This method provides simplicity and direct control, making it ideal for learning, prototyping, and smaller-scale deployments where you want hands-on control over the bootstrapping process.

## Choosing the Right Method

Consider the following when selecting a bootstrapping approach:

| Factor | Talos Bootstrapping |
|--------|-------------------|
| **Scale** | Single to few nodes |
| **Automation** | Manual/interactive |
| **Complexity** | Lower |
| **Use Case** | Development, edge, small deployments |
| **Management** | Per-node configuration |
| **Learning Curve** | Easier to start |

## Prerequisites

Before bootstrapping, ensure you have:

- **Hardware**: Compatible device (Raspberry Pi, x86_64 server, ARM64 device, etc.)
- **Network**: Network connectivity for the device
- **Tools**: `talosctl` installed (see [Installation Guide](../../install.md))
- **Access**: Physical or remote access to the device
- **Storage**: SD card or disk for the device

## Next Steps

1. **Review the prerequisites**: Ensure you have all required tools and access
2. **Choose your method**: Select the appropriate Talos bootstrapping guide for your device
3. **Follow the guide**: Use the appropriate bootstrapping guide for step-by-step instructions
4. **Verify your cluster**: Once bootstrapped, verify your cluster is operational
5. **Proceed to deployment**: After bootstrapping, you can proceed with application deployments

## Getting Help

- **Documentation**: [Documentation Site](https://tvangundy.github.io)
- **Talos Documentation**: [Talos Linux Docs](https://www.talos.dev/)
- **Issues**: [GitHub Issues](https://github.com/tvangundy/workspace/issues)
- **Discussions**: [GitHub Discussions](https://github.com/tvangundy/workspace/discussions)
