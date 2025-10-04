# bootstrap-structure.ps1
#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Root folder where the solution directory will be created.")]
    [string]$RootPath = (Get-Location).Path,

    [Parameter(HelpMessage = "Name of the solution root folder.")]
    [string]$SolutionName = "SlackToTeamsSolution"
)

$ErrorActionPreference = 'Stop'

function Ensure-Directory {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        if ((Get-Item -LiteralPath $Path).PSIsContainer -ne $true) {
            throw "Path exists but is not a directory: $Path"
        }
        return
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

try {
    # Resolve solution root
    $SolutionRoot = Join-Path -Path $RootPath -ChildPath $SolutionName
    Ensure-Directory -Path $SolutionRoot

    # Define relative structure
    $RelativeDirs = @(
        'Orchestrator',
        'Phases',
        'Shared',
        'Dataset',
        (Join-Path 'Dataset' 'Default'),
        'Output',
        (Join-Path 'Output' 'Reports'),
        (Join-Path 'Output' 'Downloads'),
        (Join-Path 'Output' 'Uploads'),
        'Config',
        'Docs',
        (Join-Path 'Docs' 'Diagrams'),
        (Join-Path 'Docs' 'Guides'),
        'Checklists',
        'Logs',
        (Join-Path 'Logs' 'RunLogs'),
        'Temp'
    )

    # Create all directories
    $Created = New-Object System.Collections.Generic.List[string]
    foreach ($rel in $RelativeDirs) {
        $full = Join-Path $SolutionRoot $rel
        Ensure-Directory -Path $full
        $Created.Add($full) | Out-Null
    }

    # Summary
    Write-Host ""
    Write-Host "Solution root: $SolutionRoot"
    Write-Host "Created/ensured directories:" -ForegroundColor Cyan
    $Created | ForEach-Object { Write-Host "  - $_" }

    Write-Host ""
    Write-Host "Done. Proceed to script 2 after this completes successfully." -ForegroundColor Green
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}