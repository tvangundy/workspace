# Development Container with Incus

This runbook guides you through creating and managing development containers or virtual machines using Incus. These dev environments provide isolated, reproducible development environments that can be instantly started from your workspace.

## Overview

Development environments in Incus can be created as either:

- **Containers** (`dev-container`): Lightweight, fast startup, shared kernel with host
- **Virtual Machines** (`dev-vm`): Full isolation, own kernel, better for testing OS-level features

Both types can:
- Share your workspace directory as a mounted disk
- Be started/stopped instantly
- Provide persistent storage
- Be accessed via `incus exec` (similar to `docker exec`)

## Prerequisites

- Incus installed and configured (see [IncusOS Setup](../incusos/incusos-setup.md))
- Incus remote configured (see [IncusOS Setup - Step 8](../incusos/incusos-setup.md#step-8-connect-to-incus-server))
- Workspace initialized (see [Initialize Workspace](../workspace/init.md))
- Windsor context initialized

## Quick Start

### 1. Create a Development Container

```bash
# Create a dev-container using Ubuntu 22.04
task dev:create -- container ubuntu/22.04

# Or create a dev-vm (virtual machine)
task dev:create -- vm ubuntu/22.04
```

### 2. Start the Development Environment

```bash
# Start the instance (if not already running)
task dev:start

# Or specify the instance name
task dev:start -- my-dev-container
```

### 3. Access the Development Environment

```bash
# Open an interactive shell (like docker exec -it)
task dev:shell

# Or execute a specific command
task dev:exec -- ls -la

# Or specify the instance name
task dev:shell -- my-dev-container
```

### 4. Stop the Development Environment

```bash
# Stop the instance
task dev:stop

# Or specify the instance name
task dev:stop -- my-dev-container
```

## Detailed Setup

### Step 1: Configure Environment Variables

Add the following to your `contexts/<context>/windsor.yaml`:

```yaml
environment:
  # Incus remote name (the name you used when adding the remote)
  INCUS_REMOTE_NAME: nuc
  
  # Default instance name (optional, defaults to dev-container or dev-vm)
  DEV_INSTANCE_NAME: dev-container
  
  # Default image (optional, defaults to ubuntu/22.04)
  DEV_IMAGE: ubuntu/22.04
  
  # Instance resources (optional)
  DEV_MEMORY: 4GB
  DEV_CPU: 2
  DEV_DISK: 20GB
```

### Step 2: Create a Development Instance

#### Create a Container

Containers are lightweight and start quickly:

```bash
task dev:create -- container ubuntu/22.04
```

This will:
- Create a container named `dev-container` (or the name in `DEV_INSTANCE_NAME`)
- Use Ubuntu 22.04 as the base image
- Mount your workspace directory at `/workspace` inside the container
- Configure the container with the specified resources

#### Create a Virtual Machine

VMs provide full isolation:

```bash
task dev:create -- vm ubuntu/22.04
```

This will:
- Create a VM named `dev-vm` (or the name in `DEV_INSTANCE_NAME`)
- Use Ubuntu 22.04 as the base image
- Mount your workspace directory as a disk device
- Configure the VM with the specified resources

### Step 3: Access the Instance

#### Interactive Shell

Open a bash shell in the instance:

```bash
task dev:shell
```

This is equivalent to `docker exec -it <container> bash`.

#### Execute Commands

Run a specific command:

```bash
task dev:exec -- ls -la /workspace
task dev:exec -- apt update && apt install -y git
```

#### Login (SSH-style)

For VMs, you can also set up SSH access:

```bash
# First, get the VM's IP address
task dev:info

# Then SSH into it (if SSH is configured)
ssh ubuntu@<vm-ip>
```

### Step 4: Manage the Instance

#### List Instances

```bash
# List all dev instances
task dev:list
```

#### Get Instance Information

```bash
# Get detailed info about the instance
task dev:info

# Or specify the instance name
task dev:info -- my-dev-container
```

#### Start/Stop Instance

```bash
# Start the instance
task dev:start

# Stop the instance
task dev:stop

# Restart the instance
task dev:restart
```

#### Delete Instance

```bash
# Delete the instance (destructive)
task dev:delete

# Or specify the instance name
task dev:delete -- my-dev-container
```

## Workspace Sharing

The dev tasks automatically mount your workspace directory into the instance:

- **Containers**: Workspace is mounted at `/workspace` using a disk device
- **VMs**: Workspace is mounted as a disk device that you can mount inside the VM

### Accessing the Workspace in Containers

The workspace is automatically available at `/workspace`:

```bash
task dev:shell
# Inside the container:
cd /workspace
ls -la
```

### Accessing the Workspace in VMs

For VMs, you may need to mount the disk device:

```bash
task dev:shell
# Inside the VM:
# The disk device is available, you may need to mount it
sudo mkdir -p /workspace
sudo mount /dev/sdb1 /workspace  # Adjust device name as needed
```

## Common Use Cases

### Development Environment Setup

```bash
# Create a dev container
task dev:create -- container ubuntu/22.04

# Install development tools
task dev:exec -- apt update
task dev:exec -- apt install -y build-essential git curl

# Clone your project
task dev:exec -- git clone https://github.com/user/repo.git /workspace/project

# Work in the container
task dev:shell
```

### Testing Different OS Versions

```bash
# Create containers with different OS versions
task dev:create -- container ubuntu/20.04 --name ubuntu20
task dev:create -- container ubuntu/22.04 --name ubuntu22
task dev:create -- container debian/11 --name debian11

# Test your code in each
task dev:exec --name ubuntu20 -- python3 test.py
task dev:exec --name ubuntu22 -- python3 test.py
task dev:exec --name debian11 -- python3 test.py
```

### Isolated Build Environment

```bash
# Create a clean build environment
task dev:create -- container ubuntu/22.04 --name build-env

# Install build dependencies
task dev:exec --name build-env -- apt update
task dev:exec --name build-env -- apt install -y build-essential cmake

# Build your project
task dev:exec --name build-env -- cd /workspace && make
```

## Advanced Configuration

### Custom Instance Names

```bash
# Create with a custom name
task dev:create -- container ubuntu/22.04 --name my-custom-name

# Use the custom name in other commands
task dev:start -- my-custom-name
task dev:shell -- my-custom-name
```

### Resource Limits

Override default resources when creating:

```bash
# Create with custom resources
DEV_MEMORY=8GB DEV_CPU=4 task dev:create -- container ubuntu/22.04
```

### Network Configuration

By default, instances get an IP from the Incus network. For VMs, you can configure network access:

```bash
# Get the instance's IP address
task dev:info

# The IP will be shown in the output
```

### Persistent Storage

The workspace mount is persistent. Any changes to files in `/workspace` are reflected in your host workspace directory.

## Troubleshooting

### Instance Won't Start

```bash
# Check instance status
task dev:info

# Check Incus logs
incus info <remote-name>:<instance-name>

# Try starting manually
incus start <remote-name>:<instance-name>
```

### Workspace Not Accessible

For containers, the workspace should be automatically mounted. If not:

```bash
# Check if disk device is attached
task dev:info

# Verify the mount point
task dev:exec -- ls -la /workspace
```

### Permission Issues

If you encounter permission issues with the workspace mount:

```bash
# Check file permissions
task dev:exec -- ls -la /workspace

# Adjust permissions if needed (inside the container)
task dev:exec -- sudo chown -R $USER:$USER /workspace
```

### Instance Already Exists

If you try to create an instance that already exists:

```bash
# Delete the existing instance first
task dev:delete -- <instance-name>

# Then create a new one
task dev:create -- container ubuntu/22.04 --name <instance-name>
```

## Comparison: Container vs VM

| Feature | Container | VM |
|---------|-----------|-----|
| Startup Time | Instant (~1 second) | Slower (~10-30 seconds) |
| Resource Usage | Lower | Higher |
| Isolation | Process-level | Full OS-level |
| Kernel | Shared with host | Own kernel |
| Use Case | Development, testing | OS-level testing, full isolation |

## Best Practices

1. **Use containers for development**: Faster startup, lower resource usage
2. **Use VMs for OS testing**: When you need to test OS-level features
3. **Clean up regularly**: Delete instances you're no longer using
4. **Use descriptive names**: When creating multiple instances, use descriptive names
5. **Mount workspace**: Always use the workspace mount to keep your code in sync

## Next Steps

After setting up your dev environment:

1. **Install your tools**: Set up your development environment inside the instance
2. **Configure your shell**: Customize your shell configuration
3. **Set up SSH** (for VMs): Configure SSH access for easier connection
4. **Create snapshots**: Use `incus snapshot` to save your environment state
5. **Automate setup**: Create scripts to automate your development environment setup

## Additional Resources

- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Incus Exec Command](https://linuxcontainers.org/incus/docs/main/instances/#execute-commands)
- [Incus Disk Devices](https://linuxcontainers.org/incus/docs/main/storage/#disk-devices)

