# Local Development Container on macOS with Colima

This runbook guides you through creating and managing development containers locally on macOS using Colima. This setup provides real-time workspace sharing, making it ideal for development with direct IDE integration.

## Overview

Local development containers run on your macOS machine using Colima and provide:
- Real-time workspace sharing (changes sync instantly)
- Direct integration with your local IDE and tools
- Fast file access without network transfer
- Isolated, reproducible development environments
- Access via `incus exec` (similar to `docker exec`)

## Prerequisites

- macOS with Homebrew installed
- Workspace initialized (see [Initialize Workspace](../workspace/init.md))
- Windsor context initialized

## Setup

### Step 1: Install Colima and Incus

Install the required tools:

```bash
# Install Colima and Incus client
brew install colima incus
```

**Confirmation:**
```bash
# Verify Colima is installed
colima version

# Verify Incus is installed
incus version
```

### Step 2: Start Colima with Incus Runtime

Start Colima with the Incus runtime:

```bash
# Start Colima with Incus runtime
colima start --runtime=incus
```

This will:
- Create a Linux VM using Colima
- Install and configure Incus server inside the VM
- Set up the `local` remote automatically

**Confirmation:**
```bash
# Verify Colima is running
colima status

# Verify local remote is available
incus remote list

# Verify you can list instances
incus list local:
```

**Expected output:**
- `colima status` should show "Status: Running"
- `incus remote list` should show `local` remote
- `incus list local:` should work (may show empty list)

### Step 3: Configure Environment Variables

Add the following to your `contexts/<context>/windsor.yaml`:

```yaml
environment:
  # Use local Incus (required for workspace sharing)
  INCUS_REMOTE_NAME: local
  
  # Enable workspace sharing
  DEV_SHARE_WORKSPACE: true
  DEV_WORKSPACE_PATH: ""  # Optional: defaults to WINDSOR_PROJECT_ROOT
  
  # Default instance name (optional, defaults to dev-container)
  DEV_INSTANCE_NAME: dev-container
  
  # Default image (optional, defaults to ubuntu/22.04)
  DEV_IMAGE: ubuntu/22.04
  
  # Instance resources (optional)
  DEV_MEMORY: 4GB
  DEV_CPU: 2
```

**Confirmation:**
```bash
# Verify environment variables are set
windsor env | grep INCUS_REMOTE_NAME
windsor env | grep DEV_SHARE_WORKSPACE

# Expected output:
# INCUS_REMOTE_NAME=local
# DEV_SHARE_WORKSPACE=true
```

### Step 4: Create the Development Container

Create a container with workspace sharing:

```bash
task dev:create -- container ubuntu/22.04
```

This will:
- Create a container named `dev-container` (or the name in `DEV_INSTANCE_NAME`)
- Use Ubuntu 22.04 as the base image
- Mount your workspace directory at `/workspace` inside the container
- Configure the container with the specified resources

**Confirmation:**
```bash
# Verify instance was created
task dev:list

# Check instance status
task dev:info

# Verify workspace is mounted
task dev:exec -- ls -la /workspace

# Verify file changes sync (create a test file)
echo "test" > /tmp/test-local.txt
task dev:exec -- cp /tmp/test-local.txt /workspace/
# Check that the file appears in your local workspace directory
ls -la "${WINDSOR_PROJECT_ROOT}/test-local.txt"
```

### Step 5: Access the Container

You can access the container in two ways:

#### Option 1: Interactive Shell

Open an interactive bash shell in the container:

```bash
task dev:shell
```

This is equivalent to `docker exec -it <container> bash`. You'll get a shell prompt where you can run commands interactively.

#### Option 2: Execute Commands Directly

Run specific commands without entering an interactive shell:

```bash
task dev:exec -- ls -la /workspace
task dev:exec -- apt update && apt install -y git
```

Use this option when you want to run a single command or a series of commands without opening an interactive session.

## Workspace Sharing

The workspace is automatically mounted at `/workspace` inside the container. Changes made in either location are immediately visible in the other.

### Accessing the Workspace

```bash
# Open a shell in the container
task dev:shell

# Inside the container:
cd /workspace
ls -la
# Changes here are immediately visible on your host machine
```

### Verifying Workspace Sync

Test that workspace sharing is working:

```bash
# Create a file locally
echo "Hello from macOS" > "${WINDSOR_PROJECT_ROOT}/test-sync.txt"

# Verify it appears in the container
task dev:exec -- cat /workspace/test-sync.txt

# Create a file in the container
task dev:exec -- echo "Hello from container" > /workspace/test-container.txt

# Verify it appears locally
cat "${WINDSOR_PROJECT_ROOT}/test-container.txt"
```

Both files should be visible in both locations immediately.

## GitHub Operations

Since the workspace is shared, you can work with GitHub repositories directly from your local machine or from within the container.

### Install Git in Container

```bash
task dev:exec -- apt update
task dev:exec -- apt install -y git
```

### Clone Repository

You can clone repositories either locally or in the container:

**Option 1: Clone locally (recommended)**
```bash
# Clone to your local workspace
cd "${WINDSOR_PROJECT_ROOT}"
git clone https://github.com/user/repo.git project

# The repository is immediately available in the container
task dev:exec -- ls -la /workspace/project
```

**Option 2: Clone in container**
```bash
# Clone directly in the container
task dev:exec -- git clone https://github.com/user/repo.git /workspace/project

# The repository is immediately available locally
ls -la "${WINDSOR_PROJECT_ROOT}/project"
```

### Configure Git

Configure Git in the container (if working from within the container):

```bash
# Set up Git user (replace with your details)
task dev:exec -- git config --global user.name "Your Name"
task dev:exec -- git config --global user.email "your.email@example.com"
```

### Using SSH Keys for GitHub

Since the workspace is shared, you can use your local SSH keys:

1. **Your local SSH keys are accessible** - The workspace mount includes your home directory structure, so you can reference your local SSH keys:

```bash
# In the container, you can use your local SSH keys
task dev:exec -- git clone git@github.com:user/repo.git /workspace/project
```

However, for better integration, you may want to copy your SSH keys into the container:

```bash
# Copy your SSH key to the container
incus file push ~/.ssh/id_rsa local:dev-container/root/.ssh/id_rsa
task dev:exec -- chmod 600 /root/.ssh/id_rsa

# Copy your public key
incus file push ~/.ssh/id_rsa.pub local:dev-container/root/.ssh/id_rsa.pub
```

**Future Enhancement**: The taskfile will be enhanced to automatically copy SSH keys and configure the container user to match your local user.

### Working with Repositories

Since the workspace is shared, you can work with Git from either location:

**From your local machine:**
```bash
cd "${WINDSOR_PROJECT_ROOT}/project"
git status
git pull
git add .
git commit -m "Your commit message"
git push
```

**From within the container:**
```bash
task dev:shell
# Inside container:
cd /workspace/project
git status
git pull
git add .
git commit -m "Your commit message"
git push
```

Both approaches work seamlessly since they're working with the same files.

## Managing the Container

### List Containers

```bash
# List all dev containers
task dev:list
```

### Get Container Information

```bash
# Get detailed info about the container
task dev:info

# Or specify the container name
task dev:info -- my-dev-container
```

### Start/Stop Container

```bash
# Start the container
task dev:start

# Stop the container
task dev:stop

# Restart the container
task dev:restart
```

### Stop Colima

When you're done working, you can stop Colima to free up resources:

```bash
# Stop Colima (this stops all containers)
colima stop

# Start Colima again when needed
colima start --runtime=incus
```

### Delete Container

```bash
# Delete the container (destructive)
task dev:delete

# Or specify the container name
task dev:delete -- my-dev-container
```

## Confirmation Checklist

Use this checklist to verify your setup is working correctly:

- [ ] Colima is installed (`colima version` works)
- [ ] Incus is installed (`incus version` works)
- [ ] Colima is running (`colima status` shows "Running")
- [ ] Local remote is available (`incus remote list` shows `local`)
- [ ] Can list instances (`incus list local:` works)
- [ ] Environment variables are set correctly (`windsor env | grep INCUS_REMOTE_NAME` shows `local`)
- [ ] Container was created successfully (`task dev:list` shows your container)
- [ ] Container is running (`task dev:info` shows status as "Running")
- [ ] Workspace is mounted (`task dev:exec -- ls -la /workspace` shows files)
- [ ] Can access container shell (`task dev:shell` works)
- [ ] Can execute commands (`task dev:exec -- echo "test"` works)
- [ ] File changes sync from local to container (create file locally, verify in container)
- [ ] File changes sync from container to local (create file in container, verify locally)
- [ ] Git is installed (`task dev:exec -- git --version` works)
- [ ] Can clone repositories (both locally and in container work)

## Common Workflows

### Initial Setup

```bash
# 1. Install Colima and Incus
brew install colima incus

# 2. Start Colima
colima start --runtime=incus

# 3. Create container
task dev:create -- container ubuntu/22.04

# 4. Install development tools
task dev:exec -- apt update
task dev:exec -- apt install -y build-essential git curl

# 5. Verify workspace sharing
task dev:exec -- ls -la /workspace
```

### Daily Development

```bash
# 1. Start Colima (if stopped)
colima start --runtime=incus

# 2. Start container (if stopped)
task dev:start

# 3. Work in your local IDE - changes are immediately visible in container
# Or work in container - changes are immediately visible locally
task dev:shell

# 4. When done, stop container (optional)
task dev:stop

# 5. Stop Colima when completely done (optional)
colima stop
```

### Working with GitHub

```bash
# 1. Clone repository locally (or in container - both work)
cd "${WINDSOR_PROJECT_ROOT}"
git clone https://github.com/user/repo.git project

# 2. Work on files locally or in container
# Files are shared, so either location works

# 3. Commit and push (from either location)
cd "${WINDSOR_PROJECT_ROOT}/project"
git add .
git commit -m "Changes"
git push
```

## Troubleshooting

### Colima Won't Start

```bash
# Check Colima status
colima status

# Check Colima logs
colima logs

# Try restarting Colima
colima stop
colima start --runtime=incus
```

### Container Won't Start

```bash
# Check container status
task dev:info

# Check Incus logs
incus info local:dev-container

# Try starting manually
incus start local:dev-container
```

### Workspace Not Accessible

```bash
# Verify workspace is mounted
task dev:info

# Check mount point
task dev:exec -- ls -la /workspace

# Verify environment variables
windsor env | grep DEV_SHARE_WORKSPACE
windsor env | grep INCUS_REMOTE_NAME
```

### File Changes Not Syncing

```bash
# Verify workspace mount exists
task dev:exec -- mount | grep workspace

# Check file permissions
task dev:exec -- ls -la /workspace

# Verify you're working in the correct directory
echo "${WINDSOR_PROJECT_ROOT}"
task dev:exec -- pwd
```

### Permission Issues

```bash
# Check file permissions in container
task dev:exec -- ls -la /workspace

# Adjust permissions if needed
task dev:exec -- sudo chown -R $USER:$USER /workspace
```

## Future Enhancements

The following enhancements are planned for future versions:

- **SSH Access**: Direct SSH access to containers with user-specific configurations
- **Automatic User Setup**: Copy current user's SSH keys and configuration automatically
- **Git Credential Management**: Automatic setup of Git credentials and SSH keys
- **IDE Integration**: Better integration with popular IDEs for seamless development

## Additional Resources

- [Colima Documentation](https://github.com/abiosoft/colima)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Incus Exec Command](https://linuxcontainers.org/incus/docs/main/instances/#execute-commands)
- [Incus Disk Devices](https://linuxcontainers.org/incus/docs/main/storage/#disk-devices)

