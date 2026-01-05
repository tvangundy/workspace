---
title: "Talos Tasks"
description: "Talos Linux cluster health checks and management tasks for monitoring cluster nodes and cleaning up resources"
---
# Talos Tasks (`talos:`)

Talos Linux cluster health checks and management.

## Overview

The `talos:` namespace provides tools for monitoring and managing Talos Linux Kubernetes clusters. These tasks handle health checks for control plane and worker nodes, certificate inspection, and cluster cleanup.

## Health Checks

### `health-controlplane`

Check control plane node health.

**Usage:**

```bash
task talos:health-controlplane
```

**Environment Variables (Required):**

- `CONTROL_PLANE_IP`: IP address of the control plane node
- `TALOSCONFIG`: Path to Talos configuration file

**What it does:**

1. Runs `talosctl health` check on the control plane node
2. Verifies all control plane services are healthy

**Example:**

```bash
export CONTROL_PLANE_IP=192.168.2.31
export TALOSCONFIG=~/.talos/config

task talos:health-controlplane
```

**Output:** Shows health status of etcd, API server, and other control plane components.

### `health-worker`

Check all worker nodes health.

**Usage:**

```bash
task talos:health-worker
```

**Environment Variables (Required):**

- `CONTROL_PLANE_IP`: IP address of the control plane node (used as endpoint)
- `WORKER_0_IP`: IP address of the first worker node
- `WORKER_1_IP`: IP address of the second worker node
- `WORKER_0_VM`: Name of the first worker VM (for display)
- `WORKER_1_VM`: Name of the second worker VM (for display)
- `TALOSCONFIG`: Path to Talos configuration file

**What it does:**

1. Checks health of `WORKER_0_VM` (worker-0)
2. Checks health of `WORKER_1_VM` (worker-1)

**Example:**

```bash
export CONTROL_PLANE_IP=192.168.2.31
export WORKER_0_IP=192.168.2.111
export WORKER_1_IP=192.168.2.125
export WORKER_0_VM=talos-worker-0
export WORKER_1_VM=talos-worker-1
export TALOSCONFIG=~/.talos/config

task talos:health-worker
```

**Output:** Shows health status for each worker node.

### `health-worker-0`

Check worker-0 node health.

**Usage:**

```bash
task talos:health-worker-0
```

**Environment Variables (Required):**

- `CONTROL_PLANE_IP`: IP address of the control plane node (used as endpoint)
- `WORKER_0_IP`: IP address of the first worker node
- `TALOSCONFIG`: Path to Talos configuration file

**What it does:**

1. Runs `talosctl health` check on worker-0 node only

**Example:**

```bash
export CONTROL_PLANE_IP=192.168.2.31
export WORKER_0_IP=192.168.2.111
export TALOSCONFIG=~/.talos/config

task talos:health-worker-0
```

### `health-worker-1`

Check worker-1 node health.

**Usage:**

```bash
task talos:health-worker-1
```

**Environment Variables (Required):**

- `CONTROL_PLANE_IP`: IP address of the control plane node (used as endpoint)
- `WORKER_1_IP`: IP address of the second worker node
- `TALOSCONFIG`: Path to Talos configuration file

**What it does:**

1. Runs `talosctl health` check on worker-1 node only

**Example:**

```bash
export CONTROL_PLANE_IP=192.168.2.31
export WORKER_1_IP=192.168.2.125
export TALOSCONFIG=~/.talos/config

task talos:health-worker-1
```

### `fetch-node-server-certificate`

Fetch and display the server certificate from the control plane node.

**Usage:**

```bash
task talos:fetch-node-server-certificate
```

**Environment Variables (Required):**

- `CONTROL_PLANE_IP`: IP address of the control plane node

**What it does:**

1. Connects to the control plane node on port 50000 (Talos API port)
2. Retrieves the server certificate
3. Displays certificate details in human-readable format

**Example:**

```bash
export CONTROL_PLANE_IP=192.168.2.31

task talos:fetch-node-server-certificate
```

**Output:** Shows certificate subject, issuer, validity dates, and other details.

**Use cases:**

- Troubleshooting TLS connection issues
- Verifying certificate validity
- Inspecting certificate details

## Cluster Management

### `cleanup`

Destroy the entire Talos cluster and clean up resources. **Warning:** This permanently deletes all cluster VMs and data.

**Usage:**

```bash
task talos:cleanup
```

**Environment Variables (Required):**

- `INCUS_REMOTE_NAME`: Incus remote name
- `CONTROL_PLANE_VM`: Name of the control plane VM
- `WORKER_0_VM`: Name of the first worker VM
- `WORKER_1_VM`: Name of the second worker VM

**Optional Environment Variables:**

- `WINDSOR_CONTEXT`: Windsor context name (for showing cleanup paths)
- `CLUSTER_NAME`: Cluster name (for showing cleanup paths)

**What it does:**

1. Shows warning message about what will be deleted
2. Prompts for confirmation (must type "yes" to proceed)
3. Stops all cluster VMs
4. Deletes all cluster VMs
5. Shows optional cleanup paths for configuration files

**Example:**

```bash
export INCUS_REMOTE_NAME=nuc
export CONTROL_PLANE_VM=talos-cp
export WORKER_0_VM=talos-worker-0
export WORKER_1_VM=talos-worker-1

task talos:cleanup
```

**Warning:** This operation is **irreversible**. It will:

- Stop and delete all cluster VMs
- Remove all Kubernetes cluster state
- Delete all workloads and persistent volumes

**Confirmation Required:** You must type "yes" (exactly) to confirm the deletion.

**Optional Cleanup:**

After VM deletion, the task shows paths for optional cleanup:

- Configuration files: `contexts/<context>/clusters/<cluster-name>/`
- Talos config: `contexts/<context>/.talos/talosconfig`
- Kubeconfig: `contexts/<context>/.kube/config`
- Talos image: `contexts/<context>/devices/talos/talos-metal-amd64.qcow2`

## Environment Variables

The following environment variables are commonly used:

### Health Check Variables

- `CONTROL_PLANE_IP`: IP address of the control plane node (required for all health checks)
- `WORKER_0_IP`: IP address of the first worker node (required for worker health checks)
- `WORKER_1_IP`: IP address of the second worker node (required for worker health checks)
- `TALOSCONFIG`: Path to Talos configuration file (required for all health checks)

### Cleanup Variables

- `INCUS_REMOTE_NAME`: Incus remote name (required for cleanup)
- `CONTROL_PLANE_VM`: Name of the control plane VM (required for cleanup)
- `WORKER_0_VM`: Name of the first worker VM (required for cleanup)
- `WORKER_1_VM`: Name of the second worker VM (required for cleanup)
- `WINDSOR_CONTEXT`: Windsor context name (optional, for cleanup path display)
- `CLUSTER_NAME`: Cluster name (optional, for cleanup path display)

## Prerequisites

- `talosctl` installed and configured
- Talos cluster running and accessible
- Network access to cluster nodes
- Valid `TALOSCONFIG` file for cluster access
- For cleanup: Incus remote configured with access to cluster VMs

## Help

View all available Talos commands:

```bash
task talos:help
```

The help command also displays current environment variable values.

## Taskfile Location

Task definitions are located in `tasks/talos/Taskfile.yaml`.
