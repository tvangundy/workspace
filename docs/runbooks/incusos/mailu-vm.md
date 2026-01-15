---
title: "Mailu Email Server on IncusOS VM"
description: "Complete guide for deploying Mailu email server on an Ubuntu VM on IncusOS"
---
# Mailu Email Server on IncusOS VM

This runbook guides you through deploying a [Mailu](https://mailu.io/) email server on an Ubuntu virtual machine running on an IncusOS system. This runbook leverages the standard Ubuntu VM creation process (see [Ubuntu Virtual Machines](vm.md)) and adds Mailu-specific configuration and deployment.

## Overview

Deploying Mailu on an IncusOS VM involves:

- Creating a standard Ubuntu VM using the `vm:` task namespace
- Configuring Mailu-specific secrets using SOPS
- Deploying Mailu using Docker Compose on the VM
- Configuring DNS records for email delivery
- Managing the Mailu server and VM lifecycle

This approach uses the standard VM creation workflow, making it consistent with other VM deployments while adding Mailu-specific configuration.

## Prerequisites

- IncusOS server installed and running (see [IncusOS Setup](setup.md))
- Incus CLI client installed on your local machine
- Remote connection to your IncusOS server configured
- Workspace initialized and context set (see [Initialize Workspace](../workspace/init.md))
- Domain name with DNS access
- Network access for the VM to reach the internet (for Let's Encrypt certificates)
- Email ports open (25, 587, 465, 993, 143, 80, 443)
- Sufficient resources: At least 4GB RAM and 40GB storage on the IncusOS host for the VM

## Step 1: Install Tools Dependencies

To fully leverage the Windsor environment and manage your Mailu VM, you will need several tools installed on your system. You may install these tools manually or using your preferred tools manager (_e.g._ Homebrew). The Windsor project recommends [aqua](https://aquaproj.github.io/).

Ensure your `aqua.yaml` includes the following packages required for this runbook. Add any missing packages to your existing `aqua.yaml`:

```yaml
packages:
- name: hashicorp/terraform@v1.10.3
- name: lxc/incus@v6.20.0
- name: docker/cli@v27.4.1
- name: docker/compose@v2.32.1
```

To install the tools specified in `aqua.yaml`, run:

```bash
aqua install
```

## Step 2: Set Up SOPS Secrets

Before configuring environment variables, you need to set up SOPS secrets for sensitive Mailu configuration values. You'll need two secrets:

1. **`MAILU_SECRET_KEY`**: A random secret key for Mailu encryption
2. **`MAILU_INITIAL_ADMIN_PW`**: The password for the initial Mailu admin account

### Step 2.1: Generate the Secret Key

Generate a random secret key for Mailu:

```bash
# Generate a random 32-character hex string
openssl rand -hex 32
```

**Note**: Save this value - you'll need it for the next step. This will be used as `MAILU_SECRET_KEY`.

### Step 2.2: Choose Admin Password

Choose a secure password for your Mailu admin account. This should be a strong password that you'll use to log in to the Mailu admin interface.

**Note**: Save this password - you'll need it for the next step. This will be used as `MAILU_INITIAL_ADMIN_PW`.

### Step 2.3: Generate Secrets File

Generate the secrets file template:

```bash
task sops:generate-secrets-file
```

This creates `contexts/<context>/secrets.yaml` with a template.

### Step 2.4: Add Secrets to the File

Edit `contexts/<context>/secrets.yaml` and add your secrets:

```yaml
MAILU_SECRET_KEY: "<your-generated-secret-key>"
MAILU_INITIAL_ADMIN_PW: "<your-admin-password>"
```

Replace:
- `<your-generated-secret-key>`: The random hex string you generated in Step 3.1
- `<your-admin-password>`: The secure password you chose in Step 3.2

### Step 2.5: Encrypt the Secrets File

Encrypt the secrets file using SOPS:

```bash
task sops:encrypt-secrets-file
```

This creates `contexts/<context>/secrets.enc.yaml` (the encrypted version that can be safely committed to version control).

### Step 2.6: Configure Windsor to Use the Secrets

Update `contexts/<context>/windsor.yaml` to enable SOPS:

```yaml
secrets:
  sops:
    enabled: true
environment:
  # ... other environment variables will be added in Step 4 ...
```

**Note**: For more details on managing secrets with SOPS, see the [Managing Secrets with SOPS](../secrets/secrets.md) runbook.

## Step 3: Configure Environment Variables

Configure the environment variables for your Mailu VM deployment. Add these lines to `contexts/<context>/windsor.yaml`:

```text
secrets:
  sops:
    enabled: true
environment:
  # Use remote Incus server
  INCUS_REMOTE_NAME: your-remote-name
  
  # VM configuration (using standard VM_* variables)
  VM_INSTANCE_NAME: mailu
  VM_MEMORY: 4GB  # 4GB recommended with antivirus/ClamAV
  VM_CPU: 4
  VM_AUTOSTART: true
  VM_NETWORK_NAME: eno1  # Physical network interface for direct network access
  VM_DISK_SIZE: 100GB  # Recommended for mail storage
  
  # Workspace initialization (optional, set to false for Mailu VM)
  VM_INIT_WORKSPACE: false
  
  # Use default Docker socket (VMs run Docker natively)
  DOCKER_HOST: unix:///var/run/docker.sock

  # Mailu configuration (optional - can be set later)
  MAILU_DOMAIN: "example.com"
  MAILU_HOSTNAME: "mail.example.com"
  # Generate random strings if sops values are not available:
  # Run these commands to generate secure random values:
  #   openssl rand -hex 32    # For MAILU_SECRET_KEY
  #   openssl rand -base64 24 # For MAILU_INITIAL_ADMIN_PW
  # Then replace the values below, or use sops if configured:
  MAILU_SECRET_KEY: ${{ sops.MAILU_SECRET_KEY || "1b57fc851a92796b0743c4fa778d62b8310f47b275498cd5747685a6f2d81162" }}
  MAILU_INITIAL_ADMIN_PW: ${{ sops.MAILU_INITIAL_ADMIN_PW || "TUbV2j3Z/Frm+MoxkszQsOKCj44jj08M" }}
```

**Important Notes:**

- `INCUS_REMOTE_NAME` - The name of your Incus remote (configured via `incus remote add`)
- `VM_INSTANCE_NAME` - Name for the Mailu VM instance (defaults to `mailu`)
- `VM_MEMORY` - Memory allocation (4GB recommended with antivirus/ClamAV)
- `VM_CPU` - CPU cores (4 cores recommended)
- `VM_NETWORK_NAME` - Physical network interface on your IncusOS server for direct network access (e.g., `eno1`, `eth0`, `enp5s0`)
- `VM_DISK_SIZE` - Disk size for mail storage (100GB recommended)
- `VM_INIT_WORKSPACE` - Set to `false` for Mailu VMs (no need for workspace sync)
- `MAILU_SECRET_KEY` and `MAILU_INITIAL_ADMIN_PW` - From SOPS secrets (set in Step 2)

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

## Step 5: Configure Direct Network Attachment (Optional)

To allow the VM to get an IP address directly on your physical network, you need to configure a physical network interface for direct attachment. This creates a network that bypasses NAT and connects the VM directly to your physical network.

### Step 5a: View Current Network Configuration

First, check the current network configuration:

```bash
incus admin os system network show
```

This shows your network interfaces and their current roles.

### Step 5b: Add Instances Role to Physical Interface

Edit the network configuration to add the `instances` role to your physical network interface (typically `eno1` or `eth0`):

```bash
incus admin os system network edit
```

In the editor, find your physical interface (e.g., `eno1`) in the `config.interfaces` section. **Add a `roles` field** if it doesn't exist, and include `instances` in the list:

```yaml
config:
  interfaces:
  - addresses:
    - dhcp4
    - slaac
    hwaddr: 88:ae:dd:03:f9:f4
    name: eno1
    required_for_online: "no"
    roles:          # Add this field if it doesn't exist
    - management
    - cluster
    - instances     # Add this line
```

**Important**: 

- The `roles` field must be added to the `config.interfaces` section (not just the `state` section)
- Make sure the YAML indentation is correct (2 spaces)
- Save the file (in vim: press `Esc`, then type `:wq` and press Enter; in nano: press `Ctrl+X`, then `Y`, then Enter)

After saving, the configuration will be applied automatically. Verify the change:

```bash
incus admin os system network show
```

You should see `instances` in the `state.interfaces.eno1.roles` list.

### Step 5c: Create Physical Network

After the configuration is applied, create a managed physical network:

```bash
task incus:create-physical-network
```

This creates a physical network that directly attaches to your host's network interface, allowing the VM to get an IP address directly from your physical network's DHCP server.

**Note**: 

- If the physical network already exists, the task will verify it's correctly configured and skip creation. If you need to recreate it, delete it first with `incus network delete <remote-name>:<interface-name>`.
- Replace `eno1` with your actual physical network interface name if different. Common interface names include `eno1`, `eth0`, `enp5s0`, etc.
- You can override the interface name by setting the `VM_NETWORK_NAME` environment variable in your `windsor.yaml` file.
- After this step, VMs launched with this network will get IP addresses directly from your physical network's DHCP server, bypassing NAT.

## Step 6: Create the Ubuntu VM

Create the Ubuntu VM using the standard VM creation workflow:

```bash
task vm:create --name mailu
```

Or if you've set `VM_INSTANCE_NAME: mailu` in your environment variables:

```bash
task vm:create
```

This will:

1. Generate `terraform.tfvars` from environment variables
2. Initialize Terraform
3. Apply the Terraform configuration to create the VM
4. **Automatically install developer tools** (git, build-essential, curl, vim, etc.)
5. **Create a user matching your host username** with the same UID/GID
6. **Copy your SSH keys** for immediate access
7. **Configure Git** with your existing settings
8. **Install Docker** for containerized services
9. **Set up SSH server** for direct access

**Note**: The VM is created with Docker already installed, so you can skip the Docker installation step that was previously required.

**Confirmation:**
```bash
# Verify VM was created
task vm:list

# Check VM status
task vm:info -- mailu

# Get VM IP address
task vm:info -- mailu | grep -i ip

# Verify Docker is installed
task vm:exec -- mailu -- docker --version
```

## Step 7: Get the VM IP Address

After the VM boots and receives its DHCP-assigned IP address, get the IP address:

```bash
# Get VM IP address using the vm:info task
task vm:info -- mailu | grep -i "ipv4"

# Or get detailed information
task vm:info -- mailu

# Or use Incus directly
incus list $INCUS_REMOTE_NAME:mailu
```

**Note**: With direct network attachment, the VM gets an IP address from your DHCP server. Note this IP address as you'll need it for DNS configuration and SSH access.

## Step 8: Access the VM

You can access the VM in several ways:

#### Option 1: Direct SSH Access

Since the VM has a direct IP address on your local network, you can SSH directly:

```bash
# Get VM IP address
VM_IP=$(task vm:info -- mailu | grep -i "ipv4" | awk '{print $2}' | head -1)

# SSH directly to the VM (using your host username)
ssh <username>@${VM_IP}
```

Or use the helper task:

```bash
task vm:ssh -- mailu
```

#### Option 2: Interactive Shell via Incus

Open an interactive bash shell via Incus:

```bash
task vm:shell -- mailu
```

#### Option 3: Execute Commands Directly

Run specific commands without entering an interactive shell:

```bash
task vm:exec -- mailu -- docker --version
task vm:exec -- mailu -- docker compose version
```

**Note**: The VM created with `task vm:create` already has Docker installed and SSH configured. Your SSH keys are already copied, so you can SSH directly without additional setup.

## Step 9: Deploy Mailu

Now that your Ubuntu VM is set up with Docker, follow the [Mailu Email Server](../mailu/mailu.md) runbook to deploy Mailu on the VM.

**Important Notes for Deploying Mailu on the VM:**

1. **SSH to the VM**: Use `task vm:ssh -- mailu` or SSH directly using the VM's IP address
2. **Use the VM's IP address**: When configuring DNS records, use the VM's IP address (not the IncusOS host IP)
3. **VM has direct network access**: The VM gets its IP from DHCP, so it's directly accessible on your network
4. **Port forwarding not needed**: Since the VM has direct network access, you don't need to set up port forwarding
5. **Docker is already installed**: The VM created with `task vm:create` already has Docker and Docker Compose installed

### Quick Start for Mailu Deployment

On the VM, create a directory for Mailu and follow the Mailu runbook:

```bash
# SSH to the VM
task vm:ssh -- mailu
# Or: ssh <username>@<vm-ip>

# Inside the VM, create Mailu directory
sudo mkdir -p /mailu
cd /mailu

# Follow the Mailu runbook from here:
# 1. Generate configuration files using https://setup.mailu.io/
# 2. Download docker-compose.yml and mailu.env
# 3. Configure DNS records (use the VM's IP address)
# 4. Start Mailu services
# 5. Create admin account
```

**Note**: For detailed instructions, see the [Mailu Email Server](../mailu/mailu.md) runbook. The VM is now ready for Mailu deployment, and you can follow that runbook starting from Step 3 (Configure DNS Records).

## Step 10: Configure DNS Records

Configure DNS records for your email domain. Use the VM's IP address (not the IncusOS host IP) when setting up DNS records.

### Mail Server Hostname (A Record)

Create an A record pointing to your VM's IP address:

```
mail.example.com. IN A <vm-ip-address>
```

### MX Records

Add an MX record for each domain you want to handle email for:

```
example.com. IN MX 10 mail.example.com.
```

### Reverse DNS (PTR Record)

Configure reverse DNS for your VM's IP address. This should point to your mail server hostname:

```
<vm-ip-address> IN PTR mail.example.com.
```

**Note**: Reverse DNS is typically configured through your hosting provider or ISP. Contact them to set up reverse DNS for your VM's IP address.

### Additional DNS Records

After Mailu is deployed, you'll need to add SPF, DKIM, and DMARC records. These will be shown in the Mailu admin interface after deployment. See Step 9 in the [Mailu Email Server](../mailu/mailu.md) runbook for details.

## Step 11: Verify Mailu Deployment

After deploying Mailu following the Mailu runbook, verify that everything is working:

### Check Mailu Services

SSH to the VM and check Mailu services:

```bash
# SSH to the VM
task vm:ssh -- mailu
# Or: ssh <username>@<vm-ip>

# Check Docker containers
cd /mailu
docker compose ps

# View logs
docker compose logs -f
```

### Test Email Delivery

1. Log in to the Mailu webmail interface at `https://mail.example.com/webmail/`
2. Send a test email to an external email address
3. Receive a test email from an external email address

### Check DNS Records

Use online tools to verify your DNS records:

- [MXToolbox](https://mxtoolbox.com/): Check MX, SPF, DKIM, DMARC records
- [Mail-Tester](https://www.mail-tester.com/): Test email deliverability

## Ongoing Management

### Access the VM

You can access the Mailu VM in several ways:

```bash
# Via SSH (recommended - already configured)
task vm:ssh -- mailu

# Via Incus shell
task vm:shell -- mailu

# Via Incus exec (always works)
incus exec $INCUS_REMOTE_NAME:mailu -- bash
```

### Manage Mailu

Follow the [Mailu Email Server](../mailu/mailu.md) runbook for ongoing Mailu management:

- Updates: `task mailu:update` (on the VM)
- Backups: `task mailu:backup` (on the VM)
- Service management: `task mailu:start`, `task mailu:stop`, etc. (on the VM)

### VM Management

Manage the VM itself using the `vm:` task namespace or Terraform:

**Using VM Tasks (Recommended):**

```bash
# Start VM
task vm:start -- mailu

# Stop VM
task vm:stop -- mailu

# Restart VM
task vm:restart -- mailu

# Get VM info
task vm:info -- mailu

# List all VMs
task vm:list
```

**Using Terraform:**

```bash
# View VM status
cd terraform/vm
terraform show

# Update VM configuration
# 1. Update environment variables in windsor.yaml
# 2. Regenerate terraform.tfvars: task vm:generate-tfvars
# 3. Review changes: task vm:terraform:plan
# 4. Apply changes: task vm:terraform:apply
```

**Using Incus commands directly:**

```bash
# Start VM
incus start $INCUS_REMOTE_NAME:mailu

# Stop VM
incus stop $INCUS_REMOTE_NAME:mailu

# Restart VM
incus restart $INCUS_REMOTE_NAME:mailu

# Get VM info
incus info $INCUS_REMOTE_NAME:mailu
```

### VM Snapshots

Create snapshots for backup and recovery:

```bash
# Create snapshot
incus snapshot create $INCUS_REMOTE_NAME:mailu mailu-backup-$(date +%Y%m%d)

# List snapshots
incus snapshot list $INCUS_REMOTE_NAME:mailu

# Restore snapshot
incus snapshot restore $INCUS_REMOTE_NAME:mailu mailu-backup-YYYYMMDD
```

## Destroying the VM

To completely destroy the Mailu VM and remove all resources, use Terraform:

```bash
task vm:delete -- mailu
```

Or using Terraform directly:

```bash
cd terraform/vm
terraform destroy
```

This will:

1. **Destroy Virtual Machine**: Stops and deletes the Mailu VM
2. **Warning**: This permanently destroys all data on the VM, including:
   - All Mailu data and email
   - Docker containers and volumes
   - Any data stored on the VM

3. **Configuration Files**: The `terraform.tfvars` file is not automatically deleted. You can manually remove it if needed.

4. **Physical Network**: The physical network created for the VM is **not** deleted. The network can be shared across multiple VMs. If you want to remove it, you must do so manually with `incus network delete ${INCUS_REMOTE_NAME}:${VM_NETWORK_NAME}` (only if no other VMs are using it)

### Verification

After destruction, verify that the VM has been removed:

```bash
task vm:list
```

The Mailu VM should no longer appear in the list.

### Important Notes

- **Data Loss**: Destroying the VM will permanently delete all Mailu data, email, and persistent volumes. Ensure you have backups if needed.
- **Network**: The physical network can be reused for other VMs, so it's not deleted automatically.
- **Recreation**: To recreate the VM, simply run `task vm:create --name mailu` again.

## Troubleshooting

### VM Creation Fails

- **VM not booting**: Verify the Ubuntu image is available: `incus image list ${INCUS_REMOTE_NAME}:`
- **Network issues**: Ensure the physical network is configured correctly (Step 5)
- **Provider errors**: Check that the Incus provider can connect to your remote: `incus list ${INCUS_REMOTE_NAME}:`

### VM Not Starting

If the VM fails to start:

```bash
# Check VM status
task vm:info -- mailu

# View VM logs
incus console $INCUS_REMOTE_NAME:mailu

# Check host resources
task vm:list
```

### Network Issues

If the VM doesn't get an IP address:

```bash
# Check network configuration
incus network show $INCUS_REMOTE_NAME:$VM_NETWORK_NAME

# Check VM network interface
task vm:exec -- mailu -- ip addr

# Verify physical interface exists on host
incus network list $INCUS_REMOTE_NAME:
```

### Mailu Deployment Issues

If you encounter issues deploying Mailu:

1. Verify Docker is running: `docker ps`
2. Check disk space: `df -h`
3. Review Mailu logs: `docker compose logs` (in `/mailu` directory)
4. See the [Mailu Email Server](../mailu/mailu.md) runbook troubleshooting section

## Summary

This runbook has guided you through:

1. ✅ Setting up SOPS secrets for Mailu configuration
2. ✅ Configuring environment variables using standard `VM_*` variables
3. ✅ Configuring direct network attachment for the VM
4. ✅ Creating the Ubuntu VM using the standard `vm:` task namespace
5. ✅ Getting the VM's DHCP-assigned IP address
6. ✅ Accessing the VM (Docker and SSH are already configured)
7. ✅ Deploying Mailu on the VM (via the Mailu runbook)
8. ✅ Configuring DNS records for email delivery

You now have a Mailu email server running in an isolated VM on your IncusOS infrastructure, managed using the standard VM workflow, with full control over both the email server and the underlying VM.

## Next Steps

- Follow the [Mailu Email Server](../mailu/mailu.md) runbook for ongoing Mailu management
- Set up regular backups of both the VM and Mailu data
- Monitor email delivery and server health
- Configure additional email domains and users as needed

## Related Runbooks

- [IncusOS Setup](setup.md): Initial IncusOS server installation
- [Mailu Email Server](../mailu/mailu.md): Complete Mailu deployment and management guide
- [Talos Kubernetes Cluster](tc.md): Another example of Terraform-based VM deployment
- [Ubuntu Virtual Machines](vm.md): Creating VMs for development, CI/CD runners, or other workloads (similar process)

## Additional Resources

- [Terraform Incus Provider Documentation](https://registry.terraform.io/providers/lxc/incus/latest/docs)
- [Mailu Documentation](https://mailu.io/2024.06/)

