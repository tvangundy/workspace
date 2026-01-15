---
title: "Application Deployment Runbooks"
description: "Complete guides for deploying self-hosted applications and services"
---
# Application Deployment Runbooks

Step-by-step guides for deploying self-hosted applications and services. These runbooks cover end-to-end deployment workflows, from initial setup through ongoing management.

## Overview

These runbooks focus on deploying specific applications and services. Each runbook provides a complete, self-contained guide that includes:

- Prerequisites and dependencies
- Configuration and setup
- Deployment procedures
- Ongoing management and maintenance
- Troubleshooting guidance

## Available Application Runbooks

### 🏠 [Home Assistant](home-assistant/README.md)
Complete guide for deploying a home automation platform on Raspberry Pi. Home Assistant is a powerful open-source home automation platform that puts local control and privacy first. This runbook covers workspace initialization, Windsor CLI configuration, Kubernetes deployment, and service management.

### 📧 [Mailu Email Server](mailu/mailu.md)
Deploy and manage a Mailu email server using Docker Compose. Covers Docker and Docker Compose installation, DNS configuration (MX records, SPF, DKIM, DMARC), Mailu setup and configuration, service management, admin account creation, security configuration, and ongoing maintenance. Provides a self-hosted email server with webmail, IMAP, SMTP, and administration features.

### 📧 [Mailu Email Server on VM](mailu/mailu-vm.md)
Deploy a Mailu email server on an Ubuntu virtual machine on an IncusOS system. Ties together IncusOS setup, VM creation, Docker installation, and Mailu deployment into a complete workflow. Includes Ubuntu VM creation with direct network access, Docker and Docker Compose installation, Mailu deployment configuration, DNS setup, and ongoing VM and Mailu management.

### 🏃 [Self-Hosted GitHub Actions Runners](runners/)
Step-by-step guides for setting up GitHub Actions runners on various platforms:

- **[VM Runner Setup](runners/vm-runner-setup.md)**: Deploy a GitHub Actions runner on an Ubuntu VM running on IncusOS. Leverages the standard VM creation workflow for consistent, manageable runner deployments. Recommended for most use cases.
- **[Bare Metal Runner Setup](runners/bare-metal-runner-setup.md)**: Set up Ubuntu-based GitHub Actions runners on bare metal Raspberry Pi (ARM64) or Intel NUC (x86_64) devices. Covers Ubuntu Server installation, post-installation configuration, and runner setup.

## Getting Started

1. **Choose an application**: Select the application runbook that matches your needs
2. **Review prerequisites**: Each runbook lists specific requirements and dependencies
3. **Follow step-by-step**: Complete each step in order, as they build upon each other
4. **Customize as needed**: Adapt the deployment to your specific environment and requirements

## Common Prerequisites

Most application runbooks require:

- **Workspace initialized**: Follow the [Initialize Workspace](../../workspace/init.md) runbook if you haven't already
- **Secrets management**: Configure encrypted secrets using [SOPS](../../secrets/secrets.md) for sensitive configuration
- **Windsor CLI**: Installed and configured on your local machine
- **Network access**: Proper network configuration for the application to function

## Additional Resources

- [Windsor CLI Documentation](https://windsorcli.github.io/latest/)
- [Application Documentation](#) - Links to official application documentation

