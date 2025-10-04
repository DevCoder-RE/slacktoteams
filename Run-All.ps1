[CmdletBinding()]
param(
  [ValidateSet('Offline','Live')]
  [string]$Mode = 'Offline',
  [ValidateSet('Auto','ConfirmOnError','ConfirmEachPhase')]
  [string]$ExecutionMode = 'Auto',
  [string[]]$ChannelFilter,
  [string[]]$UserFilter,
  [switch]$DeltaMode,
  [switch]$EmailNotifications,
  [string[]]$SkipPhases,
  [switch]$SkipProvision,
  [switch]$SkipFiles,
  [switch]$DryRun,
  [switch]$Rollback,
  [switch]$FullRollback,
  [switch]$SelectiveRollback,
  [string]$BackupPath,
  [switch]$RealTimeSync,
  [int]$SyncIntervalMinutes = 5,
  [int]$MaxRuntimeHours = 24,
  [switch]$ContinuousMode,
  [switch]$EnableParallel,
  [int]$MaxConcurrentChannels = 3,
  [int]$MaxConcurrentFiles = 5
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptRoot

# Load shared modules
. .\Shared\Shared-Logging.ps1
. .\Shared\Shared-Config.ps1
. .\Shared\Shared-Json.ps1
. .\Shared\Shared-Retry.ps1
. .\Shared\Shared-Graph.ps1
. .\Shared\Shared-Slack.ps1
. .\Shared\Shared-Parallel.ps1

Initialize-Logging -LogDirectory "$scriptRoot\Logs"
Load-AppConfig -AppSettingsPath "$scriptRoot\Config\appsettings.json" -EnvPath "$scriptRoot\Config\.env"
Write-Log -Level Info -Message "Starting Run-All.ps1 with Mode=$Mode ExecutionMode=$ExecutionMode DryRun=$DryRun SkipProvision=$SkipProvision SkipFiles=$SkipFiles DeltaMode=$DeltaMode EmailNotifications=$EmailNotifications Rollback=$Rollback FullRollback=$FullRollback SelectiveRollback=$SelectiveRollback RealTimeSync=$RealTimeSync SyncIntervalMinutes=$SyncIntervalMinutes MaxRuntimeHours=$MaxRuntimeHours ContinuousMode=$ContinuousMode EnableParallel=$EnableParallel MaxConcurrentChannels=$MaxConcurrentChannels MaxConcurrentFiles=$MaxConcurrentFiles"

# Notification function
function Send-Notification {
    param([string]$Subject, [string]$Body)
    if ($EmailNotifications) {
        $smtpServer = Get-Config 'Email.SmtpServer'
        $from = Get-Config 'Email.From'
        $to = Get-Config 'Email.To'
        if ($smtpServer -and $from -and $to) {
            Send-MailMessage -SmtpServer $smtpServer -From $from -To $to -Subject $Subject -Body $Body
            Write-Log -Level Info -Message "Email notification sent: $Subject"
        }
    }
}

# Confirmation function
function Confirm-Phase {
    param([string]$PhaseName)
    if ($ExecutionMode -eq 'ConfirmEachPhase') {
        $response = Read-Host "Proceed with $PhaseName? (Y/N)"
        if ($response -ne 'Y') {
            Write-Log -Level Warn -Message "User cancelled at $PhaseName"
            exit 0
        }
    }
}

if ($Mode -eq 'Live') {
  Connect-Graph -TenantId (Get-Config 'Graph.TenantId') -ClientId (Get-Config 'Graph.ClientId') -ClientSecret (Get-Config 'Graph.ClientSecret')
}

# Check parallel processing support
$parallelSupported = Test-ParallelProcessingSupport
if ($EnableParallel -and -not $parallelSupported) {
    Write-Log -Level Warn -Message "Parallel processing requested but not supported. Falling back to sequential processing." -Context "Parallel"
    $EnableParallel = $false
} elseif ($EnableParallel) {
    Write-Log -Level Info -Message "Parallel processing enabled. Max concurrent channels: $MaxConcurrentChannels, Max concurrent files: $MaxConcurrentFiles" -Context "Parallel"
}

# Handle rollback operations
if ($Rollback) {
    Write-Log -Level Info -Message "Rollback mode detected. Starting rollback process..." -Context "Rollback"

    if (-not $FullRollback -and -not $SelectiveRollback) {
        Write-Log -Level Error -Message "Must specify either -FullRollback or -SelectiveRollback when using -Rollback" -Context "Rollback"
        exit 1
    }

    $rollbackParams = @{
        Mode = $Mode
        DryRun = $DryRun
    }

    if ($ChannelFilter) { $rollbackParams.ChannelFilter = $ChannelFilter }
    if ($UserFilter) { $rollbackParams.UserFilter = $UserFilter }
    if ($FullRollback) { $rollbackParams.FullRollback = $true }
    if ($SelectiveRollback) { $rollbackParams.SelectiveRollback = $true }
    if ($BackupPath) { $rollbackParams.BackupPath = $BackupPath }

    try {
        Write-Log -Level Info -Message "Executing rollback..." -Context "Rollback"
        & .\Phases\Phase10-Rollback.ps1 @rollbackParams
        Write-Log -Level Info -Message "Rollback completed successfully" -Context "Rollback"
        Send-Notification "Rollback Completed" "Rollback operation finished at $(Get-Date)"
        exit 0
    } catch {
        Write-Log -Level Error -Message "Rollback failed: $_" -Context "Rollback"
        Send-Notification "Rollback Failed" "Rollback operation failed: $_"
        exit 1
    }
}

# Handle real-time sync operations
if ($RealTimeSync) {
    Write-Log -Level Info -Message "Real-time sync mode detected. Starting sync process..." -Context "RealTimeSync"

    $syncParams = @{
        Mode = $Mode
        DryRun = $DryRun
        SyncIntervalMinutes = $SyncIntervalMinutes
        MaxRuntimeHours = $MaxRuntimeHours
        ContinuousMode = $ContinuousMode
    }

    if ($ChannelFilter) { $syncParams.ChannelFilter = $ChannelFilter }
    if ($UserFilter) { $syncParams.UserFilter = $UserFilter }

    try {
        Write-Log -Level Info -Message "Executing real-time sync..." -Context "RealTimeSync"
        & .\Phases\Phase11-RealTimeSync.ps1 @syncParams
        Write-Log -Level Info -Message "Real-time sync completed successfully" -Context "RealTimeSync"
        Send-Notification "Real-Time Sync Completed" "Sync operation finished at $(Get-Date)"
        exit 0
    } catch {
        Write-Log -Level Error -Message "Real-time sync failed: $_" -Context "RealTimeSync"
        Send-Notification "Real-Time Sync Failed" "Sync operation failed: $_"
        exit 1
    }
}

# Phase execution with error handling and confirmations
function Invoke-Phase {
    param([string]$PhaseName, [scriptblock]$ScriptBlock)
    if ($SkipPhases -contains $PhaseName) {
        Write-Log -Level Warn -Message "Skipping $PhaseName per SkipPhases parameter."
        return
    }
    Confirm-Phase $PhaseName
    try {
        Write-Log -Level Info -Message "Starting $PhaseName"
        & $ScriptBlock
        Write-Log -Level Info -Message "$PhaseName completed successfully"
        Send-Notification "Phase Completed: $PhaseName" "$PhaseName finished successfully at $(Get-Date)"
    } catch {
        Write-Log -Level Error -Message "$PhaseName failed: $_"
        Send-Notification "Phase Failed: $PhaseName" "$PhaseName failed: $_"
        if ($ExecutionMode -eq 'ConfirmOnError') {
            $response = Read-Host "Continue after $PhaseName error? (Y/N)"
            if ($response -ne 'Y') {
                Write-Log -Level Warn -Message "User cancelled after $PhaseName error"
                exit 1
            }
        } else {
            throw
        }
    }
}

# Phase 1
Invoke-Phase "Phase1-ParseSlack" {
    $params = @{
        Mode = $Mode
        DryRun = $DryRun
    }
    if ($ChannelFilter) { $params.ChannelFilter = $ChannelFilter }
    if ($UserFilter) { $params.UserFilter = $UserFilter }
    if ($DeltaMode) { $params.DeltaMode = $true }
    & .\Phases\Phase1-ParseSlack.ps1 @params
}

# Phase 2
Invoke-Phase "Phase2-MapUsers" {
    & .\Phases\Phase2-MapUsers.ps1 -Mode $Mode -DryRun:$DryRun
}

# Phase 3
if (-not $SkipProvision -and -not ($SkipPhases -contains "Phase3-ProvisionTeams")) {
    Invoke-Phase "Phase3-ProvisionTeams" {
        $params = @{
            Mode = $Mode
            DryRun = $DryRun
        }
        if ($ChannelFilter) { $params.ChannelFilter = $ChannelFilter }
        if ($DeltaMode) { $params.DeltaMode = $true }
        & .\Phases\Phase3-ProvisionTeams.ps1 @params
    }
} else {
    Write-Log -Level Warn -Message "Skipping Phase3-ProvisionTeams"
}

# Phase 4
Invoke-Phase "Phase4-PostMessages" {
    $params = @{
        Mode = $Mode
        DryRun = $DryRun
    }
    if ($ChannelFilter) { $params.ChannelFilter = $ChannelFilter }
    if ($UserFilter) { $params.UserFilter = $UserFilter }
    if ($DeltaMode) { $params.DeltaMode = $true }
    if ($EnableParallel) {
        $params.EnableParallel = $true
        $params.MaxConcurrentChannels = $MaxConcurrentChannels
    }
    & .\Phases\Phase4-PostMessages.ps1 @params
}

# Phase 5
if (-not $SkipFiles -and -not ($SkipPhases -contains "Phase5-DownloadFiles")) {
    Invoke-Phase "Phase5-DownloadFiles" {
        $params = @{
            Mode = $Mode
            DryRun = $DryRun
        }
        if ($ChannelFilter) { $params.ChannelFilter = $ChannelFilter }
        if ($UserFilter) { $params.UserFilter = $UserFilter }
        if ($DeltaMode) { $params.DeltaMode = $true }
        if ($EnableParallel) {
            $params.EnableParallel = $true
            $params.MaxConcurrentFiles = $MaxConcurrentFiles
        }
        & .\Phases\Phase5-DownloadFiles.ps1 @params
    }
}

# Phase 6
if (-not $SkipFiles -and -not ($SkipPhases -contains "Phase6-UploadFiles")) {
    Invoke-Phase "Phase6-UploadFiles" {
        $params = @{
            Mode = $Mode
            DryRun = $DryRun
        }
        if ($ChannelFilter) { $params.ChannelFilter = $ChannelFilter }
        if ($DeltaMode) { $params.DeltaMode = $true }
        if ($EnableParallel) {
            $params.EnableParallel = $true
            $params.MaxConcurrentFiles = $MaxConcurrentFiles
        }
        & .\Phases\Phase6-UploadFiles.ps1 @params
    }
}

# Phase 7
Invoke-Phase "Phase7-VerifyMigration" {
    & .\Phases\Phase7-VerifyMigration.ps1 -Mode $Mode -DryRun:$DryRun
}

# Phase 8
Invoke-Phase "Phase8-RetryAndFixups" {
    & .\Phases\Phase8-RetryAndFixups.ps1 -Mode $Mode -DryRun:$DryRun
}

# Phase 9
Invoke-Phase "Phase9-ArchiveRun" {
    & .\Phases\Phase9-ArchiveRun.ps1 -Mode $Mode -DryRun:$DryRun
}

Write-Log -Level Info -Message "Run-All.ps1 completed."
Send-Notification "Migration Completed" "All phases completed successfully at $(Get-Date)"
