---
title: "TC Tasks"
description: "Talos Kubernetes cluster management tasks for creating and managing three-node Talos clusters on Incus using Terraform"
---
# TC Tasks (`tc:`)

Talos Kubernetes cluster management for creating and managing three-node Talos Linux clusters on Incus using Terraform.

## Overview

The `tc:` namespace provides tasks for creating and managing Talos Kubernetes clusters on Incus. Use `task tc:instantiate` to create a cluster; use the **`talos:`** namespace for health checks and the **Incus** CLI for VM start/stop/restart/console.

## Task Reference

| Task | Description |
|------|-------------|
| [`instantiate`](#instantiate) | Create and bootstrap a three-node Talos Kubernetes cluster using Terraform |
| [`instantiate:parse-args`](#instantiateparse-args) | Parse CLI arguments for instantiate |
| [`instantiate:initialize-context`](#instantiateinitialize-context) | Initialize Windsor context and create windsor.yaml |
| [`instantiate:verify-remote`](#instantiateverify-remote) | Verify Incus remote exists and is reachable |
| [`instantiate:check-existing-vms`](#instantiatecheck-existing-vms) | Fail if cluster VMs already exist |
| [`instantiate:check-talos-image`](#instantiatecheck-talos-image) | Ensure Talos image is available (warn only) |
| [`instantiate:create-cluster-vms`](#instantiatecreate-cluster-vms) | Create cluster VMs via Terraform |
| [`instantiate:wait-for-vms`](#instantiatewait-for-vms) | Wait for all VMs to be running |
| [`instantiate:get-ip-addresses`](#instantiateget-ip-addresses) | Get IPs from Terraform, update windsor.yaml |
| [`instantiate:regenerate-tfvars-with-ips`](#instantiategenerate-tfvars-with-ips) | Regenerate tfvars with IPs and apply Talos config |
| [`instantiate:retrieve-kubeconfig`](#instantiateretrieve-kubeconfig) | Retrieve kubeconfig from cluster |
| [`instantiate:final-summary`](#instantiatefinal-summary) | Print success summary |
| [`instantiate:cleanup-if-needed`](#instantiatecleanup-if-needed) | Destroy cluster unless --keep was set |
| [`list`](#list) | List all cluster VMs |
| [`destroy`](#destroy) | Destroy the Talos cluster using Terraform |
| [`delete`](#delete) | Delete cluster VMs directly via Incus (bypasses Terraform) |
| [`help`](#help) | Show tc commands |

**Note:** Health checks are in the `talos:` namespace: `task talos:health-controlplane`, `task talos:health-worker`. Cluster VM start/stop/restart/console: use `incus start/stop/restart/console $INCUS_REMOTE_NAME:<vm-name>`.

## Cluster Creation

### `instantiate`

Create and bootstrap a three-node Talos Kubernetes cluster using Terraform. This is the primary way to create a new Talos cluster.

**Usage:**

```bash
task tc:instantiate -- <remote-name> <remote-ip> [<cluster-name>] [--destroy]
```

**Parameters:**

- `<remote-name>` (required): Name of the Incus remote (e.g., `nuc`, `local`)
- `<remote-ip>` (required): IP address of the Incus remote
- `<cluster-name>` (optional): Name for the cluster (default: `talos-test-cluster`)
- `--destroy` (optional): Destroy cluster at end of instantiate (default: keep cluster)

**What it does:**

1. Parses CLI arguments and sets up environment
2. Initializes Windsor context and creates `windsor.yaml`
3. Verifies Incus remote exists and is reachable
4. Checks if cluster VMs already exist (fails if they do)
5. Ensures Talos image is available (warns if not)
6. Creates cluster VMs via Terraform (1 control plane + 2 workers)
7. Waits for all VMs to be running
8. Gets IP addresses from Terraform outputs
9. Updates `windsor.yaml` with actual IP addresses
10. Regenerates `terraform.tfvars` with IPs and applies Talos configuration
11. Retrieves kubeconfig from the cluster
12. Displays final summary with cluster information
13. Optionally cleans up cluster (when `--destroy` is used)

**Examples:**

```bash
# Create a cluster on remote 'nuc' with default name
task tc:instantiate -- nuc 192.168.2.101

# Create a cluster with custom name
task tc:instantiate -- nuc 192.168.2.101 my-cluster

# Create a cluster and destroy it at the end (e.g. for CI)
task tc:instantiate -- nuc 192.168.2.101 my-cluster --destroy
```

**Note:** The `instantiate` task handles the complete cluster creation and bootstrapping process automatically, including IP address detection and Talos configuration.

### `instantiate:parse-args`

Parse CLI arguments for the instantiate task. This is automatically called by `instantiate` but can be run independently for testing.

**Usage:**

```bash
task tc:instantiate:parse-args
```

### `instantiate:initialize-context`

Initialize Windsor context and create `windsor.yaml` for the cluster. This is automatically called by `instantiate`.

**Usage:**

```bash
task tc:instantiate:initialize-context
```

### `instantiate:verify-remote`

Verify that the Incus remote exists and is reachable. This is automatically called by `instantiate`.

**Usage:**

```bash
task tc:instantiate:verify-remote
```

### `instantiate:check-existing-vms`

Check if cluster VMs already exist and fail if they do. This prevents accidental overwrites.

**Usage:**

```bash
task tc:instantiate:check-existing-vms
```

### `instantiate:check-talos-image`

Ensure Talos image is available on the remote. Warns if image is not found but does not fail.

**Usage:**

```bash
task tc:instantiate:check-talos-image
```

### `instantiate:create-cluster-vms`

Create cluster VMs via Terraform. This includes generating terraform.tfvars, initializing Terraform, and applying the configuration.

**Usage:**

```bash
task tc:instantiate:create-cluster-vms
```

### `instantiate:wait-for-vms`

Wait for all cluster VMs to be running and ready.

**Usage:**

```bash
task tc:instantiate:wait-for-vms
```

### `instantiate:get-ip-addresses`

Get IP addresses from Terraform outputs and update `windsor.yaml` with the actual IPs.

**Usage:**

```bash
task tc:instantiate:get-ip-addresses
```

### `instantiate:regenerate-tfvars-with-ips`

Regenerate terraform.tfvars with IP addresses and apply Talos configuration to the cluster.

**Usage:**

```bash
task tc:instantiate:regenerate-tfvars-with-ips
```

### `instantiate:retrieve-kubeconfig`

Retrieve kubeconfig from the cluster and save it to the configured location.

**Usage:**

```bash
task tc:instantiate:retrieve-kubeconfig
```

### `instantiate:final-summary`

Print success summary with cluster information including VM names, IP addresses, and connection details.

**Usage:**

```bash
task tc:instantiate:final-summary
```

### `instantiate:cleanup-if-needed`

Destroy cluster unless `--keep` flag was set. This is typically used in test contexts.

**Usage:**

```bash
task tc:instantiate:cleanup-if-needed
```

## Cluster Management

### `list`

List all cluster VMs on the configured remote.

**Usage:**

```bash
task tc:list
```

**Output:** Shows all cluster VMs (control plane and workers) with their status, IP addresses, and resource usage.

### `destroy`

Destroy the Talos cluster using Terraform.

**Usage:**

```bash
task tc:destroy [-- <cluster-name>]
```

**Warning:** This permanently removes the cluster and all its data.

### `delete`

Delete cluster VMs directly via Incus (bypasses Terraform). Use when Terraform state is lost or for manual cleanup.

**Usage:**

```bash
task tc:delete [-- <cluster-name>]
```

**Note:** Cluster VM start/stop/restart/console and health checks are not in the `tc:` namespace. Use **`talos:`** for health: `task talos:health-controlplane`, `task talos:health-worker`. Use the **Incus** CLI for VM control: `incus start/stop/restart/console $INCUS_REMOTE_NAME:<vm-name>`.

## Environment Variables

The following environment variables can be set in your `contexts/<context>/windsor.yaml` configuration:

- `INCUS_REMOTE_NAME`: Incus remote name (required). Examples: `local`, `nuc`, `remote-server`
- `INCUS_REMOTE_IP`: Incus remote IP address (required; passed as CLI argument)
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

