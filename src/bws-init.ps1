# bws-init.ps1 - PowerShell implementation
# Bitwarden Secrets Manager project initialization tool

param(
    [string]$ProjectName,
    [string]$Environment = "all",
    [string]$OutputDir = "scripts\bitwarden",
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Verbose,
    [switch]$NoScripts,
    [switch]$NoUpload,
    [switch]$Help,
    [switch]$Version
)

$script:VERSION = "1.1.0"

# Enable verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Show help
if ($Help) {
    @"
bws-init v$VERSION - Initialize Bitwarden Secrets Manager for your project

Usage: bws-init.ps1 [OPTIONS] [PROJECT_NAME]

Options:
    -ProjectName NAME       Project name (default: current directory name)
    -Environment ENV        Process only specific environment (local|production|all)
    -OutputDir DIR          Output directory for scripts (default: scripts\bitwarden)
    -Force                  Overwrite existing project
    -DryRun                 Show what would be done without making changes
    -Verbose                Enable verbose output
    -NoScripts              Don't generate retrieval scripts
    -NoUpload               Don't upload secrets (only create project)
    -Help                   Show this help message
    -Version                Show version information

Examples:
    .\bws-init.ps1                      # Initialize with auto-detected project name
    .\bws-init.ps1 "My Project"         # Initialize with specific project name
    .\bws-init.ps1 -Environment production  # Only process production env files
    .\bws-init.ps1 -DryRun              # Dry run to see what would be created

"@
    exit 0
}

# Show version
if ($Version) {
    Write-Host "bws-init version $VERSION"
    Write-Host "Bitwarden Secrets Manager initialization tool"
    exit 0
}

# Functions
function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )
    
    switch ($Level) {
        "ERROR" {
            Write-Host "[ERROR] $Message" -ForegroundColor Red
        }
        "WARN" {
            Write-Host "[WARN] $Message" -ForegroundColor Yellow
        }
        "INFO" {
            Write-Host "[INFO] $Message" -ForegroundColor Blue
        }
        "SUCCESS" {
            Write-Host "[SUCCESS] $Message" -ForegroundColor Green
        }
        "DEBUG" {
            Write-Verbose "[DEBUG] $Message"
        }
        default {
            Write-Host $Message
        }
    }
}

function Test-Prerequisites {
    Write-Verbose "Checking prerequisites..."
    
    # Check for BWS CLI
    $bwsPath = Get-Command bws.exe -ErrorAction SilentlyContinue
    if (-not $bwsPath) {
        Write-Log ERROR "Bitwarden Secrets Manager CLI not found"
        Write-Log INFO "Please install it from: https://bitwarden.com/help/secrets-manager-cli/"
        return $false
    }
    
    Write-Verbose "Found BWS CLI: $($bwsPath.Path)"
    
    # Check for access token
    if (-not $env:BWS_ACCESS_TOKEN) {
        Write-Log ERROR "BWS_ACCESS_TOKEN environment variable not set"
        Write-Log INFO "Please set your Bitwarden Secrets Manager access token"
        return $false
    }
    
    Write-Verbose "BWS_ACCESS_TOKEN is set"
    return $true
}

function Get-EnvFiles {
    param(
        [string]$EnvType = "all"
    )
    
    Write-Verbose "Detecting environment files..."
    
    $patterns = @(".env", ".env.local", ".env.development", ".env.production", ".env.example")
    
    if ($EnvType -ne "all") {
        $patterns = @(".env.$EnvType", ".env")
    }
    
    $envFiles = @()
    
    foreach ($pattern in $patterns) {
        $files = Get-ChildItem -Path . -Filter "$pattern*" -File -ErrorAction SilentlyContinue
        $envFiles += $files
    }
    
    # Remove duplicates
    $envFiles | Select-Object -Unique
}

function Read-EnvFile {
    param(
        [string]$FilePath
    )
    
    $variables = @{}
    
    if (Test-Path $FilePath) {
        Get-Content $FilePath | ForEach-Object {
            $line = $_.Trim()
            
            # Skip empty lines and comments
            if ($line -and -not $line.StartsWith('#')) {
                # Match KEY=VALUE pattern
                if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                    $key = $matches[1]
                    $value = $matches[2]
                    
                    # Remove surrounding quotes
                    $value = $value.Trim('"', "'")
                    
                    $variables[$key] = $value
                }
            }
        }
    }
    
    return $variables
}

function New-BWSProject {
    param(
        [string]$Name
    )
    
    if ($DryRun) {
        Write-Log INFO "[DRY RUN] Would create BWS project: $Name"
        return "dry-run-project-id"
    }
    
    Write-Log INFO "Creating BWS project '$Name'..."
    
    try {
        $result = bws.exe project create $Name 2>&1 | Out-String
        $jsonResult = $result | ConvertFrom-Json
        $projectId = $jsonResult.id
        Write-Log SUCCESS "Project created with ID: $projectId"
        return $projectId
    }
    catch {
        Write-Verbose "Project creation failed, checking if it already exists..."
        
        try {
            $projects = bws.exe project list 2>&1 | Out-String | ConvertFrom-Json
            $existingProject = $projects | Where-Object { $_.name -eq $Name }
            
            if ($existingProject) {
                $projectId = $existingProject.id
                Write-Log WARN "Project already exists with ID: $projectId"
                return $projectId
            }
        }
        catch {
            Write-Log ERROR "Failed to create or find project"
            return $null
        }
    }
}

function Set-BWSSecret {
    param(
        [string]$ProjectId,
        [string]$Key,
        [string]$Value,
        [string]$Note
    )
    
    if ($DryRun) {
        Write-Verbose "[DRY RUN] Would set secret: $Key"
        return $true
    }
    
    Write-Verbose "Setting secret: $Key"
    
    try {
        # Try to create the secret
        $null = bws.exe secret create --note $Note $Key $Value $ProjectId 2>&1
        return $true
    }
    catch {
        # Try to update if exists
        try {
            $secrets = bws.exe secret list $ProjectId 2>&1 | Out-String | ConvertFrom-Json
            $existingSecret = $secrets | Where-Object { $_.key -eq $Key }
            
            if ($existingSecret) {
                $null = bws.exe secret edit $existingSecret.id --key $Key --value $Value --note $Note 2>&1
                return $true
            }
        }
        catch {
            return $false
        }
    }
}

function Get-SecureValue {
    param(
        [string]$Key,
        [string]$Value
    )
    
    # Check if value looks like a placeholder
    if ($Value -match "(your_|placeholder|example|change_me|xxx|todo|fixme)") {
        # Generate secure values for specific key types
        if ($Key -match "(SESSION_SECRET|CSRF_SECRET|JWT_SECRET|ENCRYPTION_KEY)") {
            $bytes = New-Object byte[] 32
            [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
            $Value = [Convert]::ToBase64String($bytes)
            Write-Verbose "Generated secure value for $Key"
        }
    }
    
    return $Value
}

function New-RetrievalScripts {
    param(
        [string]$ProjectId,
        [string]$OutputDirectory
    )
    
    if ($DryRun) {
        Write-Log INFO "[DRY RUN] Would create retrieval scripts in $OutputDirectory"
        return
    }
    
    Write-Log INFO "Creating retrieval scripts..."
    
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    
    # Create PowerShell retrieval script
    @"
# Auto-generated BWS secret retrieval script
# Generated by bws-init v$VERSION
param(
    [string]`$Environment = "local"
)

`$projectId = "$ProjectId"

Write-Host "Retrieving secrets from BWS..."

# Check for access token
if (-not `$env:BWS_ACCESS_TOKEN) {
    Write-Host "ERROR: BWS_ACCESS_TOKEN not set" -ForegroundColor Red
    exit 1
}

try {
    `$secrets = bws.exe secret list `$projectId | ConvertFrom-Json
    
    `$outputFile = ".env.`$Environment"
    if (`$Environment -eq "local") {
        `$outputFile = ".env.local"
    }
    
    "# Generated from BWS at `$(Get-Date)" | Out-File `$outputFile
    "" | Out-File `$outputFile -Append
    
    foreach (`$secret in `$secrets | Sort-Object key) {
        `$secretValue = bws.exe secret get `$secret.id | ConvertFrom-Json
        "`$(`$secret.key)=`$(`$secretValue.value)" | Out-File `$outputFile -Append
    }
    
    Write-Host "✓ Created `$outputFile" -ForegroundColor Green
}
catch {
    Write-Host "Error: `$_" -ForegroundColor Red
    exit 1
}
"@ | Out-File -FilePath "$OutputDirectory\get-secrets.ps1" -Encoding UTF8
    
    # Create batch wrapper
    @"
@echo off
REM Auto-generated BWS secret retrieval script
REM Generated by bws-init v$VERSION

powershell -ExecutionPolicy Bypass -File "%~dp0get-secrets.ps1" %1
"@ | Out-File -FilePath "$OutputDirectory\get-secrets.cmd" -Encoding ASCII
    
    Write-Log SUCCESS "Created retrieval scripts in $OutputDirectory"
}

# Main execution
Write-Host "bws-init v$VERSION" -ForegroundColor Blue
Write-Host "======================================"
Write-Host ""

# Check prerequisites
if (-not (Test-Prerequisites)) {
    exit 1
}

# Get project name if not provided
if (-not $ProjectName) {
    $ProjectName = Split-Path -Leaf $PWD
    Write-Log INFO "Using directory name as project: $ProjectName"
}

# Check for existing project
if ((Test-Path .bws-project) -and -not $Force) {
    Write-Log ERROR "Project already initialized. Use -Force to re-initialize."
    exit 1
}

# Detect environment files
Write-Log INFO "Detecting environment files..."
$envFiles = Get-EnvFiles -EnvType $Environment

if ($envFiles.Count -eq 0) {
    Write-Log WARN "No environment files found"
    Write-Log INFO "Create a .env file first, or use -NoUpload to only create the project"
    
    if (-not $NoUpload) {
        exit 1
    }
}
else {
    Write-Log INFO "Found environment files:"
    foreach ($file in $envFiles) {
        Write-Host "  - $($file.Name)"
    }
}

# Create BWS project
$projectId = New-BWSProject -Name $ProjectName
if (-not $projectId) {
    exit 1
}

# Upload secrets
if (-not $NoUpload -and $envFiles.Count -gt 0) {
    Write-Log INFO "Processing secrets..."
    
    $totalSecrets = 0
    $successfulSecrets = 0
    $processedKeys = @{}
    
    foreach ($envFile in $envFiles) {
        Write-Log INFO "Processing $($envFile.Name)..."
        
        # Determine environment type
        $envType = "default"
        if ($envFile.Name -match "\.local") { $envType = "local" }
        elseif ($envFile.Name -match "\.production") { $envType = "production" }
        elseif ($envFile.Name -match "\.development") { $envType = "development" }
        
        # Parse and upload secrets
        $variables = Read-EnvFile -FilePath $envFile.FullName
        
        foreach ($key in $variables.Keys) {
            # Skip if already processed
            if ($processedKeys.ContainsKey($key)) {
                continue
            }
            
            $processedKeys[$key] = $true
            $totalSecrets++
            
            # Generate secure value if needed
            $value = Get-SecureValue -Key $key -Value $variables[$key]
            
            # Create or update secret
            if (Set-BWSSecret -ProjectId $projectId -Key $key -Value $value -Note "From $($envFile.Name) ($envType)") {
                $successfulSecrets++
            }
        }
    }
    
    Write-Log INFO "Processed $successfulSecrets/$totalSecrets secrets"
}

# Create retrieval scripts
if (-not $NoScripts) {
    New-RetrievalScripts -ProjectId $projectId -OutputDirectory $OutputDir
}

# Save project info
if (-not $DryRun) {
    @"
PROJECT_NAME=$ProjectName
PROJECT_ID=$projectId
CREATED=$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
BWS_INIT_VERSION=$VERSION
"@ | Out-File -FilePath ".bws-project" -Encoding UTF8
    
    Write-Verbose "Saved project info to .bws-project"
}

# Summary
Write-Host ""
Write-Host "======================================"
Write-Log SUCCESS "Initialization complete!"
Write-Host ""
Write-Host "Project: $ProjectName"
Write-Host "ID: $projectId"

if (-not $NoScripts) {
    Write-Host ""
    Write-Host "To retrieve secrets:"
    Write-Host "  .\$OutputDir\get-secrets.ps1 [environment]"
    Write-Host "  $OutputDir\get-secrets.cmd [environment]"
}

Write-Host ""
Write-Log INFO "Add .bws-project to your .gitignore"