---
title: "Mailu Email Server"
description: "Complete guide for deploying and managing a Mailu email server using Docker Compose"
---
# Mailu Email Server

This guide walks you through deploying and managing a [Mailu](https://mailu.io/) email server using Docker Compose. Mailu is a simple yet full-featured mail server as a set of Docker images, providing IMAP, SMTP, webmail, and administration features.

## Overview

Deploying a Mailu email server involves:

1. **Installing dependencies**: Setting up Docker and Docker Compose
2. **Preparing environment**: Creating directory structure and downloading configuration files
3. **Configuring DNS**: Setting up A records, MX records, reverse DNS, and security records
4. **Configuring Mailu**: Setting up mailu.env and docker-compose.yml files
5. **Starting services**: Launching Mailu using Docker Compose
6. **Creating admin account**: Setting up the initial administrator account
7. **Post-deployment configuration**: Configuring SPF, DKIM, and DMARC records
8. **Managing the server**: Ongoing maintenance and updates

This approach provides you with a self-hosted email server with full control over your email infrastructure, including webmail access, user management, and security features.

## Prerequisites

- Server with root or sudo access
- Domain name with DNS access
- Docker and Docker Compose v2 installed
- Network access to the internet (for Let's Encrypt certificates)
- Email ports open (25, 587, 465, 993, 143)

## System Requirements

### Hardware Requirements

- **With antivirus (ClamAV)**: Minimum 3GB RAM, 1GB swap
- **Without antivirus**: Minimum 1GB RAM, 1GB swap
- **Storage**: At least 20GB for mail storage (more recommended for production)

### Software Requirements

- **Operating System**: Linux (Debian stable recommended)
- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later

### Network Requirements

- **Ports to open**:
  - `25` (SMTP)
  - `587` (SMTP Submission)
  - `465` (SMTPS)
  - `993` (IMAPS)
  - `143` (IMAP)
  - `80` (HTTP - for Let's Encrypt)
  - `443` (HTTPS - for webmail and admin)

**Note**: Check with your hosting provider if port 25 is blocked. Some residential ISPs block port 25.

## Step 1: Install Tools Dependencies

To fully leverage the Windsor environment and manage your Mailu deployment, you will need several tools installed on your system. You may install these tools manually or using your preferred tools manager (_e.g._ Homebrew). The Windsor project recommends [aqua](https://aquaproj.github.io/).

Ensure your `aqua.yaml` includes the following packages required for this runbook. Add any missing packages to your existing `aqua.yaml`:

```yaml
packages:
- name: docker/cli@v27.4.1
- name: docker/compose@v2.32.1
```

Install the tools, run in the workspace root folder:

```bash
aqua install
```

## Step 2: Install Docker and Docker Compose

If Docker and Docker Compose are not already installed on your server, install them:

### Install Docker

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
docker compose version
```

**Note**: For Debian or other distributions, adjust the repository URL accordingly. See the [official Docker installation guide](https://docs.docker.com/engine/install/) for details.

## Step 3: Configure DNS Records

Before deploying Mailu, you need to configure DNS records for your domain. These records are critical for email delivery and security.

### Mail Server Hostname

Choose a fully qualified domain name (FQDN) for your mail server, e.g., `mail.example.com`. Create an A record pointing to your server's IP address:

```
mail.example.com. IN A <your-server-ip>
```

### MX Records

For each domain you want to handle email for, add an MX record pointing to your mail server hostname:

```
example.com. IN MX 10 mail.example.com.
```

**Note**: The number (10) is the priority. Lower numbers have higher priority. Multiple MX records can be used for redundancy.

### Reverse DNS (PTR Record)

Configure a reverse DNS (PTR) record for your server's IP address. This should resolve back to your mail server hostname:

```
<your-server-ip> IN PTR mail.example.com.
```

**Note**: This is typically configured through your hosting provider or ISP. Contact them to set up reverse DNS.

### SPF Record (After Deployment)

After Mailu is deployed, you'll need to add SPF records. These will be shown in the Mailu admin interface. Generally, the format is:

```
example.com. IN TXT "v=spf1 mx a:mail.example.com ~all"
```

### DKIM Record (After Deployment)

DKIM records are automatically generated by Mailu. After deployment, retrieve the DKIM public key from the Mailu admin interface and add it as a TXT record:

```
mail._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=<public-key>"
```

### DMARC Record (Optional but Recommended)

Add a DMARC policy record:

```
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
```

**Note**: Adjust the policy (`p=none`, `p=quarantine`, or `p=reject`) based on your needs.

## Step 4: Set Environment Variables

Configure the environment variables for your Mailu deployment. Add these lines to `./contexts/mailu/windsor.yaml`:

```text
environment:
  # Mailu configuration
  MAILU_DOMAIN: "example.com"
  MAILU_HOSTNAME: "mail.example.com"
  # Generate random strings if sops values are not available:
  #   openssl rand -hex 32    # For MAILU_SECRET_KEY
  #   openssl rand -base64 24 # For MAILU_INITIAL_ADMIN_PW
  # Or use sops if configured.
  # If using sops, replace the values below with:
  #   MAILU_SECRET_KEY: sops.MAILU_SECRET_KEY
  #   MAILU_INITIAL_ADMIN_PW: sops.MAILU_INITIAL_ADMIN_PW
  # Default values shown below:
  MAILU_SECRET_KEY: "1b57fc851a92796b0743c4fa778d62b8310f47b275498cd5747685a6f2d81162"
  MAILU_SUBNET: "192.168.203.0/24"
  MAILU_DB_FLAVOR: "sqlite"
  MAILU_TLS_FLAVOR: "letsencrypt"
  
  # Admin account (optional - can be set in mailu.env)
  MAILU_INITIAL_ADMIN_ACCOUNT: "admin"
  MAILU_INITIAL_ADMIN_DOMAIN: "example.com"
  MAILU_INITIAL_ADMIN_PW: "TUbV2j3Z/Frm+MoxkszQsOKCj44jj08M"
  MAILU_INITIAL_ADMIN_MODE: "ifmissing"
```

**Environment Variables:**

- `MAILU_DOMAIN`: The primary domain for your mail server
- `MAILU_HOSTNAME`: The FQDN of your mail server (must match DNS A record)
- `MAILU_SECRET_KEY`: Secret key for Mailu (generate a random string)
- `MAILU_SUBNET`: Docker network subnet (change if conflicts with your network)
- `MAILU_DB_FLAVOR`: Database backend (`sqlite`, `mysql`, or `postgresql`)
- `MAILU_TLS_FLAVOR`: TLS certificate method (`letsencrypt`, `cert`, or `notls`)
- `MAILU_INITIAL_ADMIN_ACCOUNT`: Initial admin username
- `MAILU_INITIAL_ADMIN_DOMAIN`: Domain for initial admin account
- `MAILU_INITIAL_ADMIN_PW`: Password for initial admin account
- `MAILU_INITIAL_ADMIN_MODE`: When to create admin (`ifmissing`, `always`, or `never`)

**Note**: For production deployments, use `mysql` or `postgresql` instead of `sqlite`. For secrets, use SOPS to encrypt sensitive values. See the [Secrets Management](../secrets/secrets.md) runbook for details.

## Step 5: Generate Configuration Files

Mailu provides a setup utility to generate `docker-compose.yml` and `mailu.env` files. Use the Mailu setup utility:

1. **Visit the Mailu setup utility**: [https://setup.mailu.io/](https://setup.mailu.io/)

2. **Fill in the configuration**:
   - Choose Mailu version (e.g., `2.0`)
   - Select deployment method (`docker-compose`)
   - Enter your mail server hostname
   - Select database backend (sqlite for small deployments, mysql/postgresql for production)
   - Configure storage paths
   - Select TLS flavor (Let's Encrypt recommended)
   - Configure other options as needed

3. **Download the files**:
   - Download `docker-compose.yml`
   - Download `mailu.env`

4. **Save the files**:
   - Place `docker-compose.yml` in `contexts/mailu/`
   - Place `mailu.env` in `contexts/mailu/`

Alternatively, use the Mailu taskfile to generate the configuration:

```bash
task mailu:setup
```

**Note**: The setup utility generates production-ready configuration files. Review the generated files and adjust as needed.

## Step 6: Customize Configuration

Edit the `mailu.env` file to customize your Mailu configuration:

### Essential Settings

- `SECRET_KEY`: Random secret key (generate using `openssl rand -hex 16`)
- `DOMAIN`: Your primary domain
- `HOSTNAME`: Your mail server hostname
- `TLS_FLAVOR`: Set to `letsencrypt` for automatic certificates

### Database Configuration (if using MySQL or PostgreSQL)

If using MySQL or PostgreSQL instead of SQLite:

```env
DB_FLAVOR=mysql
DB_HOST=db
DB_USER=mailu
DB_PW=your-db-password
DB_NAME=mailu
```

### Admin Account (Alternative to Environment Variables)

You can set the initial admin account in `mailu.env`:

```env
INITIAL_ADMIN_ACCOUNT=admin
INITIAL_ADMIN_DOMAIN=example.com
INITIAL_ADMIN_PW=your-secure-password
INITIAL_ADMIN_MODE=ifmissing
```

**Note**: Review all settings in `mailu.env` and adjust according to your needs. See the [Mailu configuration reference](https://mailu.io/2024.06/compose/config.html) for all available options.

## Step 7: Start Mailu

Start the Mailu services using Docker Compose:

```bash
cd contexts/mailu
docker compose up -d
```

Or use the Mailu taskfile:

```bash
task mailu:start
```

**What it does:**

1. Downloads required Docker images
2. Creates Docker networks and volumes
3. Starts all Mailu services (front, admin, imap, smtp, etc.)
4. Configures TLS certificates (if using Let's Encrypt)

**Note**: The first startup may take several minutes as images are downloaded and services are initialized.

### Verify Services are Running

Check the status of Mailu services:

```bash
docker compose ps
```

Or use the taskfile:

```bash
task mailu:status
```

All services should show as "Up" or "Up (healthy)".

### Check Logs

View Mailu logs to monitor startup and troubleshoot issues:

```bash
docker compose logs -f
```

Or view logs for a specific service:

```bash
docker compose logs -f admin
docker compose logs -f front
```

## Step 8: Create Admin Account

If you didn't set `INITIAL_ADMIN_ACCOUNT` in `mailu.env`, create an admin account manually:

```bash
docker compose exec admin flask mailu admin <username> <domain> '<password>'
```

Replace:
- `<username>`: Admin username (e.g., `admin`)
- `<domain>`: Domain for the admin account (e.g., `example.com`)
- `<password>`: Admin password

**Example:**

```bash
docker compose exec admin flask mailu admin admin example.com 'SecurePassword123!'
```

Or use the taskfile:

```bash
task mailu:create-admin
```

**Note**: After creating the admin account, you can log in to the Mailu admin interface at `https://mail.example.com/admin/`.

## Step 9: Configure Security Records (SPF, DKIM, DMARC)

After Mailu is running, configure SPF, DKIM, and DMARC records in your DNS:

### Access Mailu Admin Interface

1. Navigate to `https://mail.example.com/admin/`
2. Log in with your admin account
3. Go to **Mail domains** → Select your domain

### Get SPF Record

The SPF record is typically:

```
example.com. IN TXT "v=spf1 mx a:mail.example.com ~all"
```

Add this as a TXT record in your DNS.

### Get DKIM Record

1. In the Mailu admin interface, go to your domain
2. Find the **DKIM keys** section
3. Copy the public key
4. Add it as a TXT record:

```
mail._domainkey.example.com. IN TXT "v=DKIM1; k=rsa; p=<public-key>"
```

### Add DMARC Record

Add a DMARC policy record:

```
_dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
```

**Note**: Adjust the policy based on your needs:
- `p=none`: Monitor only
- `p=quarantine`: Quarantine suspicious emails
- `p=reject`: Reject suspicious emails

## Step 10: Verify Email Delivery

Test that your Mailu server is working correctly:

### Send Test Email

1. Log in to the Mailu webmail interface at `https://mail.example.com/webmail/`
2. Send a test email to an external email address (e.g., Gmail, Outlook)
3. Check that the email is received

### Receive Test Email

1. Send an email from an external email address to an address on your domain
2. Check the Mailu webmail interface to verify the email was received

### Check DNS Records

Use online tools to verify your DNS records:

- [MXToolbox](https://mxtoolbox.com/): Check MX, SPF, DKIM, DMARC records
- [Mail-Tester](https://www.mail-tester.com/): Test email deliverability

### Check for Open Relay

Verify that your server is not configured as an open relay:

```bash
# Test from external server
telnet mail.example.com 25
EHLO test.com
MAIL FROM: <test@test.com>
RCPT TO: <external@example.com>
QUIT
```

Your server should reject emails from external domains that aren't authorized.

## Ongoing Management

### Update Mailu

To update Mailu to a newer version:

1. Update the Mailu version in your configuration
2. Pull new images:

```bash
docker compose pull
```

3. Restart services:

```bash
docker compose up -d
```

Or use the taskfile:

```bash
task mailu:update
```

### Backup Mailu Data

Backup important Mailu data:

```bash
# Backup mail data
docker compose exec -T admin tar czf - /data/mail > mail-backup-$(date +%Y%m%d).tar.gz

# Backup configuration
cp mailu.env mailu.env.backup-$(date +%Y%m%d)
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d)
```

Or use the taskfile:

```bash
task mailu:backup
```

### Monitor Mailu

Monitor Mailu services and logs:

```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f

# Check disk usage
docker compose exec admin df -h
```

### Manage Users and Domains

Use the Mailu admin interface to:

- Create and manage email accounts
- Add and manage domains
- Configure aliases and forwards
- Set up auto-reply and auto-forward rules
- Manage quotas and limits
- Configure spam filtering

## Troubleshooting

### Services Not Starting

Check logs for errors:

```bash
docker compose logs
```

Common issues:
- Port conflicts: Ensure ports 25, 587, 465, 993, 143, 80, 443 are not in use
- DNS resolution: Verify hostname resolves correctly
- Permissions: Ensure Docker has proper permissions

### Email Delivery Issues

- **Check DNS records**: Verify MX, SPF, DKIM, DMARC records are correct
- **Check firewall**: Ensure email ports are open
- **Check logs**: Review SMTP logs for delivery errors
- **Check blacklists**: Verify your IP is not blacklisted

### Certificate Issues

If using Let's Encrypt:
- Verify port 80 is open (required for validation)
- Check DNS A record points to your server
- Review Let's Encrypt logs: `docker compose logs front`

## Additional Resources

- [Mailu Documentation](https://mailu.io/2024.06/)
- [Mailu Setup Utility](https://setup.mailu.io/)
- [Mailu GitHub Repository](https://github.com/Mailu/Mailu)
- [Mailu Community Support](https://mailu.io/contributors.html#support)

