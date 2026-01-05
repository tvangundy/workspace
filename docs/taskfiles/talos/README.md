---
title: "Talos Tasks"
description: "Talos Linux cluster health checks and management tasks"
---
# Talos Tasks (`talos:`)

Talos Linux cluster health checks and management.

## Health Checks

- `task talos:health-controlplane` - Check control plane node health
- `task talos:health-worker` - Check all worker nodes health
- `task talos:health-worker-0` - Check worker-0 node health
- `task talos:health-worker-1` - Check worker-1 node health
- `task talos:fetch-node-server-certificate` - Fetch server certificate from control plane node

## Cluster Management

- `task talos:cleanup` - Destroy the entire Talos cluster and clean up resources (stops and deletes all VMs)

## Help

- `task talos:help` - Show all Talos-related commands

## Environment Variables

- `CONTROL_PLANE_IP` - Control plane node IP address
- `WORKER_0_IP` - First worker node IP address
- `WORKER_1_IP` - Second worker node IP address
- `TALOSCONFIG` - Path to Talos configuration file
- `INCUS_REMOTE_NAME` - Incus remote name
- `CONTROL_PLANE_VM` - Control plane VM name
- `WORKER_0_VM` - First worker VM name
- `WORKER_1_VM` - Second worker VM name

## Taskfile Location

Task definitions are located in `tasks/talos/Taskfile.yaml`.

