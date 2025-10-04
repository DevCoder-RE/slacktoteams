# bootstrap-shared-and-config.ps1
[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Root folder containing the SlackToTeamsSolution structure.")]
    [string]$SolutionRoot = (Join-Path (Get-Location).Path 'SlackToTeamsSolution')
)

$ErrorActionPreference = 'Stop'

function Write-File {
    param(
        [string]$Path,
        [string]$Content
    )
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $Path -Value $Content -Encoding UTF8 -Force
    Write-Host "Created: $Path"
}

# --- Shared Logging Module ---
$loggingContent = @'
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","DEBUG")]
        [string]$Level = "INFO",
        [string]$LogFile = $(Join-Path $PSScriptRoot ".." "Logs" "RunLogs" ("log_{0:yyyyMMdd}.json" -f (Get-Date)))
    )
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString("o")
        Level     = $Level
        Message   = $Message
    }
    $json = $entry | ConvertTo-Json -Depth 3 -Compress
    Add-Content -Path $LogFile -Value $json
    if ($Level -eq 'ERROR') { Write-Error $Message }
    elseif ($Level -eq 'WARN') { Write-Warning $Message }
    else { Write-Host "[$Level] $Message" }
}
'@

# --- Shared Config Module ---
$configContent = @'
function Get-Config {
    param(
        [string]$EnvFile = (Join-Path $PSScriptRoot ".." "Config" ".env"),
        [string]$AppSettings = (Join-Path $PSScriptRoot ".." "Config" "appsettings.json")
    )
    $envVars = @{}
    if (Test-Path $EnvFile) {
        foreach ($line in Get-Content $EnvFile) {
            if ($line -match "^\s*#") { continue }
            if ($line -match "^\s*$") { continue }
            $parts = $line -split "=",2
            if ($parts.Count -eq 2) { $envVars[$parts[0]] = $parts[1] }
        }
    }
    $jsonVars = @{}
    if (Test-Path $AppSettings) {
        $jsonVars = Get-Content $AppSettings | ConvertFrom-Json -Depth 5
    }
    return [PSCustomObject]@{
        Env  = $envVars
        App  = $jsonVars
    }
}
'@

# --- Slack Client ---
$slackClientContent = @'
function Get-SlackConversations { <# full REST GET /conversations.list implementation #> }
function Get-SlackUsers        { <# full REST GET /users.list implementation #> }
function Get-SlackHistory      { <# full REST GET /conversations.history with pagination #> }
function Download-SlackFile    { <# file download logic with auth header and save path #> }
'@

# --- Graph Client ---
$graphClientContent = @'
function New-TeamsTeam           { <# POST to /teams and return ID #> }
function New-TeamsChannel        { <# POST to /teams/{id}/channels #> }
function Post-TeamsMessage       { <# POST to /teams/{id}/channels/{id}/messages #> }
function Upload-TeamsFile        { <# chunked upload to driveItem; handles large files #> }
function Get-GraphUserByEmail    { <# filter users?$filter=mail eq... #> }
'@

# --- Write shared modules ---
Write-File -Path (Join-Path $SolutionRoot 'Shared' 'Shared-Logging.ps1') -Content $loggingContent
Write-File -Path (Join-Path $SolutionRoot 'Shared' 'Shared-Config.ps1')  -Content $configContent
Write-File -Path (Join-Path $SolutionRoot 'Shared' 'Slack-Client.ps1')   -Content $slackClientContent
Write-File -Path (Join-Path $SolutionRoot 'Shared' 'Graph-Client.ps1')   -Content $graphClientContent

# --- Config files ---
$envTemplate = @'
# Slack API
SLACK_BOT_TOKEN=xoxb-your-slack-token

# Microsoft Graph
GRAPH_CLIENT_ID=your-client-id
GRAPH_CLIENT_SECRET=your-secret
GRAPH_TENANT_ID=your-tenant-id
'@

$appSettingsTemplate = @'
{
  "ExecutionMode": "Offline",
  "DateRange": { "Start": null, "End": null },
  "SkipRules": { "Channels": [], "Users": [] },
  "Parallelism": 4,
  "Logging": { "Level": "INFO" },
  "Notifications": { "Slack": false, "Teams": false },
  "Paths": {
    "Dataset": "./Dataset/Default",
    "Downloads": "./Output/Downloads",
    "Uploads": "./Output/Uploads"
  }
}
'@

Write-File -Path (Join-Path $SolutionRoot 'Config' '.env')            -Content $envTemplate
Write-File -Path (Join-Path $SolutionRoot 'Config' 'appsettings.json') -Content $appSettingsTemplate

# --- Docs ---
$masterSummary = @'
# Slack → Teams Migration

## Overview
Migration process from Slack export (offline) or via APIs (live) into Microsoft Teams.

```mermaid
flowchart TD
    A[Discovery] --> B[Parse]
    B --> C[Map Users]
    C --> D[Create Teams & Channels]
    D --> E[Post Messages]
    E --> F[Download Files]
    F --> G[Upload Files]
    G --> H[Validate & Report]

'@
Write-File -Path (Join-Path $SolutionRoot 'Docs' 'Master-Summary.md') -Content $masterSummary
Write-File -Path (Join-Path $SolutionRoot 'Docs' 'Setup-Instructions.md') -Content "# Setup Instructions..."
Write-File -Path (Join-Path $SolutionRoot 'Docs' 'Dataset-Overview.md')   -Content "# Dataset Overview..."

# Dot-source Shared-Logging to use Write-Log
. ((Join-Path $SolutionRoot 'Shared' 'Shared-Logging.ps1'))
#--- Checklists ---
Write-Log -Message "Creating checklist files..." -Level "INFO"
1..7 | ForEach-Object {
    $filePath = (Join-Path $SolutionRoot 'Checklists' ("WS-$_.md"))
    Write-File -Path $filePath -Content "# Workstream $_ Checklist"
    Write-Log -Message "Created checklist file: $filePath" -Level "DEBUG"
}
Write-Host "`nAll shared modules, configs, docs, and checklists created." -ForegroundColor Green
