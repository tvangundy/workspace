---
title: "Managing Secrets with SOPS"
description: "Step-by-step guide for managing encrypted secrets using SOPS in a Windsor workspace"
---

# Managing Secrets with SOPS

This runbook walks you through setting up and managing encrypted secrets using SOPS (Secrets Operations) in a Windsor workspace. You'll learn how to create a secrets context, generate and encrypt secret files, and make them available through Windsor's environment system.

## Prerequisites

- [Windsor CLI](https://windsorcli.github.io/latest/install/) installed and configured
- [SOPS](https://github.com/getsops/sops) installed
- An initialized workspace (see [Initialize Workspace](./workspace/init.md))
- Access to your workspace directory

## Overview

The secrets management process involves:

1. **Create a secrets context** using `windsor init secrets`
2. **Generate a secrets file** using `task sops:generate-secrets-file`
3. **Edit the secrets file** with your actual secret values
4. **Encrypt the secrets file** using `task sops:encrypt-secrets-file`
5. **Configure blueprint.yaml and windsor.yaml** to reference the secrets
6. **Verify secrets** are available using `windsor env`

## Step 1: Create the Secrets Context

First, navigate to your workspace directory and create a new context called "secrets":

```bash
cd /path/to/your/workspace
windsor init secrets
```

This command creates a new context directory structure under `contexts/secrets/` with the necessary configuration files.

## Step 2: Generate the Secrets File

Generate a template secrets file for the secrets context:

```bash
task sops:generate-secrets-file
```

This command:
- Creates the `contexts/secrets/` directory if it doesn't exist
- Generates a `secrets.yaml` file with a sample secret (`TEST_ENV_VAR: value`)
- The file is created at `contexts/secrets/secrets.yaml`

### Verify the Generated File

You can verify the file was created:

```bash
cat contexts/secrets/secrets.yaml
```

You should see:
```yaml
TEST_ENV_VAR: value
```

## Step 3: Edit the Secrets File

Edit the `contexts/secrets/secrets.yaml` file to add your actual secrets. You can use any text editor:

```bash
# Using your preferred editor
vim contexts/secrets/secrets.yaml
# or
nano contexts/secrets/secrets.yaml
# or
code contexts/secrets/secrets.yaml
```

### Example Secrets File

Here's an example of what your `secrets.yaml` might look like:

```yaml
DATABASE_PASSWORD: my-secure-password-123
API_KEY: sk_live_abc123xyz789
JWT_SECRET: super-secret-jwt-key
AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**Important**: The `secrets.yaml` file contains unencrypted secrets. Keep this file secure and never commit it to version control. Only the encrypted `secrets.enc.yaml` file should be committed.

## Step 4: Encrypt the Secrets File

Once you've added your secrets, encrypt the file using SOPS:

```bash
task sops:encrypt-secrets-file
```

This command:
- Encrypts `contexts/secrets/secrets.yaml`
- Creates `contexts/secrets/secrets.enc.yaml` (the encrypted version)
- Uses your configured SOPS encryption keys (typically AWS KMS or age keys)

### Verify the Encrypted File

You should see the encrypted file:

```bash
ls -la contexts/secrets/
```

You should see both:
- `secrets.yaml` (unencrypted - keep this secure!)
- `secrets.enc.yaml` (encrypted - safe to commit)

## Step 5: Configure blueprint.yaml

To make the secrets available in your deployment, you need to reference them in your context's `blueprint.yaml` file.

Edit `contexts/secrets/blueprint.yaml` and add a `secrets` section. Here's an example:

```yaml
kind: Blueprint
apiVersion: blueprints.windsorcli.dev/v1alpha1
metadata:
  name: secrets
  description: Secrets context for encrypted configuration
secrets:
  - name: secrets
    path: contexts/secrets/secrets.enc.yaml
    type: sops
```

### Key Configuration Points

- **`name`**: A name for this secrets source (can be anything descriptive)
- **`path`**: The path to the encrypted secrets file relative to the workspace root
- **`type`**: Set to `sops` to indicate SOPS-encrypted format

## Step 6: Configure windsor.yaml

The `windsor.yaml` file in your context directory controls how Windsor processes the secrets. Edit `contexts/secrets/windsor.yaml`:

```yaml
id: <your-context-id>
provider: generic
secrets:
  enabled: true
  sources:
    - name: secrets
      type: sops
      path: contexts/secrets/secrets.enc.yaml
```

### Alternative: Root windsor.yaml

If you want secrets available across all contexts, you can also configure them in the root `windsor.yaml` file at the workspace root:

```yaml
secrets:
  enabled: true
  sources:
    - name: secrets
      type: sops
      path: contexts/secrets/secrets.enc.yaml
```

## Step 7: Set the Context and Verify

Set the secrets context as active:

```bash
windsor context set secrets
```

Now verify that your secrets are available by running:

```bash
windsor env
```

This command will output all environment variables, including your decrypted secrets. You should see your secret variables in the output:

```bash
DATABASE_PASSWORD=my-secure-password-123
API_KEY=sk_live_abc123xyz789
JWT_SECRET=super-secret-jwt-key
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Using Secrets in Commands

You can also source the environment variables directly:

```bash
eval "$(windsor env)"
echo $DATABASE_PASSWORD
```

## Complete Example Workflow

Here's a complete example of the entire process:

```bash
# Step 1: Navigate to workspace
cd /Users/$USER/Developer/my-workspace

# Step 2: Create secrets context
windsor init secrets

# Step 3: Generate secrets file template
task sops:generate-secrets-file

# Step 4: Edit secrets file (add your actual secrets)
vim contexts/secrets/secrets.yaml

# Step 5: Encrypt the secrets file
task sops:encrypt-secrets-file

# Step 6: Configure blueprint.yaml
# Edit contexts/secrets/blueprint.yaml to add secrets section

# Step 7: Configure windsor.yaml
# Edit contexts/secrets/windsor.yaml to enable secrets

# Step 8: Set context and verify
windsor context set secrets
windsor env | grep DATABASE_PASSWORD
```

## Additional SOPS Operations

### Viewing Encrypted Secrets

To view the contents of an encrypted file without decrypting it permanently:

```bash
sops contexts/secrets/secrets.enc.yaml
```

### Editing Encrypted Secrets

SOPS allows you to edit encrypted files directly:

```bash
sops contexts/secrets/secrets.enc.yaml
```

This will:
1. Decrypt the file temporarily
2. Open it in your default editor
3. Re-encrypt it when you save and close

### Decrypting for Inspection

To decrypt the file for inspection (without editing):

```bash
sops -d contexts/secrets/secrets.enc.yaml
```

## Best Practices

1. **Never commit unencrypted secrets**: Only commit `secrets.enc.yaml`, never `secrets.yaml`
2. **Use .gitignore**: Ensure `secrets.yaml` is in your `.gitignore` file
3. **Rotate keys regularly**: Periodically rotate your SOPS encryption keys
4. **Limit access**: Only grant SOPS decryption access to those who need it
5. **Use separate contexts**: Consider using different secrets contexts for different environments (dev, staging, prod)

## Troubleshooting

### Secrets Not Appearing in `windsor env`

If secrets don't appear when running `windsor env`:

1. **Verify context is set**: Run `windsor context get` to confirm you're using the secrets context
2. **Check blueprint.yaml**: Ensure the secrets section is correctly configured
3. **Check windsor.yaml**: Verify secrets are enabled and the path is correct
4. **Verify file exists**: Confirm `contexts/secrets/secrets.enc.yaml` exists
5. **Check SOPS keys**: Ensure you have access to the SOPS encryption keys

### SOPS Encryption Errors

If you encounter encryption errors:

1. **Check SOPS configuration**: Verify your `.sops.yaml` or SOPS environment is configured
2. **Verify key access**: Ensure you have permissions to use the encryption keys (AWS KMS, age keys, etc.)
3. **Check file format**: Ensure `secrets.yaml` is valid YAML

### Context Not Found

If `windsor init secrets` fails:

1. **Verify workspace**: Ensure you're in a valid Windsor workspace directory
2. **Check for parent .windsor**: Ensure you're not nested under another workspace (see [Initialize Workspace](./workspace/init.md) for details)

## Related Documentation

- [Initialize Workspace](./workspace/init.md) - Setting up a new workspace
- [SOPS Documentation](https://github.com/getsops/sops)
- [Windsor CLI Documentation](https://windsorcli.github.io/latest/)
