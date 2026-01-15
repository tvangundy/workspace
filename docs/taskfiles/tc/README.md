---
title: "TC Tasks"
description: "Talos Kubernetes cluster management tasks for creating and managing three-node Talos clusters on Incus using Terraform"
---
# TC Tasks (`tc:`)

Talos Kubernetes cluster management for creating and managing three-node Talos Linux clusters on Incus using Terraform.

## Overview

The `tc:` namespace provides comprehensive tools for creating, managing, and interacting with Talos Kubernetes clusters running on Incus. These tasks use Terraform for infrastructure-as-code management and handle cluster lifecycle, node management, health checks, and cluster validation.

## Task Reference

| Task | Description |
|------|-------------|
| [`create`](#create) | Create a three-node Talos Kubernetes cluster using Terraform |
| [`create:validate`](#createvalidate) | Validate input and check prerequisites for cluster creation |
| [`generate-tfvars`](#generate-tfvars) | Generate terraform.tfvars from environment variables |
| [`terraform:init`](#terraforminit) | Initialize Terraform for the cluster |
| [`terraform:plan`](#terraformplan) | Show Terraform plan for the cluster |
| [`terraform:apply`](#terraformapply) | Apply Terraform configuration to create the cluster |
| [`terraform:destroy`](#terraformdestroy) | Destroy the cluster using Terraform |
| [`list`](#list) | List all cluster VMs |
| [`info`](#info) | Get detailed information about the cluster |
| [`console`](#console) | Access VM console |
| [`start`](#start) | Start all cluster VMs |
| [`stop`](#stop) | Stop all cluster VMs |
| [`restart`](#restart) | Restart all cluster VMs |
| [`destroy`](#destroy) | Destroy the Talos cluster using Terraform |
| [`health-controlplane`](#health-controlplane) | Health check the control plane node |
| [`health-worker`](#health-worker) | Health check all worker nodes |
| [`health-worker-0`](#health-worker-0) | Health check worker-0 |
| [`health-worker-1`](#health-worker-1) | Health check worker-1 |
| [`test`](#test) | Test cluster setup by running through all runbook steps and validating the cluster |

## Cluster Creation

### `create`

Create a three-node Talos Kubernetes cluster using Terraform.

**Usage:**

```bash
task tc:create
```

**What it does:**

1. Validates prerequisites and environment variables
2. Generates `terraform.tfvars` from environment variables
3. Initializes Terraform
4. Applies Terraform configuration to create 3 VMs:
   - 1 control plane node
   - 2 worker nodes
5. Displays cluster information including VM names and IP addresses

**Note:** After creation, you need to:
1. Wait for VMs to boot and get DHCP-assigned IP addresses
2. Get actual IP addresses from Terraform outputs
3. Update `windsor.yaml` with actual IPs
4. Regenerate `terraform.tfvars` and continue deployment

### `create:validate`

Validate input and check prerequisites for cluster creation. This is automatically called by `create` but can be run independently.

**Usage:**

```bash
task tc:create:validate
```

## Terraform Operations

### `generate-tfvars`

Generate `terraform.tfvars` from environment variables.

**Usage:**

```bash
task tc:generate-tfvars
```

**What it does:**

1. Reads environment variables from Windsor context
2. Generates `terraform/cluster/terraform.tfvars`
3. Includes configuration for cluster resources, network, and storage

**Note:** The generated file is automatically created and should not be edited manually. Update environment variables in `contexts/<context>/windsor.yaml` instead.

### `terraform:init`

Initialize Terraform for the cluster.

**Usage:**

```bash
task tc:terraform:init
```

### `terraform:plan`

Show Terraform plan for the cluster.

**Usage:**

```bash
task tc:terraform:plan
```

### `terraform:apply`

Apply Terraform configuration to create the cluster.

**Usage:**

```bash
task tc:terraform:apply
```

### `terraform:destroy`

Destroy the cluster using Terraform.

**Usage:**

```bash
task tc:terraform:destroy
```

**Warning:** This permanently removes the cluster and all its data.

## Cluster Management

### `list`

List all cluster VMs on the configured remote.

**Usage:**

```bash
task tc:list
```

**Output:** Shows all cluster VMs (control plane and workers) with their status, IP addresses, and resource usage.

### `info`

Get detailed information about the cluster.

**Usage:**

```bash
task tc:info
```

**Output:** Shows cluster configuration, VM information, network details, and status.

### `console`

Access VM console for debugging and troubleshooting.

**Usage:**

```bash
task tc:console -- <vm-name>
```

**Parameters:**

- `<vm-name>` (required): VM name (e.g., `talos-cp`, `talos-worker-0`, `talos-worker-1`)

**Example:**

```bash
task tc:console -- talos-cp
```

**Note:** Press `Ctrl+A` then `Q` to exit the console.

### `start`

Start all cluster VMs.

**Usage:**

```bash
task tc:start
```

### `stop`

Stop all cluster VMs.

**Usage:**

```bash
task tc:stop
```

### `restart`

Restart all cluster VMs.

**Usage:**

```bash
task tc:restart
```

### `destroy`

Destroy the Talos cluster using Terraform.

**Usage:**

```bash
task tc:destroy
```

**Warning:** This permanently removes the cluster and all its data.

## Health Checks

### `health-controlplane`

Health check the control plane node.

**Usage:**

```bash
task tc:health-controlplane
```

**Requirements:**

- `CONTROL_PLANE_IP` environment variable must be set
- `TALOSCONFIG` environment variable must be set
- Control plane node must be bootstrapped

### `health-worker`

Health check all worker nodes.

**Usage:**

```bash
task tc:health-worker
```

**Requirements:**

- `CONTROL_PLANE_IP`, `WORKER_0_IP`, `WORKER_1_IP` environment variables must be set
- `TALOSCONFIG` environment variable must be set
- Control plane node must be bootstrapped

### `health-worker-0`

Health check worker-0.

**Usage:**

```bash
task tc:health-worker-0
```

**Requirements:**

- `CONTROL_PLANE_IP`, `WORKER_0_IP` environment variables must be set
- `TALOSCONFIG` environment variable must be set
- Control plane node must be bootstrapped

### `health-worker-1`

Health check worker-1.

**Usage:**

```bash
task tc:health-worker-1
```

**Requirements:**

- `CONTROL_PLANE_IP`, `WORKER_1_IP` environment variables must be set
- `TALOSCONFIG` environment variable must be set
- Control plane node must be bootstrapped

## Testing

### `test`

Test cluster setup by running through all runbook steps and validating the cluster. Use `--keep` to leave cluster running after test.

**Usage:**

```bash
task tc:test -- <incus-remote-name> [--keep]
```

**Parameters:**

- `<incus-remote-name>` (required): Incus remote name
- `--keep`, `--no-cleanup` (optional): Keep cluster running after test (default: delete cluster)

**What it does:**

1. Initializes Windsor context "test"
2. Validates remote connection
3. Generates terraform.tfvars
4. Ensures Talos image is available
5. Creates cluster VMs using Terraform
6. Waits for VMs to boot
7. Gets IP addresses (from Terraform outputs or prompts user)
8. Updates windsor.yaml with IP addresses
9. Continues Terraform deployment to configure Talos
10. Retrieves kubeconfig
11. Verifies and fixes kubeconfig
12. Validates cluster health using `talosctl health` and `kubectl get nodes`
13. Displays comprehensive cluster information
14. Optionally cleans up cluster (unless `--keep` is used)

**Examples:**

```bash
# Run full test suite (creates cluster, validates setup, then deletes it)
task tc:test -- nuc

# Keep cluster after test
task tc:test -- nuc --keep
```

## Environment Variables

The following environment variables can be set in your `contexts/<context>/windsor.yaml` configuration:

- `INCUS_REMOTE_NAME`: Incus remote name (required). Examples: `local`, `nuc`, `remote-server`
- `CLUSTER_NAME`: Cluster name. Default: `talos-cluster`
- `CONTROL_PLANE_VM`: Control plane VM name. Default: `talos-cp`
- `WORKER_0_VM`: Worker 0 VM name. Default: `talos-worker-0`
- `WORKER_1_VM`: Worker 1 VM name. Default: `talos-worker-1`
- `CONTROL_PLANE_IP`: Control plane node IP address (required after VMs are created)
- `WORKER_0_IP`: Worker 0 node IP address (required after VMs are created)
- `WORKER_1_IP`: Worker 1 node IP address (required after VMs are created)
- `TALOS_IMAGE_VERSION`: Talos image version. Default: `v1.12.0`
- `TALOS_IMAGE_ARCH`: Talos image architecture. Default: `metal-amd64`
- `PHYSICAL_INTERFACE`: Physical network interface for direct network access (e.g., `eno1`, `eth0`, `enp5s0`). Default: `eno1`
- `STORAGE_POOL`: Storage pool name. Default: `local`
- `CONTROL_PLANE_MEMORY`: Control plane VM memory allocation (e.g., `2GB`, `4GB`). Default: `2GB`
- `CONTROL_PLANE_CPU`: Control plane VM CPU count. Default: `2`
- `WORKER_MEMORY`: Worker VM memory allocation (e.g., `2GB`, `4GB`). Default: `2GB`
- `WORKER_CPU`: Worker VM CPU count. Default: `2`
- `TALOSCONFIG`: Path to Talos configuration file (required). Default: `contexts/<context>/.talos/talosconfig`
- `KUBECONFIG_FILE`: Path to Kubernetes kubeconfig file (required). Default: `contexts/<context>/.kube/config`

## Prerequisites

- Incus installed and configured
- Terraform installed
- Talos CLI (`talosctl`) installed
- Kubernetes CLI (`kubectl`) installed
- `INCUS_REMOTE_NAME` environment variable set
- For remote deployments: SSH access configured
- Physical network interface configured for direct network access (see runbook)

## Help

View all available tc commands:

```bash
task tc:help
```

## Taskfile Location

Task definitions are located in `tasks/tc/Taskfile.yaml`.

## Related Documentation

- [Talos Cluster Runbook](../../runbooks/incusos/tc.md) - Complete guide for creating and managing Talos clusters
- [Terraform Cluster Configuration](../../../terraform/cluster/) - Terraform module for Talos clusters

