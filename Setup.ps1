[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Create directories
$dirs = @(
  'Config',
  'Config\mappings',
  'Data\SlackExport',
  'Logs',
  'Output',
  'Output\Phase1-ParseSlack',
  'Output\Phase2-MapUsers',
  'Output\Phase3-Provision',
  'Output\Phase4-PostMessages',
  'Output\Phase5-DownloadFiles',
  'Output\Phase6-UploadFiles',
  'Output\Phase7-Validate',
  'Output\Phase8-RetryFixups',
  'Reports',
  'Shared',
  'Phases'
)
$dirs | ForEach-Object { if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ | Out-Null } }

# Write sample config files if not present
if (-not (Test-Path 'Config\appsettings.json')) {
  Copy-Item 'Config\appsettings.sample.json' 'Config\appsettings.json' -Force
}

Write-Host "Setup complete. Fill Config\.env and Config\appsettings.json, place Slack export under Data\SlackExport, then run .\Run-All.ps1" -ForegroundColor Green
