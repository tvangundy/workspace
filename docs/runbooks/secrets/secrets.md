---
title: "Managing Secrets with SOPS"
description: "Step-by-step guide for managing encrypted secrets using SOPS in a Windsor workspace"
---

# Managing Secrets with SOPS

This runbook walks you through setting up and managing encrypted secrets using SOPS (Secrets Operations) in a Windsor workspace. You'll learn how to create a secrets context, generate and encrypt secret files, and make them available through Windsor's environment system.

## Prerequisites

- [Windsor CLI](https://windsorcli.github.io/latest/install/) installed and configured
- [SOPS](https://github.com/getsops/sops) installed
- An initialized workspace (see [Initialize Workspace](../workspace/init.md))
- Access to your workspace directory

## Overview

The secrets management process involves:

1. **Create a secrets context** using `windsor init <context>`
2. **Generate a secrets file** using `task sops:generate-secrets-file`
3. **Edit the secrets file** with your actual secret values
4. **Encrypt the secrets file** using `task sops:encrypt-secrets-file`
5. **Configure  contexts/windsor.yaml** to reference the secrets
6. **Verify secrets** are available using `windsor env`

## Step 1: Create the Secrets Context

First, navigate to your workspace directory and create a new context called "secrets":

```bash
cd /path/to/your/workspace
windsor init <context>
```

This command creates a new context directory structure under `contexts/$WINDSOR_CONTEXT/` with the necessary configuration files.

## Step 2: Generate the Secrets File

Generate a template secrets file for the current context:

```bash
task sops:generate-secrets-file
```

This command:

- Creates the `contexts/$WINDSOR_CONTEXT/` directory if it doesn't exist
- Generates a `secrets.yaml` file with a sample secret (`TEST_ENV_VAR: value`)
- The file is created at `contexts/$WINDSOR_CONTEXT/secrets.yaml`

### Verify the Generated File

You can verify the file was created:

```bash
cat contexts/$WINDSOR_CONTEXT/secrets.yaml
```

You should see:
```yaml
TEST_ENV_VAR: value
```

## Step 3: Edit the Secrets File

Edit the `contexts/$WINDSOR_CONTEXT/secrets.yaml` file to add your actual secrets. You can use any text editor:

```bash
# Using your preferred editor
vim contexts/$WINDSOR_CONTEXT/secrets.yaml
# or
nano contexts/$WINDSOR_CONTEXT/secrets.yaml
# or
code contexts/$WINDSOR_CONTEXT/secrets.yaml
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

- Encrypts `contexts/$WINDSOR_CONTEXT/secrets.yaml`
- Creates `contexts/$WINDSOR_CONTEXT/secrets.enc.yaml` (the encrypted version)
- Uses your configured SOPS encryption keys (typically AWS KMS or age keys)

### Verify the Encrypted File

You should see the encrypted file:

```bash
ls -la contexts/$WINDSOR_CONTEXT/
```

You should see both:

- `secrets.yaml` (unencrypted - keep this secure!)
- `secrets.enc.yaml` (encrypted - safe to commit)

## Step 5: Configure Windsor to inject the secrets

To make the secrets available in your deployment, you need to reference them in your context's `windsor.yaml` file.

{% raw %}
```yaml
secrets:
  sops:
    enabled: true
environment:
  TEST_ENV_VAR: ${{ sops.TEST_ENV_VAR }}
```
{% endraw %}

## Step 6: Verify


Verify that your secrets are available by running:

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
windsor init <context>

# Step 3: Generate secrets file template
task sops:generate-secrets-file

# Step 4: Edit secrets file (add your actual secrets)
vim contexts/$WINDSOR_CONTEXT/secrets.yaml

# Step 5: Encrypt the secrets file
task sops:encrypt-secrets-file

# Step 6: Configure windsor.yaml
# Edit contexts/$WINDSOR_CONTEXT/windsor.yaml to enable secrets
# Add this to the end of windsor.yaml
{% raw %}
secrets:
  sops:
    enabled: true
environment:
  TEST_ENV_VAR: ${{ sops.TEST_ENV_VAR }}
{% endraw %}

# Step 7: Verify
windsor env | grep TEST_ENV_VAR
```

## Additional SOPS Operations

### Viewing Encrypted Secrets

To view the contents of an encrypted file without decrypting it permanently:

```bash
sops contexts/$WINDSOR_CONTEXT/secrets.enc.yaml
```

### Editing Encrypted Secrets

SOPS allows you to edit encrypted files directly:

```bash
sops contexts/$WINDSOR_CONTEXT/secrets.enc.yaml
```

This will:

1. Decrypt the file temporarily
2. Open it in your default editor
3. Re-encrypt it when you save and close

### Decrypting for Inspection

To decrypt the file for inspection (without editing):

```bash
sops -d contexts/$WINDSOR_CONTEXT/secrets.enc.yaml
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

1. **Verify context is set**: Run `windsor context get` to confirm you're using the current context
2. **Check blueprint.yaml**: Ensure the secrets section is correctly configured
3. **Check windsor.yaml**: Verify secrets are enabled and the path is correct
4. **Verify file exists**: Confirm `contexts/$WINDSOR_CONTEXT/secrets.enc.yaml` exists
5. **Check SOPS keys**: Ensure you have access to the SOPS encryption keys

### SOPS Encryption Errors

If you encounter encryption errors:

1. **Check SOPS configuration**: Verify your `.sops.yaml` or SOPS environment is configured
2. **Verify key access**: Ensure you have permissions to use the encryption keys (AWS KMS, age keys, etc.)
3. **Check file format**: Ensure `secrets.yaml` is valid YAML

### Context Not Found

If `windsor init <context>` fails:

1. **Verify workspace**: Ensure you're in a valid Windsor workspace directory
2. **Check for parent .windsor**: Ensure you're not nested under another workspace (see [Initialize Workspace](../workspace/init.md) for details)

## Related Documentation

- [Initialize Workspace](../workspace/init.md) - Setting up a new workspace
- [SOPS Documentation](https://github.com/getsops/sops)
- [Windsor CLI Documentation](https://windsorcli.github.io/latest/)
