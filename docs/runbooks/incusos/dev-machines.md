# Remote Development Machines on IncusOS

This runbook guides you through creating and managing development virtual machines on a remote IncusOS server. These VMs provide isolated, persistent development environments with direct SSH access from your local network.

## Overview

Remote development VMs run on your IncusOS server and provide:

- Isolated, reproducible development environments
- Direct SSH access from your local network (no port forwarding needed)
- Persistent storage and configurations
- Full system access for installing tools and services
- Workspace syncing capabilities for file transfer
- Dedicated resources (CPU, memory, disk)

## Prerequisites

- IncusOS server installed and running (see [IncusOS Setup](setup.md))
- Incus CLI client installed on your local machine
- Remote connection to your IncusOS server configured
- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))

## Step 1: Install Tools Dependencies

To fully leverage the Windsor environment and manage your remote development VMs, you will need several tools installed on your system. You may install these tools manually or using your preferred tools manager (_e.g._ Homebrew). The Windsor project recommends [aqua](https://aquaproj.github.io/).

Ensure your `aqua.yaml` includes the following packages required for this runbook. Add any missing packages to your existing `aqua.yaml`:

```yaml
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
- name: lima-vm/lima@v1.0.7
```

To install the tools specified in `aqua.yaml`, run:

```bash
aqua install
```

## Step 2: Configure Environment Variables

Add the following to your `contexts/<context>/windsor.yaml`:

```yaml
environment:
  # Use remote Incus server
  INCUS_REMOTE_NAME: your-remote-name
  
  # Workspace initialization (optional)
  DEV_INIT_WORKSPACE: true  # Set to true to initialize workspace on creation
  
  # Default VM name (optional, defaults to dev)
  DEV_INSTANCE_NAME: dev
  DEV_INSTANCE_TYPE: vm  # Use VM for remote development
  
  # Default image (optional, defaults to ubuntu/24.04)
  DEV_IMAGE: ubuntu/24.04
  
  # VM resources (optional)
  DEV_MEMORY: 8GB
  DEV_CPU: 4
  
  # Network interface for VM (optional, defaults to eth0)
  # This should be a physical interface on the IncusOS server
  DEV_NETWORK_NAME: enp5s0
  
  # Use default Docker socket (VMs run Docker natively)
  DOCKER_HOST: unix:///var/run/docker.sock
```

**Important Notes:**

- `INCUS_REMOTE_NAME` - The name of your Incus remote (configured via `incus remote add`)
- `DEV_INSTANCE_TYPE: vm` - Use VMs for remote development (more isolation than containers)
- `DEV_NETWORK_NAME` - Physical network interface on your IncusOS server for direct network access
- `DOCKER_HOST` - Points to the default Docker socket (VMs run Docker natively)

## Step 3: Configure Talos Machine Settings (If Setting Up a Talos Kubernetes Cluster)

**Note**: This step is only needed if you plan to set up a Talos Kubernetes cluster in your dev VM. If you're just creating a regular Ubuntu development VM, skip this step and proceed to Step 4.

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

**Important**: This configuration must be in place before creating the VM. The kernel module configuration will take effect when you generate and apply Talos machine configurations.

If you're not using Terraform/Windsor CLI and generating Talos configs directly, you'll need to patch the generated YAML files manually or use `talosctl` patch commands.

## Step 4: Verify Remote Connection

Before creating a VM, verify you can connect to your IncusOS server:

```bash
# List configured remotes
incus remote list

# Verify you can connect to your remote
incus list <remote-name>:

# Verify environment variables are set
windsor env | grep INCUS_REMOTE_NAME
```

**Expected output:**

- Your remote should appear in `incus remote list` with the name you configured
- `incus list <remote-name>:` should show existing instances (may be empty)
- `INCUS_REMOTE_NAME` should be set to your remote name

## Step 5: Create the Development VM

Create a VM on your IncusOS server:

```bash
task dev:create
```

**Why VMs for Remote Development?**

- **Full isolation** - Each VM is completely isolated from others
- **Direct network access** - VMs get IP addresses on your local network
- **Persistent storage** - Changes persist across reboots
- **Full system access** - Install any tools or services you need
- **Resource guarantees** - Dedicated CPU and memory allocation

The VM will:

- Create a VM named `dev` (or the name in `DEV_INSTANCE_NAME`)
- Use Ubuntu 24.04 as the base image
- **Get a direct IP address** on your local network (via `DEV_NETWORK_NAME`)
- Optionally initialize with workspace contents if `DEV_INIT_WORKSPACE=true`
- **Automatically install developer tools** (git, build-essential, curl, vim, etc.)
- **Create a user matching your host username** with the same UID/GID
- **Copy your SSH keys** for immediate GitHub access
- **Configure Git** with your existing settings
- **Install Docker** for containerized development
- **Set up SSH server** for direct access

**Confirmation:**
```bash
# Verify VM was created
task dev:list

# Check VM status
task dev:info

# Get VM IP address
task dev:info | grep -i ip

# Verify developer tools are installed
task dev:exec -- git --version
task dev:exec -- curl --version
task dev:exec -- docker --version

# Verify user was created (should match your host username)
task dev:exec -- whoami
```

## Step 6: Access the Development VM

You can access the VM in several ways:

#### Option 1: Direct SSH Access

Since the VM has a direct IP address on your local network, you can SSH directly:

```bash
# Get VM IP address
VM_IP=$(task dev:info | grep -i "ipv4" | awk '{print $2}' | head -1)

# SSH directly to the VM
ssh <username>@${VM_IP}
```

Or use the helper task:

```bash
task dev:ssh
```

This is the recommended method for interactive development sessions.

#### Option 2: Interactive Shell via Incus

Open an interactive bash shell via Incus:

```bash
task dev:shell
```

This is equivalent to `incus exec <vm> -- bash`. You'll get a shell prompt where you can run commands interactively.

#### Option 3: Execute Commands Directly

Run specific commands without entering an interactive shell:

```bash
task dev:exec -- ls -la ${WINDSOR_PROJECT_ROOT}
task dev:exec -- apt update && apt install -y git
```

Use this option when you want to run a single command or a series of commands without opening an interactive session.

**Benefits of Direct SSH Access:**

- **Better performance** - Direct network connection, no proxy overhead
- **SSH features** - Can use SSH agent forwarding, port forwarding, etc.
- **IDE integration** - Can use remote SSH in IDEs like VS Code
- **File sync** - Can use tools like `rsync` or `scp` directly
- **Persistent sessions** - SSH sessions persist even if Incus CLI connection drops

## Developer Environment Setup

The VM is automatically initialized with:

### Installed Tools

- **Git** - Version control
- **Build tools** - build-essential, gcc, make, etc.
- **Network tools** - curl, wget
- **Editors** - vim, nano
- **SSH client/server** - For GitHub access and direct access
- **Docker** - Container runtime for development
- **System tools** - sudo, ca-certificates, gnupg

### User Configuration

- **Matching user account** - Created with the same username, UID, and GID as your host
- **SSH keys** - Your `~/.ssh/id_rsa` and `id_rsa.pub` are copied
- **SSH config** - Your `~/.ssh/config` is copied (if it exists)
- **Git configuration** - Your global Git user.name and user.email are configured
- **Sudo access** - Passwordless sudo is configured

### Workspace Setup

- **Workspace directory** - Located at `/home/<username>/<workspace-name>`
- **Ownership** - Owned by your user account
- **Ready for development** - Can immediately clone repos, run tasks, etc.

## Workspace Syncing

While direct SSH access is recommended for most workflows, you can also sync files between your local machine and the VM:

### Copy Workspace to VM

```bash
# Copy workspace to VM (replaces existing)
task dev:copy-workspace

# Add workspace to VM (merges with existing)
task dev:add-workspace

# Sync only changed files (rsync)
task dev:sync-workspace
```

### Manual File Transfer

Since the VM has a direct IP address, you can use standard tools:

```bash
# Get VM IP
VM_IP=$(task dev:info | grep -i "ipv4" | awk '{print $2}' | head -1)

# Copy files using scp
scp -r ${WINDSOR_PROJECT_ROOT} <username>@${VM_IP}:~/workspace

# Sync files using rsync
rsync -avz ${WINDSOR_PROJECT_ROOT}/ <username>@${VM_IP}:~/workspace/
```

## GitHub Operations

Git and SSH keys are automatically configured during VM creation, so you can immediately work with GitHub repositories.

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

## Managing the VM

### List VMs

```bash
# List all dev VMs
task dev:list
```

### Get VM Information

```bash
# Get detailed info about the VM (including IP address)
task dev:info

# Or specify the VM name
task dev:info -- my-dev
```

### Start/Stop VM

```bash
# Start the VM
task dev:start

# Stop the VM
task dev:stop

# Restart the VM
task dev:restart
```

### Delete VM

To completely remove the development VM:

```bash
# Delete the VM (destructive, includes 5-second confirmation delay)
task dev:delete

# Or specify the VM name
task dev:delete -- my-dev
```

**What Gets Deleted:**

- The VM instance and all its data
- All files installed inside the VM
- VM-specific configuration

**Warning**: Deleting the VM is **irreversible** for VM-specific data.

## Common Workflows

### Initial Setup

```bash
# 1. Create VM (automatically installs tools, sets up user, copies SSH keys)
task dev:create

# 2. Get VM IP address
task dev:info | grep -i ip

# 3. SSH to VM
VM_IP=$(task dev:info | grep -i "ipv4" | awk '{print $2}' | head -1)
ssh <username>@${VM_IP}

# 4. Inside VM, verify everything is set up
git --version
git config --global user.name
git config --global user.email
ssh -T git@github.com
docker --version
```

### Daily Development

**Recommended Workflow:**
```bash
# 1. Start VM (if stopped)
task dev:start

# 2. SSH directly to VM
task dev:ssh
# Or: ssh <username>@<vm-ip>

# 3. Inside VM, work with your code
cd ~/workspace
git clone git@github.com:user/repo.git
cd repo
# Edit files, run tests, etc.

# 4. Commit and push changes
git add .
git commit -m "Changes"
git push
```

### Working with Git

Since the VM has direct SSH access, you can use Git normally:

**From VM:**
```bash
ssh <username>@<vm-ip>
cd ~/workspace
git clone git@github.com:user/repo.git
cd repo
# Edit files in your IDE or vim
git add .
git commit -m "Changes"
git push
```

## Troubleshooting

### VM Won't Start

```bash
# Check VM status
task dev:info

# Check Incus logs
incus info <remote-name>:dev

# Try starting manually
incus start <remote-name>:dev
```

### Can't SSH to VM

```bash
# Get VM IP address
task dev:info | grep -i ip

# Check if VM is running
task dev:info | grep -i status

# Verify SSH service is running in VM
task dev:exec -- systemctl status ssh

# Try accessing via Incus exec first
task dev:shell
# Then check SSH service
systemctl status ssh
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
# Check file permissions in VM
task dev:exec -- ls -la ${WINDSOR_PROJECT_ROOT}

# Adjust permissions if needed
task dev:exec -- sudo chown -R $USER:$USER ${WINDSOR_PROJECT_ROOT}
```

### Docker Not Working

```bash
# Check Docker service status
task dev:exec -- systemctl status docker

# Start Docker service if needed
task dev:exec -- sudo systemctl start docker

# Verify Docker is accessible
task dev:exec -- docker ps
```

## Confirmation Checklist

Use this checklist to verify your setup is working correctly:

- [ ] Remote connection to IncusOS server is configured (`incus remote list` shows your remote)
- [ ] Environment variables are set correctly (`windsor env | grep INCUS_REMOTE_NAME`)
- [ ] VM was created successfully (`task dev:list` shows your VM)
- [ ] VM is running (`task dev:info` shows status as "Running")
- [ ] VM has an IP address (`task dev:info` shows IPv4 address)
- [ ] Can SSH directly to VM (`task dev:ssh` or `ssh <username>@<vm-ip>` works)
- [ ] Can access VM shell via Incus (`task dev:shell` works)
- [ ] Can execute commands (`task dev:exec -- echo "test"` works)
- [ ] Git is installed (`task dev:exec -- git --version` works)
- [ ] Git is configured (`task dev:exec -- git config --global user.name` shows your name)
- [ ] SSH keys work with GitHub (`task dev:exec -- ssh -T git@github.com` works)
- [ ] Docker is installed and running (`task dev:exec -- docker ps` works)
- [ ] User account matches host (`task dev:exec -- whoami` matches your host username)
- [ ] Can clone repositories (`task dev:exec -- git clone git@github.com:user/repo.git ${WINDSOR_PROJECT_ROOT}/test` works)

## Additional Resources

- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Incus VM Management](https://linuxcontainers.org/incus/docs/main/instances/#virtual-machines)
- [Incus Network Configuration](https://linuxcontainers.org/incus/docs/main/networks/)

