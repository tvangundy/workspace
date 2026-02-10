---
title: "SOPS Tasks"
description: "Secrets management using SOPS for generating, encrypting, and decrypting secrets files"
---
# SOPS Tasks (`sops:`)

Secrets management using SOPS (Secrets Operations).

## Overview

The `sops:` namespace provides tools for managing encrypted secrets using SOPS. These tasks handle secret file generation, encryption, and decryption for the current Windsor context.

## Task Reference

| Task | Description |
|------|-------------|
| [`generate-secrets-file`](#generate-secrets-file) | Generate a new secrets file template for the current context |
| [`encrypt-secrets-file`](#encrypt-secrets-file) | Encrypt the secrets file using SOPS |
| [`decrypt-secrets-file`](#decrypt-secrets-file) | Decrypt the secrets file using SOPS |

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
- SOPS configured with appropriate encryption keys (e.g., AWS KMS)
- AWS credentials configured with access to KMS key (when using KMS)

**What it does:**

1. Reads `contexts/<context>/secrets.yaml`
2. Encrypts it using SOPS
3. Writes encrypted content to `contexts/<context>/secrets.enc.yaml`

**Example:**

```bash
task sops:encrypt-secrets-file
```

**Output:** Creates `contexts/<context>/secrets.enc.yaml` with encrypted content.

**Note:** The encrypted file can be safely committed to version control.

### `decrypt-secrets-file`

Decrypt the secrets file using SOPS.

**Usage:**

```bash
task sops:decrypt-secrets-file
```

**Environment Variables:**

- `WINDSOR_PROJECT_ROOT`: Windsor project root directory (auto-detected)
- `WINDSOR_CONTEXT`: Current Windsor context (auto-detected)

**Prerequisites:**

- `secrets.enc.yaml` file exists in `contexts/<context>/`
- SOPS configured with decryption keys
- AWS credentials configured with access to KMS key (when using KMS)

**What it does:**

1. Reads `contexts/<context>/secrets.enc.yaml`
2. Decrypts it using SOPS
3. Writes decrypted content to `contexts/<context>/secrets.yaml`

**Example:**

```bash
task sops:decrypt-secrets-file
```

**Warning:** Do not commit decrypted `secrets.yaml` to version control.

## Environment Variables

The following environment variables are used:

- `WINDSOR_PROJECT_ROOT`: Windsor project root directory (auto-detected)
- `WINDSOR_CONTEXT`: Current Windsor context (auto-detected via `windsor context get`)

## Workflow Example

Secrets management workflow:

```bash
# 1. Generate secrets file template
task sops:generate-secrets-file

# 2. Edit secrets.yaml with your actual secrets
vim contexts/<context>/secrets.yaml

# 3. Encrypt the secrets file
task sops:encrypt-secrets-file

# 4. Commit encrypted file to version control
git add contexts/<context>/secrets.enc.yaml
git commit -m "Add encrypted secrets"

# 5. When you need to decrypt (e.g., for local use)
task sops:decrypt-secrets-file
```

## Prerequisites

- SOPS installed
- Windsor CLI configured
- Encryption keys configured (e.g., AWS KMS with credentials when using KMS)

## Help

View all available SOPS commands:

```bash
task sops:help
```

## Taskfile Location

Task definitions are located in `tasks/sops/Taskfile.yaml`.
