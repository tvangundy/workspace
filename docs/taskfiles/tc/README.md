---
title: "TC Tasks"
description: "Talos Kubernetes cluster management tasks for creating and managing three-node Talos clusters on Incus using Terraform"
---
# TC Tasks (`tc:`)

Talos Kubernetes cluster management for creating and managing three-node Talos Linux clusters on Incus using Terraform.

## Overview

The `tc:` namespace provides tools for creating and managing Talos Kubernetes clusters on Incus. The primary entry point is `tc:instantiate`. For cluster VM start/stop/restart/console use the Incus CLI. For health checks use the `talos:` namespace: `task talos:health-controlplane`, `task talos:health-worker`.

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

## Cluster Creation

### `instantiate`

Create and bootstrap a three-node Talos Kubernetes cluster using Terraform. This is the primary way to create a new Talos cluster.

**Usage:**

```bash
task tc:instantiate -- <remote-name> [<cluster-name>] [--keep]
```

**Parameters:**

- `<remote-name>` (required): Name of the Incus remote (e.g., `nuc`, `local`)
- `<cluster-name>` (optional): Name for the cluster (default: `talos-test-cluster`)
- `--keep`, `--no-cleanup` (optional): Keep cluster running after creation (default: destroy cluster if used in test context)

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
13. Optionally cleans up cluster (unless `--keep` is used)

**Examples:**

```bash
# Create a cluster on remote 'nuc' with default name
task tc:instantiate -- nuc

# Create a cluster with custom name
task tc:instantiate -- nuc my-cluster

# Create a cluster and keep it running
task tc:instantiate -- nuc my-cluster --keep
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

