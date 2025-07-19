# Quick Start Guide

This guide will help you get started with bws-init in under 5 minutes.

## Prerequisites

Before you begin, ensure you have:

1. **Bitwarden Secrets Manager CLI** installed
   - Download: https://bitwarden.com/help/secrets-manager-cli/
   - Verify: `bws --version`

2. **BWS Access Token** from your Bitwarden account
   - Set as environment variable

## Installation

### Option 1: Download Standalone Script (Fastest)

```bash
# Download the script
curl -O https://raw.githubusercontent.com/yourusername/bws-init/main/src/bws-init.sh

# Make it executable
chmod +x bws-init.sh

# Run it
./bws-init.sh
```

### Option 2: Install Globally

```bash
# Clone the repository
git clone https://github.com/yourusername/bws-init.git
cd bws-init

# Install
./scripts/install.sh
```

## Basic Usage

### 1. Set up your environment

```bash
# Linux/macOS
export BWS_ACCESS_TOKEN="your-access-token-here"

# Windows (PowerShell)
$env:BWS_ACCESS_TOKEN = "your-access-token-here"
```

### 2. Initialize BWS in your project

```bash
# Navigate to your project
cd /path/to/your/project

# Run bws-init
bws-init
```

### 3. Retrieve your secrets

```bash
# Get local development secrets
./scripts/bitwarden/get-secrets.sh local

# Get production secrets
./scripts/bitwarden/get-secrets.sh production
```

## Example Workflow

Let's say you have a Node.js project with these env files:

```
my-app/
├── .env
├── .env.local
├── .env.production
└── package.json
```

### Step 1: Initialize BWS

```bash
$ cd my-app
$ bws-init

bws-init v1.0.0
======================================

[INFO] Using directory name as project: my-app
[INFO] Detecting environment files...
[INFO] Found environment files:
  - .env
  - .env.local
  - .env.production
[INFO] Creating BWS project 'my-app'...
[SUCCESS] Project created with ID: abc123
[INFO] Processing secrets...
[INFO] Processed 12/12 secrets
[SUCCESS] Initialization complete!
```

### Step 2: Add to .gitignore

```bash
echo ".bws-project" >> .gitignore
echo ".env*" >> .gitignore
echo "!.env.example" >> .gitignore
```

### Step 3: Use in development

```bash
# Get your local secrets
./scripts/bitwarden/get-secrets.sh local

# Start your app
npm run dev
```

### Step 4: Use in CI/CD

```yaml
# .github/workflows/deploy.yml
- name: Get production secrets
  env:
    BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}
  run: |
    ./scripts/bitwarden/get-secrets.sh production
    
- name: Deploy
  run: npm run deploy
```

## Common Patterns

### Multiple Environments

```bash
# Process only production secrets
bws-init --env production

# Process only local secrets
bws-init --env local
```

### Custom Output Directory

```bash
# Put scripts in a different location
bws-init --output .bws/scripts
```

### Dry Run

```bash
# See what would happen without making changes
bws-init --dry-run
```

### Force Re-initialization

```bash
# Overwrite existing project
bws-init --force
```

## Tips

1. **Placeholder Values**: bws-init automatically detects and replaces placeholder values like `your_api_key_here` with secure generated values for secrets like `SESSION_SECRET`.

2. **Team Collaboration**: Share the BWS project ID with your team so they can access the same secrets.

3. **Environment Variables**: The generated scripts respect the environment parameter, so you can easily switch between local, development, and production configs.

4. **CI/CD**: Store your `BWS_ACCESS_TOKEN` as a secret in your CI/CD platform for automated deployments.

## Next Steps

- Read the full [README](../README.md) for detailed documentation
- Check out [examples](./examples) for specific use cases
- Join the [discussions](https://github.com/yourusername/bws-init/discussions) for help and tips