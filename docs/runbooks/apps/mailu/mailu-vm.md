---
title: "Mailu Email Server on IncusOS VM"
description: "Complete guide for deploying Mailu email server on an Ubuntu VM on IncusOS"
---
# Mailu Email Server on IncusOS VM

This runbook guides you through deploying a [Mailu](https://mailu.io/) email server on an Ubuntu virtual machine running on an IncusOS system. This runbook leverages the standard Ubuntu VM creation process (see [Ubuntu Virtual Machines](../../incusos/vm.md)) and adds Mailu-specific configuration and deployment.

## Overview

Deploying Mailu on an IncusOS VM involves:

- Creating a standard Ubuntu VM using the `vm:` task namespace
- Configuring Mailu-specific secrets using SOPS
- Deploying Mailu using Docker Compose on the VM
- Configuring DNS records for email delivery
- Managing the Mailu server and VM lifecycle

This approach uses the standard VM creation workflow, making it consistent with other VM deployments while adding Mailu-specific configuration.

## Prerequisites

- IncusOS server installed and running (see [IncusOS Server](../../incusos/server.md))
- Incus CLI client installed on your local machine
- Remote connection to your IncusOS server configured
- Workspace initialized and context set (see [Initialize Workspace](../../workspace/init.md))
- Domain name with DNS access
- Network access for the VM to reach the internet (for Let's Encrypt certificates)
- Email ports open (25, 587, 465, 993, 143, 80, 443)
- Sufficient resources: At least 4GB RAM and 40GB storage on the IncusOS host for the VM

## Step 1: Install Tools

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
- `<your-generated-secret-key>`: The random hex string you generated in Step 2.1
- `<your-admin-password>`: The secure password you chose in Step 2.2

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

**Note**: For more details on managing secrets with SOPS, see the [Managing Secrets with SOPS](../../secrets/secrets.md) runbook.

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
  # Then replace the values below, or use sops if configured.
  # If using sops, replace the values below with:
  #   MAILU_SECRET_KEY: sops.MAILU_SECRET_KEY
  #   MAILU_INITIAL_ADMIN_PW: sops.MAILU_INITIAL_ADMIN_PW
  # Default values shown below:
  MAILU_SECRET_KEY: "<secret-key>"
  MAILU_INITIAL_ADMIN_PW: "<admin-password>"
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

## Step 5: Create the Ubuntu VM

Create the Ubuntu VM using the standard VM creation workflow:

```bash
task vm:instantiate -- <remote-name> [<vm-name>] [--keep] --name mailu
```

Or if you've set `VM_INSTANCE_NAME: mailu` in your environment variables:

```bash
task vm:instantiate -- <remote-name> [<vm-name>] [--keep]
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

# Check VM status and get IP
incus info $INCUS_REMOTE_NAME:mailu
incus list $INCUS_REMOTE_NAME:mailu --format csv -c n,4

# Verify Docker is installed
incus exec $INCUS_REMOTE_NAME:mailu -- docker --version
```

## Step 6: Get the VM IP Address

After the VM boots and receives its DHCP-assigned IP address, get the IP address:

```bash
# List VM and IPv4
incus list $INCUS_REMOTE_NAME:mailu --format csv -c n,4

# Or get detailed information
incus info $INCUS_REMOTE_NAME:mailu
```

**Note**: With direct network attachment, the VM gets an IP address from your DHCP server. Note this IP address as you'll need it for DNS configuration and SSH access.

## Step 7: Access the VM

You can access the VM in several ways:

#### Option 1: Direct SSH Access

Since the VM has a direct IP address on your local network, you can SSH directly:

```bash
# Get VM IP from Incus (format: name,IPv4)
VM_IP=$(incus list $INCUS_REMOTE_NAME:mailu --format csv -c 4 | tail -1)

# SSH directly to the VM (using your host username)
ssh <username>@${VM_IP}
```

#### Option 2: Interactive Shell via Incus

Open an interactive bash shell via Incus:

```bash
incus exec $INCUS_REMOTE_NAME:mailu -- bash
```

#### Option 3: Execute Commands Directly

Run specific commands without entering an interactive shell:

```bash
incus exec $INCUS_REMOTE_NAME:mailu -- docker --version
incus exec $INCUS_REMOTE_NAME:mailu -- docker compose version
```

**Note**: The VM created with `task vm:instantiate -- <remote-name> [<vm-name>] [--keep]` already has Docker installed and SSH configured. Your SSH keys are already copied, so you can SSH directly without additional setup.

## Step 8: Deploy Mailu

Now that your Ubuntu VM is set up with Docker, follow the [Mailu Email Server](mailu.md) runbook to deploy Mailu on the VM.

**Important Notes for Deploying Mailu on the VM:**

1. **SSH to the VM**: Get the VM IP from `incus list $INCUS_REMOTE_NAME:mailu`, then `ssh <username>@<vm-ip>`
2. **Use the VM's IP address**: When configuring DNS records, use the VM's IP address (not the IncusOS host IP)
3. **VM has direct network access**: The VM gets its IP from DHCP, so it's directly accessible on your network
4. **Port forwarding not needed**: Since the VM has direct network access, you don't need to set up port forwarding
5. **Docker is already installed**: The VM created with `task vm:instantiate -- <remote-name> [<vm-name>] [--keep]` already has Docker and Docker Compose installed

### Quick Start for Mailu Deployment

On the VM, create a directory for Mailu and follow the Mailu runbook:

```bash
# SSH to the VM (get IP from: incus list $INCUS_REMOTE_NAME:mailu)
ssh <username>@<vm-ip>

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

**Note**: For detailed instructions, see the [Mailu Email Server](mailu.md) runbook. The VM is now ready for Mailu deployment, and you can follow that runbook starting from Step 3 (Configure DNS Records).

## Step 9: Configure DNS Records

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

After Mailu is deployed, you'll need to add SPF, DKIM, and DMARC records. These will be shown in the Mailu admin interface after deployment. See Step 9 in the [Mailu Email Server](mailu.md) runbook for details.

## Step 10: Verify Mailu Deployment

After deploying Mailu following the Mailu runbook, verify that everything is working:

### Check Mailu Services

SSH to the VM and check Mailu services:

```bash
# SSH to the VM (get IP from: incus list $INCUS_REMOTE_NAME:mailu)
ssh <username>@<vm-ip>

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
# Via SSH: get IP from incus list $INCUS_REMOTE_NAME:mailu, then ssh <username>@<vm-ip>
# Via Incus shell
incus exec $INCUS_REMOTE_NAME:mailu -- bash
```

### Manage Mailu

Follow the [Mailu Email Server](mailu.md) runbook for ongoing Mailu management. From the workspace (with mailu taskfile): `task mailu:update`, `task mailu:backup`, `task mailu:start`, `task mailu:stop`, etc.

### VM Management

```bash
# List VMs
task vm:list

# Start/stop/restart VM (Incus)
incus start $INCUS_REMOTE_NAME:mailu
incus stop $INCUS_REMOTE_NAME:mailu
incus restart $INCUS_REMOTE_NAME:mailu

# Destroy VM (Terraform)
task vm:destroy -- mailu
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
task vm:destroy -- mailu
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
- **Recreation**: To recreate the VM, simply run `task vm:instantiate -- <remote-name> [<vm-name>] [--keep] --name mailu` again.

## Troubleshooting

### VM Creation Fails

- **VM not booting**: Verify the Ubuntu image is available: `incus image list ${INCUS_REMOTE_NAME}:`
- **Network issues**: Ensure the physical network is configured correctly (see [IncusOS Server](../../incusos/server.md) Step 8)
- **Provider errors**: Check that the Incus provider can connect to your remote: `incus list ${INCUS_REMOTE_NAME}:`

### VM Not Starting

If the VM fails to start:

```bash
# Check VM status
incus info $INCUS_REMOTE_NAME:mailu

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
incus exec $INCUS_REMOTE_NAME:mailu -- ip addr

# Verify physical interface exists on host
incus network list $INCUS_REMOTE_NAME:
```

### Mailu Deployment Issues

If you encounter issues deploying Mailu:

1. Verify Docker is running: `docker ps`
2. Check disk space: `df -h`
3. Review Mailu logs: `docker compose logs` (in `/mailu` directory)
4. See the [Mailu Email Server](mailu.md) runbook troubleshooting section

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

- Follow the [Mailu Email Server](mailu.md) runbook for ongoing Mailu management
- Set up regular backups of both the VM and Mailu data
- Monitor email delivery and server health
- Configure additional email domains and users as needed

## Related Runbooks

- [IncusOS Server](../../incusos/server.md): Initial IncusOS server installation
- [Mailu Email Server](mailu.md): Complete Mailu deployment and management guide
- [Talos Kubernetes Cluster](../../incusos/tc.md): Another example of Terraform-based VM deployment
- [Ubuntu Virtual Machines](../../incusos/vm.md): Creating VMs for development, CI/CD runners, or other workloads (similar process)

## Additional Resources

- [Terraform Incus Provider Documentation](https://registry.terraform.io/providers/lxc/incus/latest/docs)
- [Mailu Documentation](https://mailu.io/2024.06/)


