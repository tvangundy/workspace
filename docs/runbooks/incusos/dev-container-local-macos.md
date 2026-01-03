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

### Step 1: Install Tools Dependencies

To fully leverage the Windsor environment and manage your local development container, you will need several tools installed on your system. You may install these tools manually or using your preferred tools manager (_e.g._ Homebrew). The Windsor project recommends [aqua](https://aquaproj.github.io/). For your convenience, we have provided a sample setup file for aqua. Place this file in the root of your project.

Create an `aqua.yaml` file in your project's root directory with the following content:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/aquaproj/aqua/main/json-schema/aqua-yaml.json
# aqua - Declarative CLI Version Manager
# https://aquaproj.github.io/
# checksum:
#   enabled: true
#   require_checksum: true
#   supported_envs:
#   - all
registries:
  - type: standard
    ref: v4.285.0
packages:
- name: hashicorp/terraform@v1.10.3
- name: siderolabs/talos@v1.9.1
- name: kubernetes/kubectl@v1.32.0
- name: docker/cli@v27.4.1
- name: docker/compose@v2.32.1
- name: lxc/incus@v6.20.0
- name: helm/helm@v3.17.3
- name: fluxcd/flux2@v2.5.1
- name: derailed/k9s@v0.50.3
- name: abiosoft/colima@v0.8.1
```

To install the tools specified in `aqua.yaml`, run:

```bash
aqua install
```

**Alternative Installation (Homebrew):**

If you prefer to use Homebrew directly:

```bash
# Install Colima and Incus client
brew install colima incus
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
  
  # Enable workspace sharing (required for local)
  DEV_SHARE_WORKSPACE: true
  
  # Workspace initialization (optional)
  DEV_INIT_WORKSPACE: true  # Set to true to initialize workspace on creation
  
  # Default container name (optional, defaults to dev)
  DEV_INSTANCE_NAME: dev
  DEV_INSTANCE_TYPE: container  # Use container for local development
  
  # Default image (optional, defaults to ubuntu/22.04)
  DEV_IMAGE: ubuntu/22.04
  
  # Container resources (optional)
  DEV_MEMORY: 4GB
  DEV_CPU: 2
  
  # Use system Docker socket from Colima
  DOCKER_HOST: unix://${HOME}/.colima/default/docker.sock
```

**Important Notes:**

- `INCUS_REMOTE_NAME: local` - Uses the local Colima Incus server
- `DEV_SHARE_WORKSPACE: true` - Enables real-time workspace sharing (required for local)
- `DEV_INSTANCE_TYPE: container` - Use containers for local development (faster than VMs)
- `DOCKER_HOST` - Points to Colima's Docker socket for Docker operations

### Step 4: Configure Talos Machine Settings (If Setting Up a Talos Kubernetes Cluster)

**Note**: This step is only needed if you plan to set up a Talos Kubernetes cluster in your dev container. If you're just creating a regular Ubuntu development container, skip this step and proceed to Step 5.

#### Create Terraform Configuration File

**Note**: If this file doesn't exist, you may need to:
1. Ensure your `blueprint.yaml` includes the Talos Terraform module:
   ```yaml
   terraform:
   - source: core
     path: cluster/talos
   ```

#### Add Kernel Module Configuration

Create this file: `contexts/<context>/terraform/cluster/talos/terraform.tfvars`

Add the `br_netfilter` kernel module configuration to the `common_config_patches` field. 

This is required for Flannel CNI to work properly:

```hcl
// A YAML string of common config patches to apply. Can be an empty string or valid YAML.
common_config_patches = <<EOF
"machine":
  "kernel":
    "modules":
    - "name": "br_netfilter"
  "sysctls":
    "net.bridge.bridge-nf-call-iptables": "1"
    "net.bridge.bridge-nf-call-ip6tables": "1"
EOF
```

**Note**: If you already have a `common_config_patches` section, merge the `kernel` and `sysctls` settings into your existing `machine` configuration. For example:

```hcl
common_config_patches = <<EOF
"machine":
  "certSANs":
  - "localhost"
  - "127.0.0.1"
  "kubelet":
    "extraArgs":
      "rotate-server-certificates": "true"
  "kernel":
    "modules":
    - "name": "br_netfilter"
  "sysctls":
    "net.bridge.bridge-nf-call-iptables": "1"
    "net.bridge.bridge-nf-call-ip6tables": "1"
EOF
```

**Important**: This configuration must be in place before creating the container. The kernel module configuration will take effect when you generate and apply Talos machine configurations.

If you're not using Terraform/Windsor CLI and generating Talos configs directly, you'll need to patch the generated YAML files manually or use `talosctl` patch commands.

### Step 5: Verify Local Connection

Before creating a container, verify you can connect to the local Incus server:

```bash
# List configured remotes
incus remote list

# Verify you can connect to local
incus list local:

# Verify environment variables are set
windsor env | grep INCUS_REMOTE_NAME
```

**Expected output:**

- Your remote should appear in `incus remote list` with name `local`
- `incus list local:` should show existing instances (may be empty)
- `INCUS_REMOTE_NAME` should be set to `local`

### Step 6: Create the Development Container

Create a container on your local Colima instance:

```bash
task dev:create
```

**Why Containers for Local Development?**

- **Fast startup** - Containers start in seconds
- **Real-time workspace sharing** - Changes sync instantly between host and container
- **Lower resource usage** - More efficient than VMs for local development
- **Direct IDE integration** - Your IDE can directly access files in the container
- **Seamless workflow** - Edit files locally, run commands in container

The container will:

- Create a container named `dev` (or the name in `DEV_INSTANCE_NAME`)
- Use Ubuntu 22.04 as the base image
- **Share your workspace directory** in real-time (if `DEV_SHARE_WORKSPACE=true`)
- Optionally initialize with workspace contents if `DEV_INIT_WORKSPACE=true`
- **Automatically install developer tools** (git, build-essential, curl, vim, etc.)
- **Create a user matching your host username** with the same UID/GID
- **Copy your SSH keys** for immediate GitHub access
- **Configure Git** with your existing settings
- **Set up access** for direct command execution

**Confirmation:**
```bash
# Verify container was created
task dev:list

# Check container status
task dev:info

# Verify workspace is accessible (workspace is shared in real-time)
task dev:exec -- ls -la ${WINDSOR_PROJECT_ROOT}

# Verify developer tools are installed
task dev:exec -- git --version
task dev:exec -- curl --version

# Verify user was created (should match your host username)
task dev:exec -- whoami
```

### Step 7: Access the Development Container

You can access the container in several ways:

#### Option 1: Interactive Shell

Open an interactive bash shell in the container:

```bash
task dev:shell
```

This is equivalent to `incus exec <container> -- bash`. You'll get a shell prompt where you can run commands interactively.

#### Option 2: Execute Commands Directly

Run specific commands without entering an interactive shell:

```bash
# Workspace is shared in real-time
task dev:exec -- ls -la ${WINDSOR_PROJECT_ROOT}
task dev:exec -- apt update && apt install -y git
```

Use this option when you want to run a single command or a series of commands without opening an interactive session.

#### Option 3: Direct File Access

Since the workspace is shared, you can edit files directly from your macOS host using your IDE:

- Files are automatically synced between host and container
- Changes made on host are immediately visible in container
- Changes made in container are immediately visible on host

**Benefits of Local Container Access:**

- **Works immediately** - Container is ready right after creation
- **Real-time file sync** - No need to push/pull files
- **Native IDE integration** - Edit files locally, run in container
- **Fast development cycle** - Instant feedback
- **Full shell integration** - All tools available

## Developer Environment Setup

The container is automatically initialized with:

### Installed Tools

- **Git** - Version control
- **Build tools** - build-essential, gcc, make, etc.
- **Network tools** - curl, wget
- **Editors** - vim, nano
- **SSH client/server** - For GitHub access
- **System tools** - sudo, ca-certificates, gnupg

### User Configuration

- **Matching user account** - Created with the same username, UID, and GID as your host
- **SSH keys** - Your `~/.ssh/id_rsa` and `id_rsa.pub` are copied
- **SSH config** - Your `~/.ssh/config` is copied (if it exists)
- **Git configuration** - Your global Git user.name and user.email are configured
- **Sudo access** - Passwordless sudo is configured

### Workspace Setup

- **Workspace directory** - Shared in real-time between host and container
- **Ownership** - Owned by your user account
- **Ready for development** - Can immediately clone repos, run tasks, etc.

## Real-Time Workspace Sharing

One of the key benefits of local containers is real-time workspace sharing:

### How It Works

- Your workspace directory is mounted directly into the container
- Changes made on your macOS host are immediately visible in the container
- Changes made in the container are immediately visible on your host
- No manual file transfer needed

### Editing Files

You can edit files using your favorite macOS IDE (VS Code, Cursor, etc.):

```bash
# Edit files locally using your IDE
code ${WINDSOR_PROJECT_ROOT}/src/main.py

# Changes are immediately visible in container
task dev:exec -- cat ${WINDSOR_PROJECT_ROOT}/src/main.py
```

### Running Commands

Run commands in the container while editing files locally:

```bash
# While editing locally, run commands in container
task dev:exec -- python ${WINDSOR_PROJECT_ROOT}/src/main.py
task dev:exec -- npm test
task dev:exec -- go build
```

## GitHub Operations

Git and SSH keys are automatically configured during container creation, so you can immediately work with GitHub repositories.

### Verify Git Setup

```bash
# Check Git is installed and configured
task dev:exec -- git --version
task dev:exec -- git config --global user.name
task dev:exec -- git config --global user.email
```

### Clone Repository

You can clone repositories immediately using SSH (your keys are already set up):

```bash
# Clone a public repository
task dev:exec -- git clone https://github.com/user/repo.git ${WINDSOR_PROJECT_ROOT}/project

# Clone a private repository (SSH keys are already configured)
task dev:exec -- git clone git@github.com:user/repo.git ${WINDSOR_PROJECT_ROOT}/project
```

### Test GitHub Connection

Verify your SSH keys work with GitHub:

```bash
# Test GitHub SSH connection
task dev:exec -- ssh -T git@github.com
```

You should see: `Hi <username>! You've successfully authenticated...`

### Working with Repositories

Since the workspace is shared, you can work with Git from both host and container:

**From macOS host:**
```bash
cd ${WINDSOR_PROJECT_ROOT}/project
git status
git pull
# Edit files in your IDE
git add .
git commit -m "Changes"
git push
```

**From container:**
```bash
task dev:exec -- bash -c "cd ${WINDSOR_PROJECT_ROOT}/project && git status"
task dev:exec -- bash -c "cd ${WINDSOR_PROJECT_ROOT}/project && git pull"
```

Both approaches work seamlessly since the workspace is shared!

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
task dev:info -- my-dev
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

### Delete Container

To completely remove the development container:

```bash
# Delete the container (destructive, includes 5-second confirmation delay)
task dev:delete

# Or specify the container name
task dev:delete -- my-dev
```

**What Gets Deleted:**

- The container instance and all its data
- All files installed inside the container
- Container-specific configuration

**Note**: Files in your shared workspace directory on the host are **not** deleted - only container-specific data is removed.

**Warning**: Deleting the container is **irreversible** for container-specific data. Your workspace files on the host remain safe.

## Managing Colima

### Start Colima

```bash
# Start Colima with Incus runtime
colima start --runtime=incus
```

### Stop Colima

```bash
# Stop Colima (will stop all containers)
colima stop
```

### Check Colima Status

```bash
# Check if Colima is running
colima status
```

### Restart Colima

```bash
# Restart Colima
colima restart
```

### Configure Colima Resources

You can customize Colima's resource allocation:

```bash
# Stop Colima first
colima stop

# Start with custom resources
colima start --runtime=incus --cpu 4 --memory 8
```

## Confirmation Checklist

Use this checklist to verify your setup is working correctly:

- [ ] Colima is running (`colima status` shows "Running")
- [ ] Local Incus remote is available (`incus remote list` shows `local`)
- [ ] Environment variables are set correctly (`windsor env | grep INCUS_REMOTE_NAME`)
- [ ] Container was created successfully (`task dev:list` shows your container)
- [ ] Container is running (`task dev:info` shows status as "Running")
- [ ] Workspace is accessible (`task dev:exec -- ls -la ${WINDSOR_PROJECT_ROOT}` shows files)
- [ ] Can access container shell (`task dev:shell` works)
- [ ] Can execute commands (`task dev:exec -- echo "test"` works)
- [ ] Workspace files are synced (edit on host, see in container)
- [ ] Git is installed (`task dev:exec -- git --version` works)
- [ ] Git is configured (`task dev:exec -- git config --global user.name` shows your name)
- [ ] SSH keys are set up (`task dev:exec -- ssh -T git@github.com` works)
- [ ] Can clone repositories (`task dev:exec -- git clone git@github.com:user/repo.git ${WINDSOR_PROJECT_ROOT}/test` works)
- [ ] User account matches host (`task dev:exec -- whoami` matches your host username)

## Common Workflows

### Initial Setup

```bash
# 1. Start Colima
colima start --runtime=incus

# 2. Create container (automatically installs tools, sets up user, copies SSH keys)
task dev:create

# 3. Verify workspace is accessible
task dev:exec -- ls -la ${WINDSOR_PROJECT_ROOT}

# 4. Verify everything is set up
task dev:shell
# Inside container:
git --version
git config --global user.name
git config --global user.email
ssh -T git@github.com
exit
```

### Daily Development

**Recommended Workflow:**
```bash
# 1. Start Colima (if stopped)
colima start --runtime=incus

# 2. Start container (if stopped)
task dev:start

# 3. Edit files locally using your IDE
code ${WINDSOR_PROJECT_ROOT}/src

# 4. Run commands in container
task dev:exec -- npm install
task dev:exec -- npm test
task dev:exec -- python src/main.py

# 5. Commit changes from host or container
cd ${WINDSOR_PROJECT_ROOT}
git add .
git commit -m "Changes"
git push
```

### Working with Git

Since the workspace is shared, you can use Git from either host or container:

**From macOS host:**
```bash
cd ${WINDSOR_PROJECT_ROOT}/project
git clone git@github.com:user/repo.git
cd repo
# Edit files in your IDE
git add .
git commit -m "Changes"
git push
```

**From container:**
```bash
task dev:exec -- bash -c "cd ${WINDSOR_PROJECT_ROOT}/project && git clone git@github.com:user/repo.git"
task dev:exec -- bash -c "cd ${WINDSOR_PROJECT_ROOT}/project/repo && git status"
```

Both work seamlessly!

## Troubleshooting

### Container Won't Start

```bash
# Check container status
task dev:info

# Check Colima status
colima status

# Check Incus logs
incus info local:dev

# Try starting manually
incus start local:dev
```

### Colima Won't Start

```bash
# Check Colima status
colima status

# Check logs
colima logs

# Try restarting
colima restart

# If issues persist, delete and recreate
colima stop
colima delete
colima start --runtime=incus
```

### Workspace Not Accessible

```bash
# Verify workspace sharing is enabled
windsor env | grep DEV_SHARE_WORKSPACE

# Check container status
task dev:info

# Verify workspace path exists in container
task dev:exec -- ls -la ${WINDSOR_PROJECT_ROOT}

# Restart container
task dev:restart
```

### Git Operations Fail

```bash
# Verify Git is installed
task dev:exec -- git --version

# Check Git configuration
task dev:exec -- git config --list

# Test GitHub connection
task dev:exec -- ssh -T git@github.com
```

### Permission Issues

```bash
# Check file permissions in container
task dev:exec -- ls -la ${WINDSOR_PROJECT_ROOT}

# Adjust permissions if needed
task dev:exec -- sudo chown -R $USER:$USER ${WINDSOR_PROJECT_ROOT}
```

### Docker Not Working

If you need Docker inside the container:

```bash
# Check DOCKER_HOST is set correctly
windsor env | grep DOCKER_HOST

# The DOCKER_HOST should point to Colima's socket
# Update in windsor.yaml if needed:
# DOCKER_HOST: unix://${HOME}/.colima/default/docker.sock
```

## Final Verification Test

To verify everything is set up correctly, perform this final test:

```bash
# 1. Verify Colima is running
colima status

# 2. Verify container is running
task dev:info

# 3. Access container shell
task dev:shell

# 4. Inside container, verify:
#    - You're in the workspace directory (or can navigate to it)
cd ${WINDSOR_PROJECT_ROOT}
pwd

#    - You can see workspace files
ls -la

#    - You can run tasks (if Taskfile is in workspace)
task help

#    - Git works with GitHub
git clone git@github.com:user/repo.git test-repo
cd test-repo
git status
cd ..
rm -rf test-repo

#    - All developer tools are available
git --version
curl --version
vim --version

# 5. Exit container
exit

# 6. Verify file sync works (edit on host, see in container)
echo "test" > ${WINDSOR_PROJECT_ROOT}/test-file.txt
task dev:exec -- cat ${WINDSOR_PROJECT_ROOT}/test-file.txt
rm ${WINDSOR_PROJECT_ROOT}/test-file.txt
```

If all these commands work, your local development container is fully configured and ready for development!

**What this test confirms:**
- ✅ Colima is running with Incus runtime
- ✅ Container is accessible
- ✅ Workspace directory is shared and accessible
- ✅ All developer tools are installed
- ✅ Git and SSH keys work with GitHub
- ✅ You can run the same tasks locally and in container
- ✅ File sync works between host and container
- ✅ You're ready for productive development work

## Additional Resources

- [Colima Documentation](https://github.com/abiosoft/colima)
- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Incus File Operations](https://linuxcontainers.org/incus/docs/main/instances/#file-operations)
- [Incus Exec Command](https://linuxcontainers.org/incus/docs/main/instances/#execute-commands)
