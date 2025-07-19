#!/usr/bin/env bash
# bws-init - Main implementation
# Bitwarden Secrets Manager project initialization tool

VERSION="1.1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BWS_CMD=""
PROJECT_ID=""
PROJECT_NAME=""
ENV_TYPE="all"
OUTPUT_DIR="scripts/bitwarden"
VERBOSE=false
DRY_RUN=false

# Function to display usage
usage() {
    cat << EOF
bws-init v${VERSION} - Initialize Bitwarden Secrets Manager for your project

Usage: bws-init [OPTIONS] [PROJECT_NAME]
       bws-init --sync PROJECT_NAME [OPTIONS]
       bws-init --list-projects

MODES:
    Default mode: Initialize BWS project and upload secrets from .env files
    --sync:      Download secrets from existing BWS project to .env files  
    --list:      List available BWS projects for syncing

Options:
    -h, --help              Show this help message
    -v, --version           Show version information
    -e, --env ENV           Process only specific environment (local|production|all)
    -o, --output DIR        Output directory for scripts (default: scripts/bitwarden)
    -f, --force             Overwrite existing project/files
    -d, --dry-run           Show what would be done without making changes
    -V, --verbose           Enable verbose output
    --no-scripts            Don't generate retrieval scripts
    --no-upload             Don't upload secrets (only create project)
    --sync PROJECT_NAME     Sync secrets from existing BWS project
    --list-projects         List available BWS projects

Examples:
    # Initialize new project
    bws-init                    # Initialize with auto-detected project name
    bws-init "My Project"       # Initialize with specific project name
    bws-init -e production      # Only process production env files
    bws-init -d                 # Dry run to see what would be created
    
    # Sync from existing project
    bws-init --sync "My Project"          # Download all secrets to .env
    bws-init --sync "My Project" -e prod  # Download only production secrets
    bws-init --list-projects              # Show available projects

EOF
}

# Function to display version
version() {
    echo "bws-init version ${VERSION}"
    echo "Bitwarden Secrets Manager initialization tool"
}

# Function to log messages
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        DEBUG)
            if [ "$VERBOSE" = true ]; then
                echo -e "[DEBUG] $message"
            fi
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    log DEBUG "Checking prerequisites..."
    
    # Check for BWS CLI
    if command -v bws.exe &> /dev/null; then
        BWS_CMD="bws.exe"
    elif command -v bws &> /dev/null; then
        BWS_CMD="bws"
    else
        log ERROR "Bitwarden Secrets Manager CLI not found"
        log INFO "Please install it from: https://bitwarden.com/help/secrets-manager-cli/"
        return 1
    fi
    
    log DEBUG "Found BWS CLI: $BWS_CMD"
    
    # Check for access token
    if [ -z "$BWS_ACCESS_TOKEN" ]; then
        # Try to get from Windows environment if in WSL
        if grep -qi microsoft /proc/version 2>/dev/null; then
            export BWS_ACCESS_TOKEN=$(cmd.exe /c "echo %BWS_ACCESS_TOKEN%" 2>/dev/null | tr -d '\r' | tr -d '\n')
        fi
        
        if [ -z "$BWS_ACCESS_TOKEN" ]; then
            log ERROR "BWS_ACCESS_TOKEN environment variable not set"
            log INFO "Please set your Bitwarden Secrets Manager access token"
            return 1
        fi
    fi
    
    log DEBUG "BWS_ACCESS_TOKEN is set"
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        log WARN "jq not found - JSON parsing may be limited"
    fi
    
    return 0
}

# Function to detect environment files
detect_env_files() {
    local env_files=()
    local patterns=(".env" ".env.local" ".env.development" ".env.production" ".env.example")
    
    log DEBUG "Detecting environment files..."
    
    # Add specific patterns based on env type
    if [ "$ENV_TYPE" != "all" ]; then
        patterns=(".env.$ENV_TYPE" ".env")
    fi
    
    # Find env files
    for pattern in "${patterns[@]}"; do
        while IFS= read -r -d '' file; do
            env_files+=("$file")
        done < <(find . -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
    done
    
    # Also check for .env.* files
    while IFS= read -r -d '' file; do
        env_files+=("$file")
    done < <(find . -maxdepth 1 -type f -name ".env.*" -print0 2>/dev/null)
    
    # Remove duplicates and sort
    printf '%s\n' "${env_files[@]}" | sort -u
}

# Function to parse env file
parse_env_file() {
    local file="$1"
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Extract KEY=VALUE pairs
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove surrounding quotes
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            
            echo "$key=$value"
        fi
    done < "$file"
}

# Function to create or update BWS project
create_bws_project() {
    local name="$1"
    
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would create BWS project: $name"
        PROJECT_ID="dry-run-project-id"
        return 0
    fi
    
    # First check if project already exists
    log DEBUG "Checking for existing project..."
    local projects
    projects=$($BWS_CMD project list 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        PROJECT_ID=$(echo "$projects" | jq -r ".[] | select(.name == \"$name\") | .id" 2>/dev/null)
        
        if [ -n "$PROJECT_ID" ]; then
            log INFO "Using existing project '$name' with ID: $PROJECT_ID"
            return 0
        fi
    fi
    
    # Create new project if it doesn't exist
    log INFO "Creating BWS project '$name'..."
    
    local result
    result=$($BWS_CMD project create "$name" 2>&1)
    
    if [ $? -eq 0 ]; then
        PROJECT_ID=$(echo "$result" | jq -r '.id' 2>/dev/null || echo "$result" | grep -oP '"id"\s*:\s*"\K[^"]+')
        log SUCCESS "Project created with ID: $PROJECT_ID"
        return 0
    else
        log ERROR "Failed to create project: $result"
        return 1
    fi
}

# Function to create or update secret
create_or_update_secret() {
    local key="$1"
    local value="$2"
    local note="$3"
    
    if [ "$DRY_RUN" = true ]; then
        log DEBUG "[DRY RUN] Would set secret: $key"
        return 0
    fi
    
    log DEBUG "Setting secret: $key"
    
    # Try to create the secret
    if $BWS_CMD secret create --note "$note" "$key" "$value" "$PROJECT_ID" &>/dev/null; then
        return 0
    else
        # Try to update if exists
        local secret_id
        secret_id=$($BWS_CMD secret list "$PROJECT_ID" 2>/dev/null | jq -r ".[] | select(.key == \"$key\") | .id" 2>/dev/null)
        
        if [ -n "$secret_id" ]; then
            if $BWS_CMD secret edit "$secret_id" --key "$key" --value "$value" --note "$note" &>/dev/null; then
                return 0
            fi
        fi
        
        return 1
    fi
}

# Function to generate secure value
generate_secure_value() {
    local key="$1"
    local value="$2"
    
    # Check if value looks like a placeholder
    if [[ "$value" =~ (your_|placeholder|example|change_me|xxx|todo|fixme) ]]; then
        # Generate secure values for specific key types
        if [[ "$key" =~ (SESSION_SECRET|CSRF_SECRET|JWT_SECRET|ENCRYPTION_KEY) ]]; then
            if command -v openssl &> /dev/null; then
                value=$(openssl rand -base64 32 2>/dev/null)
                log DEBUG "Generated secure value for $key"
            else
                value="generated_secret_$(date +%s)"
                log WARN "openssl not found, using timestamp-based secret for $key"
            fi
        fi
    fi
    
    echo "$value"
}

# Function to create retrieval scripts
create_retrieval_scripts() {
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would create retrieval scripts in $OUTPUT_DIR"
        return 0
    fi
    
    log INFO "Creating retrieval scripts..."
    
    mkdir -p "$OUTPUT_DIR"
    
    # Create bash retrieval script
    cat > "$OUTPUT_DIR/get-secrets.sh" << EOF
#!/usr/bin/env bash
# Auto-generated BWS secret retrieval script
# Generated by bws-init v${VERSION}

PROJECT_ID="$PROJECT_ID"
ENV="\${1:-local}"

echo "Retrieving secrets from BWS..."

# Detect BWS command
if command -v bws.exe &> /dev/null; then
    BWS_CMD="bws.exe"
else
    BWS_CMD="bws"
fi

# Check for access token
if [ -z "\$BWS_ACCESS_TOKEN" ]; then
    if grep -qi microsoft /proc/version 2>/dev/null; then
        export BWS_ACCESS_TOKEN=\$(cmd.exe /c "echo %BWS_ACCESS_TOKEN%" 2>/dev/null | tr -d '\r' | tr -d '\n')
    fi
    
    if [ -z "\$BWS_ACCESS_TOKEN" ]; then
        echo "ERROR: BWS_ACCESS_TOKEN not set" >&2
        exit 1
    fi
fi

# Function to get secret value
get_secret_value() {
    local key="\$1"
    local secret_id
    secret_id=\$(\$BWS_CMD secret list "\$PROJECT_ID" 2>/dev/null | jq -r ".[] | select(.key == \\"\$key\\") | .id")
    if [ -n "\$secret_id" ]; then
        \$BWS_CMD secret get "\$secret_id" 2>/dev/null | jq -r '.value // empty'
    fi
}

# Determine output file
OUTPUT_FILE=".env.\$ENV"
[ "\$ENV" = "local" ] && OUTPUT_FILE=".env.local"

# Create env file
echo "# Generated from BWS at \$(date)" > "\$OUTPUT_FILE"
echo "" >> "\$OUTPUT_FILE"

# Get all secrets
\$BWS_CMD secret list "\$PROJECT_ID" 2>/dev/null | jq -r '.[].key' | sort | while read -r key; do
    value=\$(get_secret_value "\$key")
    if [ -n "\$value" ]; then
        echo "\$key=\$value" >> "\$OUTPUT_FILE"
    fi
done

echo "✓ Created \$OUTPUT_FILE"
EOF

    chmod +x "$OUTPUT_DIR/get-secrets.sh"
    
    # Create Windows batch file
    cat > "$OUTPUT_DIR/get-secrets.cmd" << EOF
@echo off
REM Auto-generated BWS secret retrieval script
REM Generated by bws-init v${VERSION}

where wsl >nul 2>nul
if %ERRORLEVEL% == 0 (
    wsl bash -c "cd '%cd%' && bash $OUTPUT_DIR/get-secrets.sh %1"
) else (
    powershell -ExecutionPolicy Bypass -File "$OUTPUT_DIR/get-secrets.ps1" %1
)
EOF

    # Create PowerShell script
    cat > "$OUTPUT_DIR/get-secrets.ps1" << 'EOF'
# Auto-generated BWS secret retrieval script
param(
    [string]$Environment = "local"
)

$projectId = "PROJECT_ID_PLACEHOLDER"

Write-Host "Retrieving secrets from BWS..."

# Check for access token
if (-not $env:BWS_ACCESS_TOKEN) {
    Write-Host "ERROR: BWS_ACCESS_TOKEN not set" -ForegroundColor Red
    exit 1
}

try {
    $secrets = bws.exe secret list $projectId | ConvertFrom-Json
    
    $outputFile = ".env.$Environment"
    if ($Environment -eq "local") {
        $outputFile = ".env.local"
    }
    
    "# Generated from BWS at $(Get-Date)" | Out-File $outputFile
    "" | Out-File $outputFile -Append
    
    foreach ($secret in $secrets | Sort-Object key) {
        $secretValue = bws.exe secret get $secret.id | ConvertFrom-Json
        "$($secret.key)=$($secretValue.value)" | Out-File $outputFile -Append
    }
    
    Write-Host "✓ Created $outputFile" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
EOF

    # Replace PROJECT_ID in PowerShell script
    sed -i "s/PROJECT_ID_PLACEHOLDER/$PROJECT_ID/g" "$OUTPUT_DIR/get-secrets.ps1" 2>/dev/null || \
    perl -pi -e "s/PROJECT_ID_PLACEHOLDER/$PROJECT_ID/g" "$OUTPUT_DIR/get-secrets.ps1"
    
    log SUCCESS "Created retrieval scripts in $OUTPUT_DIR"
}

# Function to save project info
save_project_info() {
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would save project info to .bws-project"
        return 0
    fi
    
    cat > .bws-project << EOF
PROJECT_NAME=$PROJECT_NAME
PROJECT_ID=$PROJECT_ID
CREATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BWS_INIT_VERSION=$VERSION
EOF
    
    log DEBUG "Saved project info to .bws-project"
}

# Function to list available BWS projects
list_projects() {
    log INFO "Available BWS projects:"
    
    local projects
    projects=$($BWS_CMD project list 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log ERROR "Failed to list projects"
        return 1
    fi
    
    if [ "$(echo "$projects" | jq '. | length')" -eq 0 ]; then
        log WARN "No BWS projects found"
        return 0
    fi
    
    echo "$projects" | jq -r '.[] | "  \(.name) (ID: \(.id))"'
    echo ""
    log INFO "Use: bws-init --sync \"PROJECT_NAME\" to sync from a project"
}

# Function to find project by name
find_project_by_name() {
    local name="$1"
    
    local projects
    projects=$($BWS_CMD project list 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log ERROR "Failed to list projects"
        return 1
    fi
    
    echo "$projects" | jq -r ".[] | select(.name == \"$name\") | .id"
}

# Function to sync secrets from BWS project
sync_from_project() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        log ERROR "Project name required for sync mode"
        return 1
    fi
    
    log INFO "Finding BWS project: $project_name"
    
    local project_id
    project_id=$(find_project_by_name "$project_name")
    
    if [ -z "$project_id" ]; then
        log ERROR "Project '$project_name' not found"
        log INFO "Available projects:"
        list_projects
        return 1
    fi
    
    log INFO "Found project '$project_name' with ID: $project_id"
    
    # Get secrets from BWS
    log INFO "Retrieving secrets from BWS..."
    local secrets
    secrets=$($BWS_CMD secret list "$project_id" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log ERROR "Failed to retrieve secrets from project"
        return 1
    fi
    
    local secret_count
    secret_count=$(echo "$secrets" | jq '. | length')
    log INFO "Found $secret_count secrets"
    
    if [ "$secret_count" -eq 0 ]; then
        log WARN "No secrets found in project"
        return 0
    fi
    
    # Determine target env file based on ENV_TYPE
    local target_file=".env"
    if [ "$ENV_TYPE" != "all" ]; then
        target_file=".env.$ENV_TYPE"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] Would create/update: $target_file"
        log INFO "[DRY RUN] Secrets to download:"
        echo "$secrets" | jq -r '.[] | "  \(.key)"'
        return 0
    fi
    
    # Check if target file exists and ask for confirmation
    if [ -f "$target_file" ] && [ "$FORCE" != true ]; then
        log WARN "File $target_file already exists"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log INFO "Sync cancelled"
            return 0
        fi
    fi
    
    # Create env file from secrets
    log INFO "Creating $target_file..."
    
    {
        echo "# Environment variables synced from BWS project: $project_name"
        echo "# Project ID: $project_id"
        echo "# Synced: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "# BWS-Init Version: $VERSION"
        echo ""
        
        echo "$secrets" | jq -r '.[] | "\(.key)=\"\(.value)\""'
    } > "$target_file"
    
    log SUCCESS "Successfully synced $secret_count secrets to $target_file"
    
    # Create .bws-project file for future operations
    cat > .bws-project << EOF
PROJECT_NAME=$project_name
PROJECT_ID=$project_id
SYNCED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BWS_INIT_VERSION=$VERSION
MODE=sync
EOF
    
    log INFO "Created .bws-project file for future operations"
    
    # Optionally create sync scripts
    if [ "$NO_SCRIPTS" != true ]; then
        PROJECT_ID="$project_id"
        PROJECT_NAME="$project_name"
        create_retrieval_scripts
    fi
    
    return 0
}

# Main function
main() {
    local FORCE=false
    local NO_SCRIPTS=false
    local NO_UPLOAD=false
    local SYNC_MODE=false
    local LIST_PROJECTS=false
    local SYNC_PROJECT_NAME=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                version
                exit 0
                ;;
            -e|--env)
                ENV_TYPE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -V|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-scripts)
                NO_SCRIPTS=true
                shift
                ;;
            --no-upload)
                NO_UPLOAD=true
                shift
                ;;
            --sync)
                SYNC_MODE=true
                SYNC_PROJECT_NAME="$2"
                shift 2
                ;;
            --list-projects)
                LIST_PROJECTS=true
                shift
                ;;
            -*)
                log ERROR "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                PROJECT_NAME="$1"
                shift
                ;;
        esac
    done
    
    # Check prerequisites first
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Handle special modes
    if [ "$LIST_PROJECTS" = true ]; then
        list_projects
        exit 0
    fi
    
    if [ "$SYNC_MODE" = true ]; then
        echo -e "${BLUE}bws-init v${VERSION} - Sync Mode${NC}"
        echo "======================================"
        echo ""
        sync_from_project "$SYNC_PROJECT_NAME"
        exit $?
    fi
    
    # Header for default mode
    echo -e "${BLUE}bws-init v${VERSION}${NC}"
    echo "======================================"
    echo ""
    
    # Get project name if not provided
    if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME=$(basename "$PWD")
        log INFO "Using directory name as project: $PROJECT_NAME"
    fi
    
    # Check for existing project
    if [ -f .bws-project ] && [ "$FORCE" != true ]; then
        log ERROR "Project already initialized. Use -f to force re-initialization."
        exit 1
    fi
    
    # Detect environment files
    log INFO "Detecting environment files..."
    local env_files
    env_files=$(detect_env_files)
    
    if [ -z "$env_files" ]; then
        log WARN "No environment files found"
        log INFO "Create a .env file first, or use --no-upload to only create the project"
        
        if [ "$NO_UPLOAD" != true ]; then
            exit 1
        fi
    else
        log INFO "Found environment files:"
        echo "$env_files" | while read -r file; do
            echo "  - $file"
        done
    fi
    
    # Create BWS project
    if ! create_bws_project "$PROJECT_NAME"; then
        exit 1
    fi
    
    # Upload secrets
    if [ "$NO_UPLOAD" != true ] && [ -n "$env_files" ]; then
        log INFO "Processing secrets..."
        
        local total_secrets=0
        local successful_secrets=0
        declare -A processed_keys
        
        while IFS= read -r env_file; do
            [ -z "$env_file" ] && continue
            
            log INFO "Processing $env_file..."
            
            # Determine environment type from filename
            local env_type="default"
            if [[ "$env_file" =~ \.local ]]; then
                env_type="local"
            elif [[ "$env_file" =~ \.production ]]; then
                env_type="production"
            elif [[ "$env_file" =~ \.development ]]; then
                env_type="development"
            fi
            
            # Parse and upload secrets
            while IFS='=' read -r key value; do
                # Skip if already processed
                if [ -n "${processed_keys[$key]}" ]; then
                    continue
                fi
                
                processed_keys[$key]=1
                ((total_secrets++))
                
                # Generate secure value if needed
                value=$(generate_secure_value "$key" "$value")
                
                # Create or update secret
                if create_or_update_secret "$key" "$value" "From $env_file ($env_type)"; then
                    ((successful_secrets++))
                fi
            done < <(parse_env_file "$env_file")
        done <<< "$env_files"
        
        log INFO "Processed $successful_secrets/$total_secrets secrets"
    fi
    
    # Create retrieval scripts
    if [ "$NO_SCRIPTS" != true ]; then
        create_retrieval_scripts
    fi
    
    # Save project info
    save_project_info
    
    # Summary
    echo ""
    echo "======================================"
    log SUCCESS "Initialization complete!"
    echo ""
    echo "Project: $PROJECT_NAME"
    echo "ID: $PROJECT_ID"
    
    if [ "$NO_SCRIPTS" != true ]; then
        echo ""
        echo "To retrieve secrets:"
        echo "  $OUTPUT_DIR/get-secrets.sh [environment]"
        echo "  $OUTPUT_DIR/get-secrets.cmd [environment]"
    fi
    
    echo ""
    log INFO "Add .bws-project to your .gitignore"
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi