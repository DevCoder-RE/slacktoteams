#Requires -Version 5.1
Set-StrictMode -Version Latest

. "$PSScriptRoot\Shared-Logging.ps1"
. "$PSScriptRoot\Shared-Json.ps1"

$Global:AppConfig = @{}

function Load-DotEnv {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return }
  Get-Content $Path | ForEach-Object {
    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*$') { return }
    $pair = $_ -split '=',2
    if ($pair.Length -eq 2) {
      $name = $pair[0].Trim()
      $value = $pair[1].Trim()
      [System.Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
  }
}

function Load-AppConfig {
  param(
    [string]$AppSettingsPath = "Config\appsettings.json",
    [string]$EnvPath = "Config\.env"
  )
  Load-DotEnv -Path $EnvPath
  if (-not (Test-Path $AppSettingsPath)) {
    throw "App settings file not found: $AppSettingsPath"
  }
  $json = Read-JsonFile -Path $AppSettingsPath
  $Global:AppConfig = $json
  # Merge env overrides
  $envMap = @{
    'Graph.TenantId'   = $env:GRAPH_TENANT_ID
    'Graph.ClientId'   = $env:GRAPH_CLIENT_ID
    'Graph.ClientSecret' = $env:GRAPH_CLIENT_SECRET
    'Slack.Token'      = $env:SLACK_TOKEN
  }
  foreach ($k in $envMap.Keys) {
    if ($envMap[$k]) { Set-Config $k $envMap[$k] }
  }
  Write-Log -Level Info -Message "Config loaded." -Context "Config"
}

function Get-Config {
  param([Parameter(Mandatory=$true)][string]$Key, [object]$Default)
  $parts = $Key -split '\.'
  $node = $Global:AppConfig
  foreach ($p in $parts) {
    if ($node.ContainsKey($p)) { $node = $node[$p] }
    else { return $Default }
  }
  return $node
}

function Set-Config {
  param([string]$Key, [Parameter(Mandatory=$true)]$Value)
  $parts = $Key -split '\.'
  $node = $Global:AppConfig
  for ($i=0; $i -lt $parts.Length; $i++) {
    $p = $parts[$i]
    if ($i -eq $parts.Length - 1) {
      $node[$p] = $Value
    } else {
      if (-not $node.ContainsKey($p)) { $node[$p] = @{} }
      $node = $node[$p]
    }
  }
}

function Save-Checkpoint {
  param(
    [Parameter(Mandatory=$true)][string]$Phase,
    [Parameter(Mandatory=$true)][hashtable]$State,
    [string]$CheckpointDir = "Output\Checkpoints"
  )
  if (-not (Test-Path $CheckpointDir)) { New-Item -ItemType Directory -Path $CheckpointDir | Out-Null }
  $checkpoint = @{
    Phase = $Phase
    Timestamp = (Get-Date).ToString('o')
    State = $State
  }
  $path = Join-Path $CheckpointDir "$Phase-checkpoint.json"
  Write-JsonFile -Path $path -Object $checkpoint
  Write-Log -Level Info -Message "Checkpoint saved for phase $Phase" -Context "Checkpoint"
}

function Load-Checkpoint {
  param(
    [Parameter(Mandatory=$true)][string]$Phase,
    [string]$CheckpointDir = "Output\Checkpoints"
  )
  $path = Join-Path $CheckpointDir "$Phase-checkpoint.json"
  if (-not (Test-Path $path)) { return $null }
  $checkpoint = Read-JsonFile -Path $path
  Write-Log -Level Info -Message "Checkpoint loaded for phase $Phase from $($checkpoint.Timestamp)" -Context "Checkpoint"
  return $checkpoint
}

function Resume-FromCheckpoint {
  param(
    [Parameter(Mandatory=$true)][string]$Phase,
    [Parameter(Mandatory=$true)][scriptblock]$ResumeAction,
    [string]$CheckpointDir = "Output\Checkpoints"
  )
  $checkpoint = Load-Checkpoint -Phase $Phase -CheckpointDir $CheckpointDir
  if ($checkpoint) {
    Write-Log -Level Info -Message "Resuming phase $Phase from checkpoint" -Context "Checkpoint"
    & $ResumeAction $checkpoint.State
  } else {
    Write-Log -Level Info -Message "No checkpoint found for phase $Phase. Starting fresh." -Context "Checkpoint"
  }
}

Export-ModuleMember -Function Load-AppConfig, Get-Config, Set-Config, Save-Checkpoint, Load-Checkpoint, Resume-FromCheckpoint
