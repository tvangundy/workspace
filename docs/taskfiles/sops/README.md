---
title: "SOPS Tasks"
description: "Secrets management using SOPS tasks"
---
# SOPS Tasks (`sops:`)

Secrets management using SOPS (Secrets Operations) with AWS KMS.

## Context Setup

- `task sops:set-context` - Initialize the SOPS context with AWS S3 backend

## Terraform Operations

- `task sops:init` - Initialize Terraform for SOPS infrastructure
- `task sops:plan` - Plan deployment to AWS
- `task sops:apply` - Deploy SOPS resources to AWS (KMS key and state bucket)
- `task sops:output` - Print SOPS Terraform state
- `task sops:destroy` - Destroy the AWS SOPS infrastructure

## SOPS Operations

- `task sops:generate-secrets-file` - Generate a new secrets file template for the current context
- `task sops:encrypt-secrets-file` - Encrypt the secrets file using SOPS

## Help

- `task sops:help` - Show all SOPS-related commands

## Taskfile Location

Task definitions are located in `tasks/sops/Taskfile.yaml`.

