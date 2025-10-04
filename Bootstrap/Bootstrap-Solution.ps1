<# 
Bootstrap-Solution.ps1
Creates the complete Slack→Teams migration solution scaffold with:
- Orchestrator (Migrate.ps1)
- Phase stubs and shared utils
- Simulated Slack export dataset
- Docs (master summary, setup guide, dataset overview)
- Workstream dry-run checklists (WS1–WS7)
- Config templates (.env examples, appsettings.json full/min)

Requires PowerShell 7+ on Windows.
#>

[CmdletBinding()]
param(
  [Parameter()] [string] $RootPath = ".\SlackToTeamsSolution"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Dir { param([string]$p) if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }

# ---------------------------
# Create folder structure
# ---------------------------
$dirs = @(
  $RootPath,
  Join-Path $RootPath 'scripts',
  Join-Path $RootPath 'scripts\phases',
  Join-Path $RootPath 'docs',
  Join-Path $RootPath 'docs\checklists',
  Join-Path $RootPath 'docs\workstreams',
  Join-Path $RootPath 'config',
  Join-Path $RootPath 'testdata'
)
$dirs | ForEach-Object { New-Dir $_ }

# Short helpers
function Out-Utf8 { param([string]$Path,[string]$Text) $Text | Set-Content -Path $Path -Encoding UTF8 -NoNewline:$false }

# ---------------------------
# Write shared utils
# ---------------------------
$sharedUtils = @'
# scripts/shared-utils.ps1
Set-StrictMode -Version Latest

function Convert-SlackTsToDateTime {
  param([Parameter(Mandatory)][string]$Ts)
  $parts = $Ts -split '\.'
  if ($parts.Count -ge 1 -and ($parts[0] -as [long]) -ne $null) {
    return [DateTimeOffset]::FromUnixTimeSeconds([long]$parts[0]).UtcDateTime
  }
  return [DateTime]::Parse($Ts).ToUniversalTime()
}

function Get-DateRange {
  param([datetime]$StartDate,[datetime]$EndDate)
  $start = if ($StartDate) { $StartDate.ToUniversalTime() } else { [datetime]::MinValue }
  $end   = if ($EndDate)   { $EndDate.ToUniversalTime() }   else { [datetime]::MaxValue }
  return @{ Start=$start; End=$end }
}

function Test-InDateRange {
  param([datetime]$When,[datetime]$Start,[datetime]$End)
  return ($When -ge $Start -and $When -le $End)
}

function Should-SkipMessage {
  param([object]$Message, [hashtable]$SkipCfg)
  if ($SkipCfg.SkipMessagesContaining) {
    foreach ($pattern in $SkipCfg.SkipMessagesContaining) {
      if ($Message.text -match [Regex]::Escape($pattern)) { return $true }
    }
  }
  return $false
}

function Should-SkipFile {
  param([object]$File, [hashtable]$SkipCfg)
  if ($SkipCfg.SkipFileTypes) {
    $ext = [System.IO.Path]::GetExtension($File.name).TrimStart('.').ToLower()
    if ($SkipCfg.SkipFileTypes -contains $ext) { return $true }
  }
  if ($SkipCfg.SkipFileMaxSizeMB -and $File.size) {
    $maxBytes = $SkipCfg.SkipFileMaxSizeMB * 1MB
    if ($File.size -gt $maxBytes) { return $true }
  }
  return $false
}
'@
Out-Utf8 (Join-Path $RootPath 'scripts\shared-utils.ps1') $sharedUtils

# ---------------------------
# Orchestrator (Migrate.ps1)
# ---------------------------
$orchestrator = @'
# Migrate.ps1 – Orchestration with Phase 0 discovery, inventory outputs, config/env, auth, date-range, skip rules, retries, notifications, selective phases, reporting.

[CmdletBinding(DefaultParameterSetName='Migrate')]
param(
  [Parameter()] [string] $ExportRoot   = ".\testdata\slack_export",
  [Parameter()] [string] $StatePath    = ".\state",
  [Parameter()] [string] $ConfigPath   = ".\config\appsettings.json",
  [Parameter()] [string] $EnvPath      = ".\.env",

  # Inventory-only
  [Parameter(ParameterSetName='Inventory')] [switch] $ListChannels,
  [Parameter(ParameterSetName='Inventory')] [switch] $ListUsers,
  [Parameter(ParameterSetName='Inventory')] [switch] $ListFiles,
  [Parameter(ParameterSetName='Inventory')] [switch] $AsTable,
  [Parameter(ParameterSetName='Inventory')] [switch] $AsMarkdown,
  [Parameter(ParameterSetName='Inventory')] [string] $AsCsv,
  [Parameter(ParameterSetName='Inventory')] [switch] $Print,
  [Parameter(ParameterSetName='Inventory')] [switch] $RefreshInventory,

  # Filters & run controls
  [Parameter(ParameterSetName='Migrate')] [string[]] $ChannelFilter,
  [Parameter(ParameterSetName='Migrate')] [string[]] $UserFilter,
  [Parameter(ParameterSetName='Migrate')] [switch]   $DeltaMode,
  [Parameter(ParameterSetName='Migrate')] [switch]   $OfflineMode,
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('Auto','ConfirmOnError','ConfirmEachPhase')] [string] $Mode = 'Auto',
  [Parameter(ParameterSetName='Migrate')] [int] $StartAtPhase = 0,
  [Parameter(ParameterSetName='Migrate')] [int] $EndAtPhase   = 99,
  [Parameter(ParameterSetName='Migrate')] [int[]] $ExcludePhases,
  [Parameter(ParameterSetName='Migrate')] [int[]] $OnlyPhases,
  [Parameter(ParameterSetName='Migrate')] [string] $Phases, # e.g. "3,5-6" (alt syntax)

  # Date range
  [Parameter(ParameterSetName='Migrate')] [datetime] $StartDate,
  [Parameter(ParameterSetName='Migrate')] [datetime] $EndDate,
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('Channels','DMs','All')] [string] $DateRangeTargets = 'All',
  [Parameter(ParameterSetName='Migrate')] [switch] $IncludeFilesInDateRange,
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('Message','File')] [string] $FileDateBasis = 'Message',

  # Auth & tokens
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('Interactive','App')] [string] $GraphAuthMode = 'Interactive',
  [Parameter(ParameterSetName='Migrate')] [string] $TenantId,
  [Parameter(ParameterSetName='Migrate')] [string] $ClientId,
  [Parameter(ParameterSetName='Migrate')] [string] $ClientSecret,
  [Parameter(ParameterSetName='Migrate')] [string[]] $GraphScopes,
  [Parameter(ParameterSetName='Migrate')] [string] $SlackToken,

  # Structure & fidelity
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('SingleTeamManyChannels','PerChannelTeam','CustomMap')] [string] $TeamLayout = 'SingleTeamManyChannels',
  [Parameter(ParameterSetName='Migrate')] [string] $TeamMapPath,
  [Parameter(ParameterSetName='Migrate')] [switch] $ValidatePreexistingTargets,
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('Reuse','Align','FailOnMismatch')] [string] $PreexistingBehavior = 'Reuse',
  [Parameter(ParameterSetName='Migrate')] [switch] $UseImportMode,
  [Parameter(ParameterSetName='Migrate')] [switch] $DisableImportMode,
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('ActualChats','PrivateChannels','ArchiveLinks')] [string] $DMStrategy = 'ActualChats',
  [Parameter(ParameterSetName='Migrate')] [switch] $PrivateChannelsAsPrivate,
  [Parameter(ParameterSetName='Migrate')] [switch] $DisablePrivateChannelsAsPrivate,

  # Files behavior
  [Parameter(ParameterSetName='Migrate')] [switch] $PreservePseudoStructure,
  [Parameter(ParameterSetName='Migrate')] [switch] $ChunkedUploads,
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('Skip','Overwrite','Suffix')] [string] $DuplicateFiles = 'Suffix',
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('Inline','SeparateMessage')] [string] $AttachmentLinking = 'SeparateMessage',

  # Performance & logging
  [Parameter(ParameterSetName='Migrate')] [int] $MaxDegreeOfParallelism = 4,
  [Parameter(ParameterSetName='Migrate')] [int] $ApiDelayMs = 200,

  # Notifications
  [Parameter(ParameterSetName='Migrate')] [switch] $EnableNotifications,
  [Parameter(ParameterSetName='Migrate')] [ValidateSet('SMTP','Graph')] [string] $NotificationMethod = 'SMTP',
  [Parameter(ParameterSetName='Migrate')] [string] $NotifyFrom,
  [Parameter(ParameterSetName='Migrate')] [string] $NotifyTo,
  [Parameter(ParameterSetName='Migrate')] [string] $SmtpServer,
  [Parameter(ParameterSetName='Migrate')] [int]    $SmtpPort = 25,
  [Parameter(ParameterSetName='Migrate')] [switch] $SmtpUseTls,
  [Parameter(ParameterSetName='Migrate')] [string] $SmtpUser,
  [Parameter(ParameterSetName='Migrate')] [string] $SmtpPassword
)

# Load shared utils
. "$PSScriptRoot\scripts\shared-utils.ps1"

# -------- Utilities & logging --------
function Ensure-Paths {
  if (-not (Test-Path $StatePath)) { New-Item -ItemType Directory -Path $StatePath | Out-Null }
}
function Get-InventoryPath { Join-Path $StatePath 'inventory.json' }
function Get-StateFilePath { Join-Path $StatePath 'state.json' }
function Get-RunLogPath    { Join-Path $StatePath ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log') }
$script:RunLog = Get-RunLogPath

function Log {
  param([ValidateSet('INFO','WARN','ERROR','FATAL','SUCCESS','PHASE','DEBUG')] [string] $Level = 'INFO',
        [Parameter(Mandatory)] [string] $Message)
  $line = '{0} [{1}] {2}' -f (Get-Date -Format 's'), $Level, $Message
  $line | Tee-Object -FilePath $script:RunLog -Append
}

function Read-JsonFile { param([string]$Path) if (Test-Path $Path) { Get-Content $Path -Raw | ConvertFrom-Json } }
function Write-JsonFile { param([object]$Data, [string]$Path) $Data | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8 }

function Read-EnvFile {
  param([string]$Path)
  $dict = @{}
  if (-not (Test-Path $Path)) { return $dict }
  Get-Content $Path | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
    $parts = $_ -split '=',2
    if ($parts.Count -eq 2) { $dict[$parts[0].Trim()] = $parts[1].Trim() }
  }
  return $dict
}

function Invoke-RestWithPolicy {
  param(
    [Parameter(Mandatory)][string]$Method,
    [Parameter(Mandatory)][string]$Uri,
    [hashtable]$Headers,
    $Body,
    [int]$MaxRetries = 5,
    [int]$BaseDelaySeconds = 2
  )
  $attempt = 0
  while ($true) {
    $attempt++
    try {
      if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $Body -ErrorAction Stop
      } else {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -ErrorAction Stop
      }
    } catch {
      $resp = $_.Exception.Response
      if ($resp) {
        $status = [int]$resp.StatusCode
        $retryAfter = $resp.Headers['Retry-After']
        if ($status -eq 429 -or $status -ge 500) {
          if ($attempt -ge $MaxRetries) { throw }
          $delay = if ($retryAfter) { [int]$retryAfter } else { [math]::Pow(2,$attempt-1) * $BaseDelaySeconds }
          Log -Level 'WARN' -Message "HTTP $status on $Method $Uri. Retrying in $delay s (attempt $attempt/$MaxRetries)."
          Start-Sleep -Seconds $delay
          continue
        }
      }
      throw
    }
  }
}

# -------- Config load & merge --------
function Load-Config {
  param([string]$EnvPath,[string]$ConfigPath)
  $cfg = @{
    Auth = @{
      GraphAuthMode = $GraphAuthMode
      TenantId      = $TenantId
      ClientId      = $ClientId
      ClientSecret  = $ClientSecret
      GraphScopes   = if ($GraphScopes) { $GraphScopes } else { @("Group.ReadWrite.All","ChannelMessage.Send","Chat.ReadWrite","Files.ReadWrite.All","User.ReadBasic.All","Sites.ReadWrite.All") }
      SlackToken    = $SlackToken
    }
    Structure = @{
      TeamLayout               = $TeamLayout
      TeamMapPath              = $TeamMapPath
      ValidatePreexisting      = [bool]$ValidatePreexistingTargets
      PreexistingBehavior      = $PreexistingBehavior
      PrivateChannelsAsPrivate = if ($DisablePrivateChannelsAsPrivate) { $false } elseif ($PrivateChannelsAsPrivate.IsPresent) { $true } else { $true }
      UseImportMode            = if ($DisableImportMode) { $false } elseif ($UseImportMode.IsPresent) { $true } else { $true }
      DMStrategy               = $DMStrategy
    }
    Files = @{
      PreservePseudoStructure = [bool]$PreservePseudoStructure
      ChunkedUploads          = if ($ChunkedUploads.IsPresent) { $true } else { $true }
      DuplicateHandling       = $DuplicateFiles
      AttachmentLinking       = $AttachmentLinking
    }
    Run = @{
      DeltaMode            = [bool]$DeltaMode
      OfflineMode          = [bool]$OfflineMode
      Mode                 = $Mode
      StartAt              = $StartAtPhase
      EndAt                = $EndAtPhase
      Exclude              = $ExcludePhases
      Only                 = $OnlyPhases
      MaxDop               = $MaxDegreeOfParallelism
      ApiDelayMs           = $ApiDelayMs
      StartDate            = $StartDate
      EndDate              = $EndDate
      DateRangeTargets     = $DateRangeTargets
      IncludeFilesInRange  = [bool]$IncludeFilesInDateRange
      FileDateBasis        = $FileDateBasis
      SkipMessagesContaining = @()
      SkipFileTypes        = @()
      SkipFileMaxSizeMB    = $null
      LogJson              = $false
      LogToFile            = $true
      LogFilePath          = (Join-Path $StatePath 'run.log')
      ContinueOnError      = $true
      SaveReportPath       = (Join-Path $StatePath 'runreport.json')
      ApplyDefaultDateRange = $true
      DefaultDateRangeDays = 365
    }
    Notify = @{
      Enabled   = [bool]$EnableNotifications
      Method    = $NotificationMethod
      From      = $NotifyFrom
      To        = $NotifyTo
      Smtp      = @{ Server=$SmtpServer; Port=$SmtpPort; UseTls=[bool]$SmtpUseTls; User=$SmtpUser; Password=$SmtpPassword }
    }
    Paths = @{
      ExportRoot = $ExportRoot
      StatePath  = $StatePath
    }
  }

  # .env merge
  $envd = Read-EnvFile -Path $EnvPath
  foreach ($k in $envd.Keys) {
    switch -Regex ($k) {
      '^TENANT_ID$'       { if (-not $cfg.Auth.TenantId)     { $cfg.Auth.TenantId    = $envd[$k] } }
      '^CLIENT_ID$'       { if (-not $cfg.Auth.ClientId)     { $cfg.Auth.ClientId    = $envd[$k] } }
      '^CLIENT_SECRET$'   { if (-not $cfg.Auth.ClientSecret) { $cfg.Auth.ClientSecret= $envd[$k] } }
      '^SLACK_TOKEN$'     { if (-not $cfg.Auth.SlackToken)   { $cfg.Auth.SlackToken  = $envd[$k] } }
      '^SMTP_SERVER$'     { if (-not $cfg.Notify.Smtp.Server){ $cfg.Notify.Smtp.Server = $envd[$k] } }
      '^SMTP_PORT$'       { if (-not $cfg.Notify.Smtp.Port)  { $cfg.Notify.Smtp.Port = [int]$envd[$k] } }
      '^SMTP_USER$'       { if (-not $cfg.Notify.Smtp.User)  { $cfg.Notify.Smtp.User = $envd[$k] } }
      '^SMTP_PASSWORD$'   { if (-not $cfg.Notify.Smtp.Password){ $cfg.Notify.Smtp.Password = $envd[$k] } }
      '^NOTIFY_FROM$'     { if (-not $cfg.Notify.From)       { $cfg.Notify.From = $envd[$k] } }
      '^NOTIFY_TO$'       { if (-not $cfg.Notify.To)         { $cfg.Notify.To   = $envd[$k] } }
    }
  }

  # appsettings.json merge
  if (Test-Path $ConfigPath) {
    $appcfg = Read-JsonFile -Path $ConfigPath
    if ($appcfg.Auth)      { $cfg.Auth      = $appcfg.Auth      + $cfg.Auth }
    if ($appcfg.Structure) { $cfg.Structure = $appcfg.Structure + $cfg.Structure }
    if ($appcfg.Files)     { $cfg.Files     = $appcfg.Files     + $cfg.Files }
    if ($appcfg.Run)       { $cfg.Run       = $appcfg.Run       + $cfg.Run }
    if ($appcfg.Notify)    { $cfg.Notify    = $appcfg.Notify    + $cfg.Notify }
    if ($appcfg.Paths)     { $cfg.Paths     = $appcfg.Paths     + $cfg.Paths }
  }

  # Default one-year range if none set
  if (-not $cfg.Run.StartDate -and -not $cfg.Run.EndDate -and $cfg.Run.ApplyDefaultDateRange) {
    $days = if ($cfg.Run.DefaultDateRangeDays) { [int]$cfg.Run.DefaultDateRangeDays } else { 365 }
    $cfg.Run.StartDate = (Get-Date).AddDays(-$days)
    $cfg.Run.EndDate   = Get-Date
    Log -Level 'INFO' -Message "No explicit date range; defaulting to last $days days."
  }
  return $cfg
}

# -------- Inventory (Phase 0) --------
function Get-SlackInventory {
  param([string]$ExportRoot)
  $inv = @{
    Channels = @()
    DMs      = @()
    Users    = @()
    Files    = @()
    Meta     = @{ ExportRoot = (Resolve-Path $ExportRoot).Path; GeneratedAt = (Get-Date).ToString('s') }
  }
  $channelsPath = Join-Path $ExportRoot 'channels.json'
  $groupsPath   = Join-Path $ExportRoot 'groups.json'
  $mpimsPath    = Join-Path $ExportRoot 'mpims.json'
  $usersPath    = Join-Path $ExportRoot 'users.json'
  if (Test-Path $channelsPath) { $inv.Channels += (Get-Content $channelsPath -Raw | ConvertFrom-Json) }
  if (Test-Path $groupsPath)   { $inv.Channels += (Get-Content $groupsPath   -Raw | ConvertFrom-Json) }
  if (Test-Path $mpimsPath)    { $inv.DMs      += (Get-Content $mpimsPath    -Raw | ConvertFrom-Json) }
  if (Test-Path $usersPath)    { $inv.Users     = (Get-Content $usersPath    -Raw | ConvertFrom-Json) }

  $fileSet = @{}
  Get-ChildItem -Path $ExportRoot -Recurse -Filter '*.json' | Where-Object {
    $_.Name -notin @('channels.json','groups.json','mpims.json','users.json')
  } | ForEach-Object {
    try {
      $msgs = Get-Content $_.FullName -Raw | ConvertFrom-Json
      foreach ($m in $msgs) {
        if ($m.files) {
          foreach ($f in $m.files) {
            $fid = $f.id
            if (-not $fileSet.ContainsKey($fid)) {
              $fileSet[$fid] = [PSCustomObject]@{
                id       = $f.id
                name     = $f.name
                mimetype = $f.mimetype
                url      = $f.url_private
                size     = $f.size
                ts       = $m.ts
              }
            }
          }
        }
      }
    } catch {
      Log -Level 'WARN' -Message "Phase 0: failed parsing $($_.FullName): $($_.Exception.Message)"
    }
  }
  $inv.Files = $fileSet.Values
  return $inv
}

function Save-Inventory { param([object]$Inventory) Write-JsonFile -Data $Inventory -Path (Get-InventoryPath) }
function Load-Inventory {
  $path = Get-InventoryPath
  $inv = Read-JsonFile -Path $path
  if (-not $inv) { throw "Inventory not found at $path. Run with -RefreshInventory or ensure export root is correct." }
  return $inv
}

function Write-MarkdownTable {
  param([object[]]$Rows, [string[]]$Headers, [string[]]$Props)
  if (-not $Rows) { return }
  $headerLine = '| ' + ($Headers -join ' | ') + ' |'
  $sepLine    = '| ' + (($Headers | ForEach-Object { '---' }) -join ' | ') + ' |'
  $dataLines  = foreach ($r in $Rows) { '| ' + ($Props | ForEach-Object { ($r.$_ -as [string]) -replace '\|','\|' }) -join ' | ' + ' |' }
  $headerLine; $sepLine; $dataLines
}

function Show-Inventory {
  param([object]$Inventory, [ValidateSet('Channels','Users','Files')] [string] $Kind,[switch]$AsTable,[switch]$AsMarkdown,[string]$AsCsv,[switch]$Print)
  switch ($Kind) {
    'Channels' {
      $rows = $Inventory.Channels | ForEach-Object { [PSCustomObject]@{ id=$_.id; name=$_.name; is_archived=$_.is_archived; created=$_.created } }
      $headers = @('id','name','is_archived','created'); $props = $headers
    }
    'Users' {
      $rows = $Inventory.Users | ForEach-Object { [PSCustomObject]@{ id=$_.id; name=$_.name; real_name=$_.profile.real_name; email=$_.profile.email } }
      $headers = @('id','name','real_name','email'); $props = $headers
    }
    'Files' {
      $rows = $Inventory.Files | ForEach-Object { [PSCustomObject]@{ id=$_.id; name=$_.name; mimetype=$_.mimetype; size=$_.size; ts=$_.ts } }
      $headers = @('id','name','mimetype','size','ts'); $props = $headers
    }
  }
  if ($AsCsv)      { $rows | Export-Csv -Path $AsCsv -NoTypeInformation -Encoding UTF8; Write-Host "CSV written: $AsCsv"; return }
  if ($AsMarkdown) { Write-MarkdownTable -Rows $rows -Headers $headers -Props $props; return }
  if ($AsTable -or $Print -or -not ($AsCsv -or $AsMarkdown)) { $rows | Format-Table -AutoSize; return }
}

# -------- State & filters --------
function Read-State {
  $path = Get-StateFilePath
  $state = Read-JsonFile -Path $path
  if (-not $state) { $state = @{ Runs=@(); Phases=@{}; Channels=@{} } }
  return $state
}
function Write-State { param([object]$State) Write-JsonFile -Data $State -Path (Get-StateFilePath) }
function Update-StatePhase { param([int]$PhaseId, [string]$Status, [string]$Detail) $s=Read-State; $s.Phases["$PhaseId"] = @{ Status=$Status; Detail=$Detail; At=(Get-Date).ToString('s') }; Write-State $s }

function Resolve-ChannelTargets { param([object]$Inventory,[string[]]$ChannelFilter)
  if (-not $ChannelFilter) { return $Inventory.Channels }
  $byName=@{};$byId=@{}; foreach($c in $Inventory.Channels){$byName[$c.name]=$c;$byId[$c.id]=$c}
  $targets=@();$missing=@(); foreach($f in $ChannelFilter){ if($byId.ContainsKey($f)){$targets+=$byId[$f]} elseif($byName.ContainsKey($f)){$targets+=$byName[$f]} else {$missing+=$f} }
  if($missing){ throw "Channel(s) not found in inventory: $($missing -join ', ')" }
  return $targets
}
function Resolve-UserTargets { param([object]$Inventory,[string[]]$UserFilter)
  if (-not $UserFilter) { return $Inventory.Users }
  $byName=@{};$byId=@{}; foreach($u in $Inventory.Users){$byName[$u.name]=$u;$byId[$u.id]=$u}
  $targets=@();$missing=@(); foreach($f in $UserFilter){ if($byId.ContainsKey($f)){$targets+=$byId[$f]} elseif($byName.ContainsKey($f)){$targets+=$byName[$f]} else {$missing+=$f} }
  if($missing){ throw "User(s) not found in inventory: $($missing -join ', ')" }
  return $targets
}

# -------- Auth --------
function Ensure-GraphToken {
  param([hashtable]$AuthCfg)
  if ($AuthCfg.GraphAuthMode -eq 'Interactive') {
    try {
      Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
      $scopes = $AuthCfg.GraphScopes
      Log -Message "Connecting to Graph interactively with scopes: $($scopes -join ', ')"
      Connect-MgGraph -Scopes $scopes -ErrorAction Stop | Out-Null
      $ctx = Get-MgContext
      if (-not $ctx.AccessToken) { throw "No access token from Connect-MgGraph." }
      return $ctx.AccessToken
    } catch {
      throw "Interactive Graph auth failed: $($_.Exception.Message)"
    }
  } else {
    if (-not $AuthCfg.TenantId)   { $AuthCfg.TenantId   = Read-Host "Enter Tenant ID (GUID)" }
    if (-not $AuthCfg.ClientId)   { $AuthCfg.ClientId   = Read-Host "Enter Client ID (App Registration)" }
    if (-not $AuthCfg.ClientSecret){ $AuthCfg.ClientSecret = Read-Host "Enter Client Secret" }
    $body = @{
      client_id     = $AuthCfg.ClientId
      client_secret = $AuthCfg.ClientSecret
      scope         = "https://graph.microsoft.com/.default"
      grant_type    = "client_credentials"
    }
    $tokenUri = "https://login.microsoftonline.com/$($AuthCfg.TenantId)/oauth2/v2.0/token"
    try {
      $resp = Invoke-RestMethod -Method POST -Uri $tokenUri -Body $body -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
      return $resp.access_token
    } catch {
      throw "App Graph auth failed: $($_.Exception.Message)"
    }
  }
}

function Ensure-SlackToken {
  param([hashtable]$AuthCfg)
  $token = $AuthCfg.SlackToken
  if (-not $token) { $token = Read-Host "Enter Slack token (Bot/User token)" }
  try {
    $resp = Invoke-RestWithPolicy -Method 'GET' -Uri 'https://slack.com/api/auth.test' -Headers @{ Authorization="Bearer $token" }
    if (-not $resp.ok) { throw "Slack auth.test returned: $($resp.error)" }
  } catch {
    throw "Slack token validation failed: $($_.Exception.Message)"
  }
  # Scope check
  $required = @('users:read','channels:read','groups:read','im:read','mpim:read','channels:history','groups:history','im:history','mpim:history','files:read')
  try {
    $perm = Invoke-RestWithPolicy -Method 'GET' -Uri 'https://slack.com/api/apps.permissions.info' -Headers @{ Authorization="Bearer $token" }
    if ($perm.ok -and $perm.info.scopes) {
      $granted = @($perm.info.scopes.user + $perm.info.scopes.bot)
      $missing = $required | Where-Object { $_ -notin $granted }
      if ($missing) { Log -Level 'WARN' -Message "Slack token missing scopes: $($missing -join ', ')" } else { Log -Message "Slack token has all required scopes." }
    } else {
      Log -Level 'WARN' -Message "Unable to verify Slack scopes; continuing."
    }
  } catch {
    Log -Level 'WARN' -Message "Slack scope check failed: $($_.Exception.Message)"
  }
  return $token
}

# -------- Notifications --------
function Send-Notification {
  param([hashtable]$NotifyCfg,[string]$Subject,[string]$Body)
  if (-not $NotifyCfg.Enabled) { return }
  try {
    if ($NotifyCfg.Method -eq 'SMTP') {
      if (-not $NotifyCfg.From)     { $NotifyCfg.From = Read-Host "Notify From (email)" }
      if (-not $NotifyCfg.To)       { $NotifyCfg.To   = Read-Host "Notify To (email)" }
      if (-not $NotifyCfg.Smtp.Server) { $NotifyCfg.Smtp.Server = Read-Host "SMTP server" }
      $params = @{
        From       = $NotifyCfg.From
        To         = $NotifyCfg.To
        Subject    = $Subject
        Body       = $Body
        SmtpServer = $NotifyCfg.Smtp.Server
      }
      if ($NotifyCfg.Smtp.Port)   { $params.Port = $NotifyCfg.Smtp.Port }
      if ($NotifyCfg.Smtp.UseTls) { $params.UseSsl = $true }
      if ($NotifyCfg.Smtp.User -and $NotifyCfg.Smtp.Password) {
        $sec = ConvertTo-SecureString $NotifyCfg.Smtp.Password -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($NotifyCfg.Smtp.User, $sec)
        $params.Credential = $cred
      }
      Send-MailMessage @params
    } else {
      $accessToken = (Get-MgContext).AccessToken
      if (-not $accessToken) { Log -Level 'WARN' -Message "Graph sendMail requires interactive auth. Skipping notification."; return }
      $headers = @{ Authorization="Bearer $accessToken"; "Content-Type"="application/json" }
      $payload = @{
        message = @{
          subject = $Subject
          body = @{ contentType="Text"; content=$Body }
          toRecipients = @(@{ emailAddress=@{ address=$NotifyCfg.To }})
          from = @{ emailAddress=@{ address=$NotifyCfg.From } }
        }
        saveToSentItems = $false
      } | ConvertTo-Json -Depth 6
      Invoke-RestWithPolicy -Method 'POST' -Uri 'https://graph.microsoft.com/v1.0/me/sendMail' -Headers $headers -Body $payload | Out-Null
    }
  } catch {
    Log -Level 'WARN' -Message "Notification failed: $($_.Exception.Message)"
  }
}

# -------- Phases registry --------
$Phases = @(
  [PSCustomObject]@{ Id=0; Name='Discovery';        RequiresOnline=$false; Script={ Run-Phase0 } },
  [PSCustomObject]@{ Id=1; Name='Parse Export';     RequiresOnline=$false; Script={ Run-Phase1 } },
  [PSCustomObject]@{ Id=2; Name='Map Users';        RequiresOnline=$true;  Script={ Run-Phase2 } },
  [PSCustomObject]@{ Id=3; Name='Create Teams';     RequiresOnline=$true;  Script={ Run-Phase3 } },
  [PSCustomObject]@{ Id=4; Name='Post Messages';    RequiresOnline=$true;  Script={ Run-Phase4 } },
  [PSCustomObject]@{ Id=5; Name='Download Files';   RequiresOnline=$true;  Script={ Run-Phase5 } },
  [PSCustomObject]@{ Id=6; Name='Upload Files';     RequiresOnline=$true;  Script={ Run-Phase6 } },
  [PSCustomObject]@{ Id=7; Name='Validate';         RequiresOnline=$true;  Script={ Run-Phase7 } }
)

function Should-RunPhase {
  param([int]$PhaseId,[int]$StartAt,[int]$EndAt,[int[]]$Exclude,[int[]]$Only,[int[]]$Explicit)
  if ($Explicit -and -not ($Explicit -contains $PhaseId)) { return $false }
  if ($Only -and -not ($Only -contains $PhaseId)) { return $false }
  if ($PhaseId -lt $StartAt) { return $false }
  if ($PhaseId -gt $EndAt)   { return $false }
  if ($Exclude -and ($Exclude -contains $PhaseId)) { return $false }
  return $true
}

# -------- Phase implementations (stubs with contracts) --------
function Run-Phase0 {
  try {
    Log -Level 'PHASE' -Message "Phase 0: Discovery started"
    $invPath = Get-InventoryPath
    if ($RefreshInventory -or -not (Test-Path $invPath)) {
      $inv = Get-SlackInventory -ExportRoot $Global:Config.Paths.ExportRoot
      Save-Inventory -Inventory $inv
      Log -Message "Inventory built. Channels=$($inv.Channels.Count), Users=$($inv.Users.Count), Files=$($inv.Files.Count)"
    } else {
      Log -Message "Inventory exists. Use -RefreshInventory to rebuild."
    }
    Update-StatePhase -PhaseId 0 -Status 'Success' -Detail 'Inventory ready'
  } catch {
    Update-StatePhase -PhaseId 0 -Status 'Error' -Detail $_.Exception.Message
    throw
  }
}

# These phase stubs accept parameters and should be completed with your implementation.
function Run-Phase1 { Log -Message "Phase 1: Parse export (stub). Produce state\slack_data.json" }
function Run-Phase2 { Log -Message "Phase 2: Map users (stub). Produce state\user_map.json" }
function Run-Phase3 { Log -Message "Phase 3: Create Teams & channels (stub)" }
function Run-Phase4 { Log -Message "Phase 4: Post messages (stub) applying date-range & skip rules" }
function Run-Phase5 { Log -Message "Phase 5: Download files (stub) applying date-range & skip rules" }
function Run-Phase6 { Log -Message "Phase 6: Upload files (stub) preserve structure & duplicates" }
function Run-Phase7 { Log -Message "Phase 7: Validate & report (stub). Emit runreport.json" }

# ---------------- Main ----------------
try {
  Ensure-Paths
  $Global:Config = Load-Config -EnvPath $EnvPath -ConfigPath $ConfigPath
  Log -Message "Loaded config. ExportRoot=$($Global:Config.Paths.ExportRoot), StatePath=$($Global:Config.Paths.StatePath)"

  # Inventory-only mode
  if ($PSCmdlet.ParameterSetName -eq 'Inventory') {
    if ($RefreshInventory -or -not (Test-Path (Get-InventoryPath))) { Run-Phase0 }
    $inv = Load-Inventory
    if ($ListChannels) { Show-Inventory -Inventory $inv -Kind 'Channels' -AsTable:$AsTable -AsMarkdown:$AsMarkdown -AsCsv:$AsCsv -Print:$Print; return }
    if ($ListUsers)    { Show-Inventory -Inventory $inv -Kind 'Users'    -AsTable:$AsTable -AsMarkdown:$AsMarkdown -AsCsv:$AsCsv -Print:$Print; return }
    if ($ListFiles)    { Show-Inventory -Inventory $inv -Kind 'Files'    -AsTable:$AsTable -AsMarkdown:$AsMarkdown -AsCsv:$AsCsv -Print:$Print; return }
    Write-Host "Use -ListChannels, -ListUsers, or -ListFiles."
    return
  }

  # Auth upfront if needed later
  if (-not $OfflineMode) {
    $null = Ensure-SlackToken -AuthCfg $Global:Config.Auth
    if ($Global:Config.Auth.GraphAuthMode -eq 'Interactive') {
      try { Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue } catch {}
    }
  }

  # Parse explicit phases string if provided (e.g., -Phases "3,5-6")
  $explicit = @()
  if ($Phases) {
    foreach ($part in $Phases -split ',') {
      if ($part -match '-') {
        $range = $part -split '-'
        $explicit += [int]$range[0]..[int]$range[1]
      } else { $explicit += [int]$part }
    }
  }

  foreach ($phase in $Phases) { } # placeholder to avoid name clash

  foreach ($p in @(
    [PSCustomObject]@{ Id=0; Action={ Run-Phase0 } },
    [PSCustomObject]@{ Id=1; Action={ Run-Phase1 } },
    [PSCustomObject]@{ Id=2; Action={ Run-Phase2 } },
    [PSCustomObject]@{ Id=3; Action={ Run-Phase3 } },
    [PSCustomObject]@{ Id=4; Action={ Run-Phase4 } },
    [PSCustomObject]@{ Id=5; Action={ Run-Phase5 } },
    [PSCustomObject]@{ Id=6; Action={ Run-Phase6 } },
    [PSCustomObject]@{ Id=7; Action={ Run-Phase7 } }
  )) {
    if (-not (Should-RunPhase -PhaseId $p.Id -StartAt $Global:Config.Run.StartAt -EndAt $Global:Config.Run.EndAt -Exclude $Global:Config.Run.Exclude -Only $Global:Config.Run.Only -Explicit $explicit)) {
      Log -Message "Skipping Phase $($p.Id)"
      continue
    }
    try {
      Log -Message "Starting Phase $($p.Id)"
      & $p.Action
      Update-StatePhase -PhaseId $p.Id -Status 'Success' -Detail ''
      Log -Message "Completed Phase $($p.Id)"
    } catch {
      Update-StatePhase -PhaseId $p.Id -Status 'Error' -Detail $_.Exception.Message
      Log -Level 'ERROR' -Message "Phase $($p.Id) failed: $($_.Exception.Message)"
      if ($Mode -eq 'Auto') { throw }
      elseif ($Mode -eq 'ConfirmOnError') {
        $ans = Read-Host "Error in Phase $($p.Id). Continue? (y/n)"; if ($ans -ne 'y') { throw }
      } elseif ($Mode -eq 'ConfirmEachPhase') {
        $ans = Read-Host "Error encountered. Continue? (y/n)"; if ($ans -ne 'y') { throw }
      }
    }
    if ($Mode -eq 'ConfirmEachPhase') {
      $ans = Read-Host "Phase $($p.Id) complete. Proceed to next? (y/n)"; if ($ans -ne 'y') { break }
    }
  }

  Log -Message "Run complete."
} catch {
  Log -Level 'FATAL' -Message "Run aborted: $($_.Exception.Message)"
  throw
}
'@
Out-Utf8 (Join-Path $RootPath 'Migrate.ps1') $orchestrator

# ---------------------------
# Phase stubs
# ---------------------------
$phase1 = @'
# scripts/phases/parse-slack-export.ps1
param([Parameter(Mandatory)][string]$ExportRootPath)
Write-Host "Parsing Slack export at $ExportRootPath (stub)."
'@
$phase2 = @'
# scripts/phases/map-users.ps1
param([Parameter(Mandatory)][string]$SlackToken,[Parameter(Mandatory)][string]$DataModelPath,[Parameter(Mandatory)][string]$GraphToken)
Write-Host "Mapping users (stub). Slack+Graph tokens present."
'@
$phase3 = @'
# scripts/phases/create-teams-channels.ps1
param([Parameter(Mandatory)][string]$UserMapPath,[Parameter(Mandatory)][string]$SlackDataPath,[Parameter(Mandatory)][string]$GraphToken)
Write-Host "Ensuring Teams and Channels (stub)."
'@
$phase4 = @'
# scripts/phases/post-messages.ps1
param([Parameter(Mandatory)][string]$SlackDataPath,[Parameter(Mandatory)][string]$UserMapPath,[Parameter(Mandatory)][string]$GraphToken,
      [datetime]$StartDate,[datetime]$EndDate,[ValidateSet("Channels","DMs","All")]$DateRangeTargets="All")
Write-Host "Posting messages with filters Start=$StartDate End=$EndDate Targets=$DateRangeTargets (stub)."
'@
$phase5 = @'
# scripts/phases/download-files.ps1
param([Parameter(Mandatory)][string]$SlackToken,[Parameter(Mandatory)][string]$SlackDataPath,[Parameter(Mandatory)][string]$DownloadFolder,
      [datetime]$StartDate,[datetime]$EndDate,[ValidateSet("Channels","DMs","All")]$DateRangeTargets="All",
      [switch]$IncludeFilesInDateRange,[ValidateSet("Message","File")]$FileDateBasis="Message")
Write-Host "Downloading files with range and rules (stub)."
'@
$phase6 = @'
# scripts/phases/upload-files.ps1
param([Parameter(Mandatory)][string]$DownloadFolder,[Parameter(Mandatory)][string]$SlackDataPath,[Parameter(Mandatory)][string]$GraphToken,
      [datetime]$StartDate,[datetime]$EndDate,[ValidateSet("Channels","DMs","All")]$DateRangeTargets="All",
      [switch]$IncludeFilesInDateRange,[ValidateSet("Message","File")]$FileDateBasis="Message")
Write-Host "Uploading files with structure & duplicate handling (stub)."
'@
$phase7 = @'
# scripts/phases/test-validate.ps1
param([Parameter(Mandatory)][string]$SlackDataPath,[Parameter(Mandatory)][string]$UserMapPath,[Parameter(Mandatory)][string]$GraphToken)
Write-Host "Validating migration & producing report (stub)."
'@
Out-Utf8 (Join-Path $RootPath 'scripts\phases\parse-slack-export.ps1') $phase1
Out-Utf8 (Join-Path $RootPath 'scripts\phases\map-users.ps1') $phase2
Out-Utf8 (Join-Path $RootPath 'scripts\phases\create-teams-channels.ps1') $phase3
Out-Utf8 (Join-Path $RootPath 'scripts\phases\post-messages.ps1') $phase4
Out-Utf8 (Join-Path $RootPath 'scripts\phases\download-files.ps1') $phase5
Out-Utf8 (Join-Path $RootPath 'scripts\phases\upload-files.ps1') $phase6
Out-Utf8 (Join-Path $RootPath 'scripts\phases\test-validate.ps1') $phase7

# ---------------------------
# Dataset generator and generate dataset
# ---------------------------
$gen = @'
# scripts/Generate-TestSlackExport.ps1
param([string]$Root = ".\testdata")
Set-StrictMode -Version Latest
$exp = Join-Path $Root "slack_export"
$filesDir = Join-Path $Root "file_payloads"
New-Item -ItemType Directory -Force -Path $exp,$filesDir | Out-Null

@'
[
  { "id":"C10001","name":"engineering","created":1672617600,"is_archived":false,"topic":"Build & ship","purpose":"Engineering discussions" },
  { "id":"C10002","name":"hr","created":1675209600,"is_archived":false,"topic":"People ops","purpose":"HR policies and Q&A" },
  { "id":"C10003","name":"product-archived","created":1640908800,"is_archived":true,"topic":"","purpose":"Old product work" }
]
'@ | Set-Content -Encoding UTF8 (Join-Path $exp "channels.json")

@'
[
  { "id":"G20001","name":"finance","created":1680566400,"is_archived":false,"topic":"Numbers","purpose":"Private finance discussions" }
]
'@ | Set-Content -Encoding UTF8 (Join-Path $exp "groups.json")

@'
[
  { "id":"G30001","name":"mpim_U10001_U10002_U10005","created":1723939200,"members":["U10001","U10002","U10005"] }
]
'@ | Set-Content -Encoding UTF8 (Join-Path $exp "mpims.json")

@'
[
  { "id":"U10001","name":"karl","profile":{"real_name":"Karl Example","email":"karl@example.test"} },
  { "id":"U10002","name":"alexa","profile":{"real_name":"Alexa Rivera","email":"alexa@example.test"} },
  { "id":"U10003","name":"mina","profile":{"real_name":"Mina Patel","email":"mina@example.test"} },
  { "id":"U10004","name":"li","profile":{"real_name":"Li Chen","email":"li@example.test"} },
  { "id":"U10005","name":"samir","profile":{"real_name":"Samir Qadir","email":"samir@example.test"} }
]
'@ | Set-Content -Encoding UTF8 (Join-Path $exp "users.json")

# Helper to write message arrays
function Write-Day {
  param([string]$folder,[string]$date,[string]$json)
  $path = Join-Path $exp $folder
  New-Item -ItemType Directory -Force -Path $path | Out-Null
  $file = Join-Path $path "$date.json"
  $json | Set-Content -Encoding UTF8 $file
}

# Engineering
Write-Day "engineering" "2023-06-01" @'
[
 { "type":"message","user":"U10001","text":"Eng: Kickoff 2023.","ts":"1685577600.000001" }
]
'@
Write-Day "engineering" "2024-11-15" @'
[
 { "type":"message","user":"U10002","text":"Eng: Mid-cycle note.","ts":"1731628800.000001" }
]
'@
Write-Day "engineering" "2025-07-10" @'
[
  { "type":"message","subtype":"thread_broadcast","user":"U10001","text":"Release 2.5 shipped! See files and notes.","ts":"1752105600.000001",
    "files":[ { "id":"F50001","name":"release-notes.pdf","mimetype":"application/pdf","size":131072,"url_private":"sandbox://file_payloads/release-notes.pdf" } ] },
  { "type":"message","user":"U10002","text":"Replying in thread. @karl please check diagram.","ts":"1752109200.000002","thread_ts":"1752105600.000001",
    "files":[ { "id":"F50002","name":"diagram.png","mimetype":"image/png","size":262144,"url_private":"sandbox://file_payloads/diagram.png" } ] },
  { "type":"message","user":"U10003","text":"Uploading large video for demo.","ts":"1752112800.000003",
    "files":[ { "id":"F50003","name":"large-video.mp4","mimetype":"video/mp4","size":62914560,"url_private":"sandbox://file_payloads/large-video.mp4" } ] }
]
'@

# HR
Write-Day "hr" "2025-01-05" @'
[
  { "type":"message","user":"U10004","text":"HR handbook v3 attached.","ts":"1736035200.000010",
    "files":[ { "id":"F50004","name":"handbook.pdf","mimetype":"application/pdf","size":131072,"url_private":"sandbox://file_payloads/handbook.pdf" } ] },
  { "type":"message","user":"U10002","text":"Please ignore this test channel message.","ts":"1736042400.000011" }
]
'@
Write-Day "hr" "2024-02-20" @'
[
  { "type":"message","user":"U10005","text":"HR retro action items.","ts":"1708387200.000012" }
]
'@

# Finance (private)
Write-Day "finance" "2023-04-12" @'
[
  { "type":"message","user":"U10005","text":"Q2 forecast (internal only).","ts":"1681267200.000020",
    "files":[ { "id":"F50005","name":"small-note.txt","mimetype":"text/plain","size":0,"url_private":"sandbox://file_payloads/small-note.txt" } ] },
  { "type":"message","user":"U10003","text":"Duplicate file name test.","ts":"1681270800.000021",
    "files":[ { "id":"F50006","name":"release-notes.pdf","mimetype":"application/pdf","size":131072,"url_private":"sandbox://file_payloads/release-notes.pdf" } ] }
]
'@

# Product (archived)
Write-Day "product-archived" "2022-12-31" @'
[
  { "type":"message","user":"U10001","text":"EOL notes for 2022 product.","ts":"1672444800.000030" }
]
'@

# DMs and MPIM
Write-Day "dm_U10001_U10002" "2023-05-01" @'
[
  { "type":"message","user":"U10001","text":"Private DM message with attachment.","ts":"1682899200.000040",
    "files":[ { "id":"F50007","name":"release-notes (1).pdf","mimetype":"application/pdf","size":131072,"url_private":"sandbox://file_payloads/release-notes (1).pdf" } ] }
]
'@
Write-Day "dm_U10003_U10004" "2025-06-20" @'
[
  { "type":"message","user":"U10003","text":"DM close to present day.","ts":"1750377600.000041" }
]
'@
Write-Day "mpim_U10001_U10002_U10005" "2024-08-18" @'
[
  { "type":"message","user":"U10002","text":"MPIM kickoff.","ts":"1723939200.000050" }
]
'@

# Placeholder files
New-Item -ItemType File -Path (Join-Path $filesDir "small-note.txt") | Out-Null
fsutil file createnew (Join-Path $filesDir "handbook.pdf") 131072    | Out-Null
fsutil file createnew (Join-Path $filesDir "diagram.png")  262144    | Out-Null
fsutil file createnew (Join-Path $filesDir "release-notes.pdf") 131072 | Out-Null
fsutil file createnew (Join-Path $filesDir "release-notes (1).pdf") 131072 | Out-Null
fsutil file createnew (Join-Path $filesDir "large-video.mp4") 62914560 | Out-Null

Write-Host "Simulated Slack export generated at $exp"
