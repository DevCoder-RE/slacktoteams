[CmdletBinding()]
param(
    [string]$DestinationPath = ".\MigrationProject"
)

Write-Host "Creating new migration project at $DestinationPath..."

# Create folder structure
$folders = @(
    "Phases",
    "Shared",
    "Output",
    "Logs",
    "Reports"
)
foreach ($folder in $folders) {
    $fullPath = Join-Path $DestinationPath $folder
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath | Out-Null
        Write-Host "Created folder: $fullPath"
    }
}

# Copy phase scripts
$sourcePhases = "$PSScriptRoot\..\Phases\*"
Copy-Item -Path $sourcePhases -Destination (Join-Path $DestinationPath "Phases") -Recurse -Force

# Copy shared modules
$sourceShared = "$PSScriptRoot\..\Shared\*"
Copy-Item -Path $sourceShared -Destination (Join-Path $DestinationPath "Shared") -Recurse -Force

Write-Host "Migration project initialized."
