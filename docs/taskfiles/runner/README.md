---
title: "Runner Tasks"
description: "GitHub Actions runner setup and management tasks"
---
# Runner Tasks (`runner:`)

GitHub Actions runner VM setup and management.

## Initialization

- `task runner:initialize -- <vm-name>` - Initialize a new Incus VM for GitHub Actions runner

## Setup Tasks

- `task runner:install-aqua -- <vm-name>` - Install aqua package manager
- `task runner:install-docker -- <vm-name>` - Install Docker
- `task runner:create-runner-user -- <vm-name>` - Create a dedicated runner user
- `task runner:setup-ssh -- <vm-name>` - Set up SSH access for the runner user
- `task runner:install-windsor-cli -- <vm-name>` - Install Windsor CLI
- `task runner:install-packages -- <vm-name>` - Install additional packages commonly needed for runners

## GitHub Actions

- `task runner:install-github-runner -- <vm-name>` - Install and configure GitHub Actions runner

## Maintenance

- `task runner:clean-work-dir -- <vm-name>` - Clean the actions-runner/_work directory
- `task runner:shell -- <vm-name>` - Open an interactive shell session in the runner VM

## Help

- `task runner:help` - Show all runner tasks

## Environment Variables

- `GITHUB_RUNNER_REPO_URL` - GitHub repository or organization URL for the runner (required)
- `GITHUB_RUNNER_TOKEN` - GitHub runner registration token (required, should be stored as a secret)
- `GITHUB_RUNNER_VERSION` - (Optional) Specific runner version (e.g., `"2.XXX.X"`)
- `GITHUB_RUNNER_ARCH` - (Optional) Runner architecture (`"x64"` or `"arm64"`)

## Taskfile Location

Task definitions are located in `tasks/runner/Taskfile.yaml`.

