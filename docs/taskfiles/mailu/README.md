---
title: "Mailu Tasks"
description: "Mailu email server deployment and management tasks for Docker Compose deployments"
---
# Mailu Tasks (`mailu:`)

Mailu email server deployment and management using Docker Compose.

## Overview

The `mailu:` namespace provides tools for deploying and managing a Mailu email server using Docker Compose. These tasks handle configuration setup, service lifecycle management, admin account creation, updates, backups, and troubleshooting.

## Task Reference

| Task | Description |
|------|-------------|
| [`setup`](#setup) | Generate Mailu configuration files using the setup utility |
| [`start`](#start) | Start Mailu services |
| [`stop`](#stop) | Stop Mailu services |
| [`restart`](#restart) | Restart Mailu services |
| [`status`](#status) | Check Mailu service status |
| [`logs`](#logs) | View Mailu logs (optionally follow logs) |
| [`create-admin`](#create-admin) | Create Mailu admin account |
| [`update`](#update) | Update Mailu to latest version |
| [`backup`](#backup) | Backup Mailu data and configuration |
| [`down`](#down) | Stop and remove Mailu services (keeps data) |
| [`shell`](#shell) | Open shell in Mailu admin container |

## Configuration Setup

### `setup`

Generate Mailu configuration files using the setup utility.

**Usage:**

```bash
task mailu:setup
```

**What it does:**

1. Creates the Mailu directory structure (`contexts/<context>/`)
2. Provides instructions for using the Mailu setup utility
3. Prompts to download `docker-compose.yml` and `mailu.env` files

**Example:**

```bash
task mailu:setup
```

**Note:** Visit [https://setup.mailu.io/](https://setup.mailu.io/) to generate your configuration files. After downloading the files, place them in `contexts/<context>/` and run `task mailu:start`.

## Service Management

### `start`

Start Mailu services.

**Usage:**

```bash
task mailu:start
```

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Starts all Mailu services using Docker Compose
3. Runs services in detached mode

**Example:**

```bash
task mailu:start
```

**Output:** Shows startup status and provides commands to check status and view logs.

### `stop`

Stop Mailu services.

**Usage:**

```bash
task mailu:stop
```

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Stops all Mailu services (containers remain, but stopped)

**Example:**

```bash
task mailu:stop
```

**Note:** Services can be restarted with `task mailu:start` without losing data (data is stored in Docker volumes).

### `restart`

Restart Mailu services.

**Usage:**

```bash
task mailu:restart
```

**What it does:**

1. Stops Mailu services (`task mailu:stop`)
2. Starts Mailu services (`task mailu:start`)

**Example:**

```bash
task mailu:restart
```

**Note:** This is useful for applying configuration changes or troubleshooting.

### `status`

Check Mailu service status.

**Usage:**

```bash
task mailu:status
```

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Shows status of all Mailu services (running, stopped, health status)

**Example:**

```bash
task mailu:status
```

**Output:** Shows service status, ports, and health status for all Mailu containers.

### `logs`

View Mailu logs.

**Usage:**

```bash
# View last 100 lines
task mailu:logs

# Follow logs (real-time)
task mailu:logs -- follow
```

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Shows logs from all Mailu services
3. If `follow` is specified, follows logs in real-time

**Example:**

```bash
# View recent logs
task mailu:logs

# Follow logs
task mailu:logs -- follow
```

**Note:** Press Ctrl+C to exit when following logs.

## Admin Management

### `create-admin`

Create Mailu admin account.

**Usage:**

```bash
task mailu:create-admin -- <username> <domain> <password>
```

**Parameters:**

- `<username>`: Admin username (e.g., `admin`)
- `<domain>`: Domain for the admin account (e.g., `example.com`)
- `<password>`: Admin password (must be quoted if contains special characters)

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Creates admin account using Mailu's admin CLI
3. Sets up the administrator account for the web interface

**Example:**

```bash
task mailu:create-admin -- admin example.com 'SecurePassword123!'
```

**Note:** After creating the admin account, you can log in to the Mailu admin interface at `https://mail.example.com/admin/`.

## Maintenance

### `update`

Update Mailu to latest version.

**Usage:**

```bash
task mailu:update
```

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Pulls latest Docker images
3. Restarts services with new images

**Example:**

```bash
task mailu:update
```

**Note:** Before updating, review the [Mailu release notes](https://mailu.io/2024.06/releases.html) for breaking changes. Consider backing up your data first using `task mailu:backup`.

### `backup`

Backup Mailu data and configuration.

**Usage:**

```bash
task mailu:backup
```

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Creates backup directory (`contexts/<context>/backups/`)
3. Backs up mail data from the admin container
4. Backs up configuration files (`docker-compose.yml`, `mailu.env`)

**Example:**

```bash
task mailu:backup
```

**Output:** Creates timestamped backup files:
- `mailu-backup-YYYYMMDD-HHMMSS.tar.gz`: Mail data
- `mailu-config-YYYYMMDD-HHMMSS.tar.gz`: Configuration files

**Note:** Backups are stored in `contexts/<context>/backups/`. Store backups in a secure location outside the server.

### `down`

Stop and remove Mailu services (keeps data).

**Usage:**

```bash
task mailu:down
```

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Waits 5 seconds for cancellation
3. Stops and removes Mailu containers
4. Preserves data in Docker volumes

**Example:**

```bash
task mailu:down
```

**Warning:** This removes containers but preserves data in Docker volumes. To completely remove Mailu, you would need to remove volumes separately (not recommended unless you're sure you want to delete all data).

**Note:** Use this when you need to completely stop Mailu and remove containers. Data in volumes is preserved and will be available when you restart with `task mailu:start`.

## Utilities

### `shell`

Open shell in Mailu admin container.

**Usage:**

```bash
task mailu:shell
```

**What it does:**

1. Verifies `docker-compose.yml` exists
2. Opens an interactive bash shell in the admin container

**Example:**

```bash
task mailu:shell
```

**Note:** This is useful for troubleshooting, running Mailu CLI commands, or inspecting the container. Type `exit` to leave the shell.

## Environment Variables

The following environment variables are used:

- `WINDSOR_PROJECT_ROOT`: Windsor project root directory (auto-detected)
- `WINDSOR_CONTEXT`: Windsor context name (default: `mailu`)

**Taskfile Variables:**

- `MAILU_DIR`: Path to Mailu directory (`contexts/<context>/`)
- `COMPOSE_FILE`: Path to docker-compose.yml file
- `MAILU_ENV`: Path to mailu.env file

## Prerequisites

- Docker installed and running
- Docker Compose v2 installed
- Mailu configuration files (`docker-compose.yml` and `mailu.env`) generated from [setup.mailu.io](https://setup.mailu.io/)
- Network access to the internet (for Let's Encrypt certificates)
- Email ports open (25, 587, 465, 993, 143, 80, 443)

## Workflow Example

Complete Mailu deployment workflow:

```bash
# 1. Generate configuration files
task mailu:setup
# Visit https://setup.mailu.io/ to download docker-compose.yml and mailu.env
# Save files to contexts/mailu/

# 2. Start Mailu services
task mailu:start

# 3. Check service status
task mailu:status

# 4. View logs to verify startup
task mailu:logs

# 5. Create admin account
task mailu:create-admin -- admin example.com 'SecurePassword123!'

# 6. Access admin interface at https://mail.example.com/admin/
```

## Help

View all available Mailu commands:

```bash
task mailu:help
```

## Taskfile Location

Task definitions are located in `tasks/mailu/Taskfile.yaml`.

