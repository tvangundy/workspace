# Remote Development VM on IncusOS

This runbook guides you through creating and managing development virtual machines on a remote IncusOS server. This setup provides a standalone remote development environment ideal for persistent development work with direct SSH access.

## Overview

Remote development VMs run on an IncusOS server and provide:

- Isolated, reproducible development environments
- Persistent storage on the remote server
- **Direct SSH access** from your local network (gets IP on your local network)
- Access via `incus exec` (similar to `docker exec`)
- Ability to initialize with workspace contents on creation
- File transfer capabilities between local workspace and remote VM

## Prerequisites

- Incus client installed on your local machine
- IncusOS server set up and accessible (see [IncusOS Setup](./setup.md))
- Incus remote configured (see [IncusOS Setup - Step 7](./setup.md#step-7-connect-to-incus-server))
- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))

## Setup

### Step 1: Install Tools Dependencies

To fully leverage the Windsor environment and manage your remote development VM, you will need several tools installed on your system. You may install these tools manually or using your preferred tools manager (_e.g._ Homebrew). The Windsor project recommends [aqua](https://aquaproj.github.io/). For your convenience, we have provided a sample setup file for aqua. Place this file in the root of your project.

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
- name: lxc/incus@v6.20.0

```

### Step 2: Configure Environment Variables

Add the following to your `contexts/<context>/windsor.yaml`:

```yaml
environment:
  # Remote Incus server name (e.g., 'nuc', 'server1')
  INCUS_REMOTE_NAME: nuc
  
  # Disable workspace sharing (required for remote)
  DEV_SHARE_WORKSPACE: false
  
  # Workspace initialization (optional)
  DEV_INIT_WORKSPACE: true  # Set to true to copy workspace contents on creation
  # Workspace will be copied to ~/workspace-name (same folder name as on host, in user's home directory)
  
  # Default VM name (optional, defaults to dev)
  DEV_INSTANCE_NAME: dev
  DEV_INSTANCE_TYPE: vm
  
  # Default image (optional, defaults to ubuntu/24.04)
  DEV_IMAGE: ubuntu/24.04
  
  # VM resources (optional)
  DEV_MEMORY: 8GB
  DEV_CPU: 2
  
  DOCKER_HOST: unix:///var/run/docker.sock

```

### Step 3: Configure Talos Machine Settings (If Setting Up a Talos Kubernetes Cluster)

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

### Step 4: Verify Remote Connection

Before creating a VM, verify you can connect to the remote Incus server:

```bash
# List configured remotes
incus remote list

# Verify you can connect to the remote
incus list nuc:

# Verify environment variables are set
windsor env | grep INCUS_REMOTE_NAME
```

**Expected output:**

- Your remote should appear in `incus remote list`
- `incus list nuc:` should show existing instances (may be empty)
- `INCUS_REMOTE_NAME` should match your remote name

### Step 5: Create the Development VM

Create a VM on the remote server:

```bash
task dev:create
```

**Why VMs?**

- Gets an IP address on your local network (via bridged networking, e.g., `192.168.2.x`)
- Directly accessible via SSH from any machine on your network
- Full OS isolation
- Can SSH in immediately after creation

**Network Configuration Required**: For VMs to get IPs on your local network, your IncusOS server must have the physical network interface configured with the `instances` role. This allows VMs to use bridged networking.

To check if this is configured:
```bash
# On the IncusOS server, check network configuration
incus admin os system network show
```

Look for your physical interface (e.g., `eno1`, `eth0`) and verify it has `instances` in the `roles` list. If not, you'll need to add it:

```bash
# Edit network configuration
incus admin os system network edit
```

Add `instances` to the `roles` list for your physical interface. See [IncusOS Setup - Network Configuration](./setup.md#network-configuration) for detailed instructions.

**Note**: After configuring the network, you may need to restart existing VMs for them to get new IP addresses on your local network.

The VM will:

- Create a VM named `dev` (or the name in `DEV_INSTANCE_NAME`)
- Use Ubuntu 24.04 as the base image
- Optionally initialize with workspace contents if `DEV_INIT_WORKSPACE=true`
- **Automatically install developer tools** (git, build-essential, curl, vim, etc.)
- **Create a user matching your host username** with the same UID/GID
- **Copy your SSH keys** for immediate GitHub access
- **Configure Git** with your existing settings
- **Set up SSH server** for direct access
- Configure the VM with the specified resources
- **Get an IP address on your local network** for immediate SSH access

**Confirmation:**
```bash
# Verify VM was created
task dev:list

# Check VM status
task dev:info

# Verify workspace was initialized (if enabled)
# Workspace is copied to ~/workspace-name (replace 'workspace-name' with your actual workspace folder name)
task dev:exec -- ls -la ~/workspace-name

# Verify developer tools are installed
task dev:exec -- git --version
task dev:exec -- curl --version

# Verify user was created (should match your host username)
task dev:exec -- whoami
```

### Step 6: Access the Development VM

You can access the VM in three ways:

#### Option 1: Interactive Shell

Open an interactive bash shell in the VM:

```bash
task dev:shell
```

This is equivalent to `docker exec -it <vm> bash`. You'll get a shell prompt where you can run commands interactively.

#### Option 2: Execute Commands Directly

Run specific commands without entering an interactive shell:

```bash
# Workspace is in ~/workspace-name (replace with your actual workspace folder name)
task dev:exec -- ls -la ~/workspace-name
task dev:exec -- apt update && apt install -y git
```

Use this option when you want to run a single command or a series of commands without opening an interactive session.

#### Option 3: SSH Access (Recommended - Works Immediately After Creation)

Once the VM is created, you can SSH directly into it immediately:

```bash
# Get SSH connection information (shows the VM's IP on your local network)
task dev:ssh-info

# SSH into the VM (you'll be in your home directory)
ssh $(whoami)@<vm-ip>

# Or SSH directly into the workspace directory (replace 'workspace-name' with your actual workspace folder name)
ssh $(whoami)@<vm-ip> -t 'cd ~/workspace-name && bash'
```

**Benefits of SSH access:**

- **Works immediately** - VM gets an IP on your local network right after creation
- Native terminal experience
- Can run all the same tasks you run locally
- Direct access to workspace directory
- Full shell integration

**Network Access:**

- **VMs**: Get IPs on your local network (e.g., `192.168.2.x`) and are directly accessible from any machine on your network
- The IP address is shown by `task dev:ssh-info` and remains stable

**Note**: The VM is automatically configured with:

- Your host username and UID/GID
- Your SSH keys (for GitHub access)
- Your Git configuration
- Developer tools pre-installed
- SSH server running and ready

## Developer Environment Setup

The VM is automatically initialized with:

### Installed Tools

- **Git** - Version control
- **Build tools** - build-essential, gcc, make, etc.
- **Network tools** - curl, wget
- **Editors** - vim, nano
- **SSH client/server** - For GitHub access and remote access
- **System tools** - sudo, ca-certificates, gnupg

### User Configuration

- **Matching user account** - Created with the same username, UID, and GID as your host
- **SSH keys** - Your `~/.ssh/id_rsa` and `id_rsa.pub` are copied
- **SSH config** - Your `~/.ssh/config` is copied (if it exists)
- **Git configuration** - Your global Git user.name and user.email are configured
- **Sudo access** - Passwordless sudo is configured

### Workspace Setup

- **Workspace directory** - Located at `~/workspace-name` (in user's home directory, same folder name as on host) with proper permissions
- **Ownership** - Owned by your user account
- **Ready for development** - Can immediately clone repos, run tasks, etc.

## Data Transfer

Since the VM runs on a remote server, you'll need to transfer files between your local workspace and the remote VM.

### Transferring Files to VM

#### Push Single File

```bash
# Push a file to the VM
incus file push local-file.txt nuc:dev/tmp/

# Push to workspace directory (replace 'workspace-name' with your actual workspace folder name)
incus file push local-file.txt nuc:dev/home/$(whoami)/workspace-name/
```

#### Push Directory

```bash
# Push entire directory recursively (replace 'workspace-name' with your actual workspace folder name)
incus file push -r ./src nuc:dev/home/$(whoami)/workspace-name/

# Push with specific permissions
incus file push -r --mode=0755 ./scripts nuc:dev/home/$(whoami)/workspace-name/
```

#### Push from Workspace Root

```bash
# Push entire workspace to VM (replace 'workspace-name' with your actual workspace folder name)
incus file push -r "${WINDSOR_PROJECT_ROOT}/" nuc:dev/home/$(whoami)/workspace-name/
```

### Transferring Files from VM

#### Pull Single File

```bash
# Pull a file from the VM
incus file pull nuc:dev/tmp/file.txt ./

# Pull from workspace directory (replace 'workspace-name' with your actual workspace folder name)
incus file pull nuc:dev/home/$(whoami)/workspace-name/output.txt ./
```

#### Pull Directory

```bash
# Pull entire directory recursively (replace 'workspace-name' with your actual workspace folder name)
incus file pull -r nuc:dev/home/$(whoami)/workspace-name/output ./

# Pull to specific destination
incus file pull -r nuc:dev/home/$(whoami)/workspace-name/build ./local-build/
```

### Sync Workspace (Bidirectional)

For ongoing development, you may want to sync your local workspace with the remote VM:

```bash
# Sync local workspace to remote VM (replace 'workspace-name' with your actual workspace folder name)
rsync -avz --exclude='.git' "${WINDSOR_PROJECT_ROOT}/" user@nuc:/tmp/workspace-sync/
incus file push -r /tmp/workspace-sync/ nuc:dev/home/$(whoami)/workspace-name/

# Or use incus file push directly (slower but simpler)
incus file push -r "${WINDSOR_PROJECT_ROOT}/" nuc:dev/home/$(whoami)/workspace-name/
```

**Note**: For large workspaces, consider using `rsync` over SSH to the remote server first, then using `incus file push` from the server to the VM.

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
task dev:exec -- git clone https://github.com/user/repo.git ~/workspace-name/project

# Clone a private repository (SSH keys are already configured)
task dev:exec -- git clone git@github.com:user/repo.git ~/workspace-name/project
```

### Test GitHub Connection

Verify your SSH keys work with GitHub:

```bash
# Test GitHub SSH connection
task dev:exec -- ssh -T git@github.com
```

You should see: `Hi <username>! You've successfully authenticated...`

### Working with Repositories via SSH

When you SSH into the VM, you can work with Git repositories just like on your local machine:

```bash
# SSH into VM (get IP from task dev:ssh-info, replace 'workspace-name' with your actual workspace folder name)
ssh $(whoami)@<vm-ip> -t 'cd ~/workspace-name && bash'

# Inside the VM, you can:
cd ~/workspace-name
git clone git@github.com:user/repo.git
cd repo
git status
git pull
# ... make changes ...
git add .
git commit -m "Changes"
git push
```

### Working with Repositories via incus exec

Alternatively, you can use `task dev:shell` or `task dev:exec`:

```bash
# Navigate to your project
task dev:shell
# Inside VM:
cd ~/workspace-name/project

# Check status
git status

# Pull latest changes
git pull

# Make changes, commit, and push
git add .
git commit -m "Your commit message"
git push
```

## Managing the VM

### List VMs

```bash
# List all dev VMs
task dev:list
```

### Get VM Information

```bash
# Get detailed info about the VM
task dev:info

# Or specify the VM name
task dev:info -- my-dev
```

### Get SSH Connection Info

```bash
# Get SSH connection information
task dev:ssh-info

# This will show:
# - VM IP address (on your local network)
# - Username to use
# - SSH command to connect
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

### Delete VM (Take Down the Remote VM)

To completely remove the remote development VM and all its data:

```bash
# Delete the VM (destructive, includes 5-second confirmation delay)
task dev:delete

# Or specify the VM name
task dev:delete -- my-dev
```

**What Gets Deleted:**

- The VM instance and all its data
- All files in the VM, including:

  - Workspace directory contents (`~/workspace-name`)
  - User data and configuration
  - Installed packages and tools
  - Any work or changes not backed up

**Warning**: Deleting the VM is **irreversible** and will permanently destroy all data on the VM. Make sure you have:

- Backed up any important files
- Pushed any Git commits to remote repositories
- Saved any work you want to keep

**Steps to Take Down the VM:**

1. **Back up any important data** (if needed):
   ```bash
   # Pull files from VM before deletion
   incus file pull -r nuc:dev/home/$(whoami)/workspace-name/ ./backup/
   ```

2. **Stop the VM** (optional, deletion will stop it automatically):
   ```bash
   task dev:stop
   ```

3. **Delete the VM**:
   ```bash
   task dev:delete
   ```
   
   The command includes a 5-second confirmation delay. Press `Ctrl+C` to cancel if needed.

4. **Verify deletion**:
   ```bash
   # List VMs - your VM should no longer appear
   task dev:list
   ```

**After Deletion:**

- The VM is completely removed from the remote Incus server
- All data on the VM is permanently deleted
- You can create a new VM using `task dev:create` if needed
- The VM's IP address will be released back to your network's DHCP pool

## Confirmation Checklist

Use this checklist to verify your setup is working correctly:

- [ ] Remote Incus server is accessible (`incus list nuc:` works)
- [ ] Environment variables are set correctly (`windsor env | grep INCUS_REMOTE_NAME`)
- [ ] VM was created successfully (`task dev:list` shows your VM)
- [ ] VM is running (`task dev:info` shows status as "Running")
- [ ] VM has an IP on your local network (`task dev:ssh-info` shows IP like `192.168.2.x`)
- [ ] Workspace was initialized (if enabled) (`task dev:exec -- ls -la ~/workspace-name` shows files)
- [ ] Can access VM shell (`task dev:shell` works)
- [ ] Can execute commands (`task dev:exec -- echo "test"` works)
- [ ] Can push files to VM (`incus file push` works)
- [ ] Can pull files from VM (`incus file pull` works)
- [ ] Git is installed (`task dev:exec -- git --version` works)
- [ ] Git is configured (`task dev:exec -- git config --global user.name` shows your name)
- [ ] SSH keys are set up (`task dev:exec -- ssh -T git@github.com` works)
- [ ] Can clone repositories (`task dev:exec -- git clone git@github.com:user/repo.git ~/workspace-name/test` works)
- [ ] User account matches host (`task dev:exec -- whoami` matches your host username)
- [ ] **Can SSH into VM** (`task dev:ssh-info` shows connection info, then `ssh user@ip` works immediately)
- [ ] **Final test**: SSH into VM, navigate to `~/workspace-name`, and run tasks (e.g., `task help`)

## Common Workflows

### Initial Setup

```bash
# 1. Create VM (automatically installs tools, sets up user, copies SSH keys, gets IP on local network)
task dev:create -- vm ubuntu/24.04

# 2. Get SSH connection info (VM will have an IP on your local network)
task dev:ssh-info

# 3. SSH into VM immediately (works right after creation)
ssh $(whoami)@<vm-ip> -t 'cd ~/workspace-name && bash'

# 4. Inside VM, verify everything is set up:
#    - You're in the workspace directory
pwd  # Should show ~/workspace-name (or /home/$(whoami)/workspace-name)

#    - Workspace files are there
ls -la

#    - Developer tools are installed
git --version
curl --version

#    - Git is configured
git config --global user.name
git config --global user.email

#    - SSH keys work with GitHub
ssh -T git@github.com

#    - Tasks are available
task help  # Should show available tasks
```

### Daily Development

**Option 1: Using SSH (Recommended)**
```bash
# 1. Start VM (if stopped)
task dev:start

# 2. Get SSH connection info
task dev:ssh-info

# 3. SSH into VM, navigate to workspace
ssh $(whoami)@<vm-ip> -t 'cd ~/workspace-name && bash'

# 4. Work in VM - all your tasks and tools are available
# Inside VM:
task help
git clone git@github.com:user/repo.git
# ... do your work ...
```

**Option 2: Using incus exec**
```bash
# 1. Start VM (if stopped)
task dev:start

# 2. Sync latest changes from local workspace (if needed)
incus file push -r "${WINDSOR_PROJECT_ROOT}/" nuc:dev/home/$(whoami)/workspace-name/

# 3. Work in VM
task dev:shell

# 4. When done, pull changes back to local (if needed)
incus file pull -r nuc:dev/home/$(whoami)/workspace-name/ "${WINDSOR_PROJECT_ROOT}/"
```

### Working with GitHub

```bash
# 1. SSH into VM (get IP from task dev:ssh-info)
task dev:ssh-info
ssh $(whoami)@<vm-ip> -t 'cd ~/workspace-name && bash'

# 2. Clone repository (SSH keys are already configured)
git clone git@github.com:user/repo.git project
cd project

# 3. Make changes and commit
# ... make changes ...
git add .
git commit -m "Changes"
git push

# 4. All done! Changes are in the remote VM's workspace
# If you need to sync back to local workspace:
exit  # Exit SSH session
incus file pull -r nuc:dev/home/$(whoami)/workspace-name/project "${WINDSOR_PROJECT_ROOT}/"
```

## Troubleshooting

### VM Won't Start

```bash
# Check VM status
task dev:info

# Check Incus logs
incus info nuc:dev

# Try starting manually
incus start nuc:dev
```

### File Transfer Fails

```bash
# Verify remote connection
incus list nuc:

# Check VM is running
task dev:info

# Verify file paths exist
task dev:exec -- ls -la ~/workspace-name
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
task dev:exec -- ls -la ~/workspace-name

# Adjust permissions if needed
task dev:exec -- sudo chown -R $USER:$USER ~/workspace-name
```

### Cannot SSH into VM

```bash
# Verify VM has an IP on your local network
task dev:ssh-info

# Check VM is running
task dev:info

# Verify network configuration on IncusOS server
# (VM needs physical interface with 'instances' role)
incus admin os system network show

# If VM doesn't have a local network IP, check network configuration
# and restart the VM after fixing network settings
task dev:restart
```

## Final Verification Test

To verify everything is set up correctly, perform this final test:

```bash
# 1. Get SSH connection information (shows VM IP on your local network)
task dev:ssh-info

# 2. SSH into the VM, navigating directly to workspace
#    This works immediately after VM creation
ssh $(whoami)@<vm-ip> -t 'cd ~/workspace-name && bash'

# 3. Inside the VM, verify:
#    - You're in the workspace directory
pwd  # Should show ~/workspace-name (or /home/$(whoami)/workspace-name)

#    - You can see workspace files
ls -la  # Should show your workspace contents

#    - You can run tasks (if Taskfile is in workspace)
task help  # Should show available tasks

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

# 4. Exit when done
exit
```

If all these commands work, your remote development VM is fully configured and ready for development!

**What this test confirms:**
- ✅ VM is accessible via SSH from your local network
- ✅ VM has an IP address on your local network (e.g., `192.168.2.x`)
- ✅ User account is set up correctly
- ✅ Workspace directory is accessible
- ✅ All developer tools are installed
- ✅ Git and SSH keys work with GitHub
- ✅ You can run the same tasks locally and remotely
- ✅ You can SSH in immediately after creation
- ✅ You're ready for productive development work

## Additional Resources

- [Incus Documentation](https://linuxcontainers.org/incus/docs/main/)
- [Incus File Operations](https://linuxcontainers.org/incus/docs/main/instances/#file-operations)
- [Incus Exec Command](https://linuxcontainers.org/incus/docs/main/instances/#execute-commands)

