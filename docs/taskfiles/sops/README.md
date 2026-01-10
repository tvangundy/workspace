---
title: "SOPS Tasks"
description: "Secrets management using SOPS (Secrets Operations) with AWS KMS tasks for context setup, Terraform operations, and secret file management"
---
# SOPS Tasks (`sops:`)

Secrets management using SOPS (Secrets Operations) with AWS KMS.

## Overview

The `sops:` namespace provides tools for managing encrypted secrets using SOPS with AWS KMS encryption. These tasks handle context setup, Terraform infrastructure deployment, and secret file generation and encryption.

## Task Reference

| Task | Description |
|------|-------------|
| [`set-context`](#set-context) | Initialize the SOPS context with AWS S3 backend |
| [`init`](#init) | Initialize Terraform for SOPS infrastructure |
| [`plan`](#plan) | Plan deployment to AWS |
| [`apply`](#apply) | Deploy SOPS resources to AWS (KMS key and state bucket) |
| [`output`](#output) | Print SOPS Terraform state output |
| [`destroy`](#destroy) | Destroy the AWS SOPS infrastructure |
| [`generate-secrets-file`](#generate-secrets-file) | Generate a new secrets file template for the current context |
| [`encrypt-secrets-file`](#encrypt-secrets-file) | Encrypt the secrets file using SOPS |

## Context Setup

### `set-context`

Initialize the SOPS context with AWS S3 backend.

**Usage:**

```bash
task sops:set-context
```

**Environment Variables:**

- `WINDSOR_PROJECT_ROOT`: Windsor project root directory (auto-detected)

**What it does:**

1. Initializes Windsor context for SOPS with S3 backend
2. Uses AWS profile `public` by default
3. Configures context in `contexts/sops/sops/`

**Example:**

```bash
task sops:set-context
```

**Note:** This sets up the SOPS infrastructure context. You'll need to run `sops:apply` to actually create the AWS resources.

## Terraform Operations

### `init`

Initialize Terraform for SOPS infrastructure.

**Usage:**

```bash
task sops:init
```

**Environment Variables:**

- `TERRAFORM_ROOT`: Root directory for Terraform configurations

**What it does:**

1. Changes to `$TERRAFORM_ROOT/sops` directory
2. Sets up Windsor environment
3. Runs `terraform init -upgrade`

**Example:**

```bash
task sops:init
```

### `plan`

Plan deployment to AWS.

**Usage:**

```bash
task sops:plan
```

**Environment Variables:**

- `TERRAFORM_ROOT`: Root directory for Terraform configurations

**What it does:**

1. Changes to `$TERRAFORM_ROOT/sops` directory
2. Sets up Windsor environment
3. Runs `terraform init -upgrade`
4. Runs `terraform plan`

**Example:**

```bash
task sops:plan
```

**Output:** Shows what Terraform will create or modify in AWS.

### `apply`

Deploy SOPS resources to AWS (KMS key and state bucket).

**Usage:**

```bash
task sops:apply
```

**Environment Variables:**

- `TERRAFORM_ROOT`: Root directory for Terraform configurations

**What it does:**

1. Changes to `$TERRAFORM_ROOT/sops` directory
2. Sets up Windsor environment
3. Runs `terraform init -upgrade`
4. Runs `terraform plan`
5. Runs `terraform apply` (requires confirmation)

**Example:**

```bash
task sops:apply
```

**Warning:** This creates AWS resources that may incur costs.

**Output:**

- Creates AWS KMS key for SOPS encryption
- Creates S3 bucket for Terraform state storage

### `output`

Print SOPS Terraform state output.

**Usage:**

```bash
task sops:output
```

**Environment Variables:**

- `TERRAFORM_ROOT`: Root directory for Terraform configurations

**What it does:**

1. Changes to `$TERRAFORM_ROOT/sops` directory
2. Sets up Windsor environment
3. Runs `terraform init`
4. Runs `terraform output`

**Example:**

```bash
task sops:output
```

**Output:** Shows Terraform outputs like KMS key ARN, bucket name, etc.

### `destroy`

Destroy the AWS SOPS infrastructure.

**Usage:**

```bash
task sops:destroy
```

**Environment Variables:**

- `TERRAFORM_ROOT`: Root directory for Terraform configurations

**What it does:**

1. Changes to `$TERRAFORM_ROOT/sops` directory
2. Sets up Windsor environment
3. Runs `terraform init`
4. Runs `terraform destroy` (requires confirmation)

**Example:**

```bash
task sops:destroy
```

**Warning:** This permanently destroys the KMS key and S3 bucket. All encrypted secrets using this infrastructure will become unusable.

## SOPS Operations

### `generate-secrets-file`

Generate a new secrets file template for the current context.

**Usage:**

```bash
task sops:generate-secrets-file
```

**Environment Variables:**

- `WINDSOR_PROJECT_ROOT`: Windsor project root directory (auto-detected)
- `WINDSOR_CONTEXT`: Current Windsor context (auto-detected)

**What it does:**

1. Creates directory: `contexts/<context>/` if needed
2. Generates `secrets.yaml` with a sample `TEST_ENV_VAR`

**Example:**

```bash
task sops:generate-secrets-file
```

**Output:** Creates `contexts/<context>/secrets.yaml` with template content.

**Note:** Edit this file to add your actual secrets before encrypting.

### `encrypt-secrets-file`

Encrypt the secrets file using SOPS.

**Usage:**

```bash
task sops:encrypt-secrets-file
```

**Environment Variables:**

- `WINDSOR_PROJECT_ROOT`: Windsor project root directory (auto-detected)
- `WINDSOR_CONTEXT`: Current Windsor context (auto-detected)

**Prerequisites:**

- `secrets.yaml` file exists in `contexts/<context>/`
- SOPS infrastructure deployed (`task sops:apply`)
- AWS credentials configured with access to KMS key

**What it does:**

1. Reads `contexts/<context>/secrets.yaml`
2. Encrypts it using SOPS with AWS KMS
3. Writes encrypted content to `contexts/<context>/secrets.enc.yaml`

**Example:**

```bash
task sops:encrypt-secrets-file
```

**Output:** Creates `contexts/<context>/secrets.enc.yaml` with encrypted content.

**Note:** The encrypted file can be safely committed to version control.

## Environment Variables

The following environment variables are used:

- `WINDSOR_PROJECT_ROOT`: Windsor project root directory (auto-detected)
- `WINDSOR_CONTEXT`: Current Windsor context (auto-detected via `windsor context get`)
- `TERRAFORM_ROOT`: Root directory for Terraform configurations
- `DEFAULT_AWS_PROFILE`: AWS profile to use (default: `public`)

## Workflow Example

Complete SOPS setup workflow:

```bash
# 1. Set up SOPS context
task sops:set-context

# 2. Deploy AWS infrastructure (KMS key and S3 bucket)
task sops:apply

# 3. Generate secrets file template
task sops:generate-secrets-file

# 4. Edit secrets.yaml with your actual secrets
vim contexts/<context>/secrets.yaml

# 5. Encrypt the secrets file
task sops:encrypt-secrets-file

# 6. Commit encrypted file to version control
git add contexts/<context>/secrets.enc.yaml
git commit -m "Add encrypted secrets"
```

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured with credentials
- Terraform installed
- SOPS installed
- Windsor CLI configured

## Help

View all available SOPS commands:

```bash
task sops:help
```

## Taskfile Location

Task definitions are located in `tasks/sops/Taskfile.yaml`.
