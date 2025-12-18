# Home Assistant Runbook

This runbook guides you through deploying Home Assistant on a Raspberry Pi using Windsor CLI. Home Assistant is a powerful open-source home automation platform that puts local control and privacy first.

## Introduction

Before you can deploy Home Assistant, you need to complete the following prerequisites:

1. **Initialize a Workspace**: Set up your Windsor workspace structure. Follow the [Initialize Workspace](./workspace/init.md) runbook to create a new workspace and configure it with Windsor CLI.

```bash
task workspace:initialize -- home-assistant ../home-assistant
```
2. **Initialize the Windsor Context**:

After completing the workspace initialization and node bootstrapping, initialize the Home Assistant context for your Raspberry Pi:

```bash
windsor init rpi
```

3. **Setup secrets**: Configure encrypted secrets for your deployment. Follow the [Managing Secrets with SOPS](./secrets/secrets.md) runbook to set up and manage your secrets. 

Use the windsor context command to confirm the current context is 'rpi'

```bash
windsor context get
```

We will be adding secrets going forward so use the windsor env command to confirm secrets are setup.
  
```bash
windsor env
```

4. **Bootstrap Your Nodes**: Prepare your Raspberry Pi devices for Kubernetes deployment. Follow the [Bootstrapping Nodes](./bootstrapping/README.md) runbook to install Talos and prepare your cluster nodes.


