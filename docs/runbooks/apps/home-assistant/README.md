# Home Assistant Runbook

This runbook guides you through deploying Home Assistant on a Raspberry Pi using Windsor CLI. Home Assistant is a powerful open-source home automation platform that puts local control and privacy first.

## Introduction

Before you can deploy Home Assistant, you need to complete the following prerequisites:

1. **Initialize a Workspace**: Set up your Windsor workspace structure. Follow the [Initialize Workspace](../workspace/init.md) runbook to create a new workspace and configure it with Windsor CLI.

```bash
task workspace:initialize -- home-assistant ../home-assistant
cd ../home-assistant
```
2. **Initialize the Windsor Context**:

Initialize a new context called rpi

```bash
windsor init rpi
```

3. **Setup secrets**: Configure encrypted secrets for your deployment. Follow the [Managing Secrets with SOPS](../secrets/secrets.md) runbook to set up and manage your secrets. 

Use the windsor context command to confirm the current context is 'rpi'

```bash
windsor context get
```

We will be adding secrets going forward so use the windsor env command to confirm secrets are setup.
  
```bash
windsor env
```

4. **Bootstrap Your Nodes**: Prepare your Raspberry Pi devices for Kubernetes deployment. Follow the [Bootstrapping Nodes](../bootstrapping/README.md) runbook to install Talos and prepare your cluster nodes.


```bash

rpi::home-assistant ✨ windsor env
BUILD_ID=251221.787.1
CLUSTER_NAME=home-assistant
K8S_AUTH_KUBECONFIG=/Users/$USER/Developer/home-assistant/contexts/rpi/.kube/config
KUBECONFIG=/Users/$USER/Developer/home-assistant/contexts/rpi/.kube/config
KUBE_CONFIG_PATH=/Users/$USER/Developer/home-assistant/contexts/rpi/.kube/config
RPI_0_IP_ADDRESS=192.168.2.111
RPI_1_IP_ADDRESS=192.168.2.125
RPI_IMAGE_ARCH=metal-arm64
RPI_IMAGE_SCHEMATIC_ID=ee21ef4a5ef808a9b7484cc0dda0f25075021691c8c09a276591eedb638ea1f9
RPI_IMAGE_VERSION=v1.11.6
USB_DISK=/dev/disk4
WINDSOR_CONTEXT=rpi
WINDSOR_CONTEXT_ID=wwqc3epv
WINDSOR_MANAGED_ALIAS=
WINDSOR_MANAGED_ENV=WINDSOR_CONTEXT,WINDSOR_CONTEXT_ID,BUILD_ID,WINDSOR_PROJECT_ROOT,WINDSOR_SESSION_TOKEN,WINDSOR_MANAGED_ENV,WINDSOR_MANAGED_ALIAS
WINDSOR_PROJECT_ROOT=/Users/$USER/Developer/home-assistant
WINDSOR_SESSION_TOKEN=kbq2FGB
```


# Install and run home assistant

```
windsor up --install --verbose

Visit: http://home-assistant:8123
```

# References

## Home Assistant in Kubernetes

https://ohmydevops.l3st-tech.com/posts/deploy-homeassistant-kubernetes/?utm_source=chatgpt.com

## Using Helm Chart
https://github.com/pajikos/home-assistant-helm-chart/blob/main/charts/home-assistant/README.md
