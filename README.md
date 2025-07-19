# bws-init

A comprehensive command-line tool for **bidirectional** Bitwarden Secrets Manager (BWS) integration. Upload secrets from .env files to BWS or download secrets from BWS to new machines.

## Features

### 🚀 **Project Initialization** (Upload Mode)
- 🔍 **Auto-detection** of all environment files (.env, .env.local, .env.production, etc.)
- 🚀 **One-command setup** for Bitwarden Secrets Manager
- 🔐 **Secure secret generation** for placeholder values
- 📜 **Retrieval script generation** for easy secret syncing

### 🔄 **Project Synchronization** (Download Mode) 
- 📥 **Download secrets** from existing BWS projects to new machines
- 🔍 **Project discovery** - list and select from available BWS projects
- 🎯 **Environment targeting** - sync to specific .env files (.env.production, etc.)
- 🔄 **Bidirectional sync** - works both ways (upload/download)

### 🛠️ **General Features**
- 🖥️ **Cross-platform support** (Windows, Linux, macOS, WSL)
- 🏃 **Dry-run mode** to preview changes before applying
- 📦 **Zero dependencies** (except BWS CLI)
- 🔄 **Duplicate prevention** - reuses existing projects

## Installation

### Prerequisites

1. **Bitwarden Secrets Manager CLI** (`bws`)
   - Download from: https://bitwarden.com/help/secrets-manager-cli/
   - Add to your system PATH

2. **BWS Access Token**
   - Get from your Bitwarden account
   - Set as environment variable: `BWS_ACCESS_TOKEN`

### Quick Install

#### Option 1: Clone the repository
```bash
git clone https://github.com/cvsloane/bws-init.git
cd bws-init
```

#### Option 2: Download release
Download the latest release from the [Releases](https://github.com/cvsloane/bws-init/releases) page.

### Add to PATH

#### Linux/macOS
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$PATH:/path/to/bws-init/bin"
```

#### Windows
Add the `bin` directory to your system PATH through System Properties → Environment Variables.

## Usage

bws-init supports two main modes:

### 🚀 **Upload Mode** (Initialize Projects)

Upload secrets from .env files to a new BWS project:

```bash
# Initialize BWS in current directory
bws-init

# Initialize with specific project name
bws-init "My Project"

# Initialize for production environment only
bws-init --env production

# Dry run to see what would be created
bws-init --dry-run
```

### 📥 **Download Mode** (Sync from BWS)

Download secrets from existing BWS projects to new machines:

```bash
# List available BWS projects
bws-init --list-projects

# Sync all secrets from a project to .env
bws-init --sync "My Project"

# Sync production secrets to .env.production
bws-init --sync "My Project" --env production

# Dry run to see what would be downloaded
bws-init --sync "My Project" --dry-run
```

### Command-Line Options

```
# Upload Mode
bws-init [OPTIONS] [PROJECT_NAME]

# Download Mode  
bws-init --sync PROJECT_NAME [OPTIONS]
bws-init --list-projects

Options:
    -h, --help              Show help message
    -v, --version           Show version information
    -e, --env ENV           Process only specific environment (local|production|all)
    -o, --output DIR        Output directory for scripts (default: scripts/bitwarden)
    -f, --force             Overwrite existing project/files
    -d, --dry-run           Show what would be done without making changes
    -V, --verbose           Enable verbose output
    --no-scripts            Don't generate retrieval scripts
    --no-upload             Don't upload secrets (only create project)
    --sync PROJECT_NAME     Download secrets from existing BWS project
    --list-projects         List available BWS projects
```

### Examples

#### Initialize a new project
```bash
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
[SUCCESS] Project created with ID: 12345-67890
[INFO] Processing secrets...
[INFO] Processing .env...
[INFO] Processing .env.local...
[INFO] Processing .env.production...
[INFO] Processed 15/15 secrets
[SUCCESS] Created retrieval scripts in scripts/bitwarden
======================================
[SUCCESS] Initialization complete!

Project: my-app
ID: 12345-67890

To retrieve secrets:
  scripts/bitwarden/get-secrets.sh [environment]
  scripts/bitwarden/get-secrets.cmd [environment]

[INFO] Add .bws-project to your .gitignore
```

#### Retrieve secrets after initialization
```bash
# Get local development secrets
./scripts/bitwarden/get-secrets.sh local

# Get production secrets
./scripts/bitwarden/get-secrets.sh production
```

#### Sync from existing BWS project (New Machine Setup)

**Scenario**: You have a BWS project "my-web-app" and want to set up development on a new machine.

```bash
# Step 1: List available projects
$ bws-init --list-projects
Available BWS projects:
  my-web-app (ID: 123e4567-e89b-12d3-a456-426614174000)
  mobile-app (ID: 987fcdeb-51a2-4b3c-d456-123456789abc)

# Step 2: Sync all secrets to .env
$ bws-init --sync "my-web-app"
bws-init v1.1.0 - Sync Mode
======================================
[INFO] Finding BWS project: my-web-app
[INFO] Found project 'my-web-app' with ID: 123e4567-e89b-12d3-a456-426614174000
[INFO] Retrieving secrets from BWS...
[INFO] Found 15 secrets
[INFO] Creating .env...
[SUCCESS] Successfully synced 15 secrets to .env

# Step 3: Verify secrets downloaded
$ head -5 .env
# Environment variables synced from BWS project: my-web-app
# Project ID: 123e4567-e89b-12d3-a456-426614174000
# Synced: 2024-01-15T10:30:00Z
DATABASE_URL="postgresql://user:pass@localhost/myapp"
API_KEY="sk-1234567890abcdef"
```

#### Environment-specific sync
```bash
# Sync only production secrets to .env.production
bws-init --sync "my-web-app" --env production

# Sync staging secrets to .env.staging  
bws-init --sync "my-web-app" --env staging
```

## How It Works

### Upload Mode (Project Initialization)
1. **Environment Detection**: Scans for all `.env*` files in your project
2. **Project Creation**: Creates a new BWS project with your repository name
3. **Secret Upload**: Parses env files and uploads all variables to BWS
4. **Security Enhancement**: Automatically generates secure values for placeholder secrets
5. **Script Generation**: Creates platform-specific scripts for retrieving secrets

### Download Mode (Project Synchronization)
1. **Project Discovery**: Lists available BWS projects or finds by name
2. **Secret Retrieval**: Downloads all secrets from the specified BWS project
3. **Environment Mapping**: Creates appropriate .env files based on --env parameter
4. **File Generation**: Generates .env files with proper formatting and metadata
5. **Local Setup**: Creates .bws-project file and sync scripts for future use

## Environment File Support

bws-init automatically detects and processes:
- `.env` - Default environment
- `.env.local` - Local development
- `.env.development` - Development environment
- `.env.production` - Production environment
- `.env.example` - Example configuration
- `.env.*` - Any other env variants

## Security Features

- **Placeholder Detection**: Automatically detects placeholder values (e.g., `your_api_key_here`)
- **Secure Generation**: Generates cryptographically secure values for:
  - `SESSION_SECRET`
  - `CSRF_SECRET`
  - `JWT_SECRET`
  - `ENCRYPTION_KEY`
- **No Plain Text Storage**: All secrets are encrypted in Bitwarden
- **Access Control**: Requires BWS access token for all operations

## CI/CD Integration

### GitHub Actions
```yaml
- name: Setup BWS
  env:
    BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}
  run: |
    # Download bws-init
    curl -L https://github.com/cvsloane/bws-init/releases/latest/download/bws-init.tar.gz | tar -xz
    
    # Get production secrets
    ./bws-init/bin/bws-init --no-upload --no-scripts
    ./scripts/bitwarden/get-secrets.sh production
```

### GitLab CI
```yaml
before_script:
  - export BWS_ACCESS_TOKEN=$BWS_ACCESS_TOKEN
  - ./scripts/bitwarden/get-secrets.sh production
```

## Troubleshooting

### "BWS CLI not found"
- Ensure `bws` is installed and in your PATH
- Windows: May need to use `bws.exe`
- Test with: `bws --version`

### "BWS_ACCESS_TOKEN not set"
- Set the environment variable:
  - Linux/Mac: `export BWS_ACCESS_TOKEN="your-token"`
  - Windows: Set in System Environment Variables
  - WSL: May need to export from Windows: `export BWS_ACCESS_TOKEN=$(cmd.exe /c "echo %BWS_ACCESS_TOKEN%" | tr -d '\r')`

### "Project already initialized"
- Use `-f` flag to force re-initialization
- Or delete `.bws-project` file manually

### "No environment files found"
- Ensure you have at least one `.env` file
- Check file permissions
- Use `--no-upload` to create project without env files

## Development

### Project Structure
```
bws-init/
├── bin/
│   ├── bws-init          # Main entry point (bash)
│   └── bws-init.cmd      # Windows wrapper
├── src/
│   ├── bws-init.sh       # Bash implementation
│   └── bws-init.ps1      # PowerShell implementation
├── docs/
│   └── ...               # Additional documentation
├── scripts/
│   └── ...               # Build and release scripts
└── tests/
    └── ...               # Test suite
```

### Running Tests
```bash
./scripts/test.sh
```

### Building Release
```bash
./scripts/build-release.sh
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Bitwarden team for the excellent Secrets Manager
- Community contributors and testers

## Support

- **Issues**: [GitHub Issues](https://github.com/cvsloane/bws-init/issues)
- **Discussions**: [GitHub Discussions](https://github.com/cvsloane/bws-init/discussions)
- **Security**: Please report security issues privately to info@heavisidegroup.com