[CmdletBinding()]
param(
    [ValidateSet('Offline','Live')]
    [string]$Mode = 'Offline',
    [string[]]$ChannelFilter,
    [string[]]$UserFilter,
    [switch]$DryRun,
    [int]$SyncIntervalMinutes = 5,
    [int]$MaxRuntimeHours = 24,
    [switch]$ContinuousMode
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"
. "$PSScriptRoot\..\Shared\Shared-Graph.ps1"
. "$PSScriptRoot\..\Shared\Shared-Slack.ps1"

Write-Log -Level Info -Message "Phase11-RealTimeSync started. Mode=$Mode SyncIntervalMinutes=$SyncIntervalMinutes MaxRuntimeHours=$MaxRuntimeHours ContinuousMode=$ContinuousMode DryRun=$DryRun" -Context "Phase11"

# Load migration data
$provisionFile = "Output\Phase3-Provision\provision-summary.json"
if (-not (Test-Path $provisionFile)) {
    throw "No migration data found. Run Phase3 first."
}

$provision = Read-JsonFile -Path $provisionFile
$userMapFile = "Output\Phase2-MapUsers\user_map.json"
$userMap = @{}
if (Test-Path $userMapFile) {
    $userMap = Read-JsonFile -Path $userMapFile
}

# Sync state tracking
$syncStateFile = "Output\Phase11-RealTimeSync\sync-state.json"
$syncStateDir = Split-Path $syncStateFile -Parent
if (-not (Test-Path $syncStateDir)) {
    New-Item -ItemType Directory -Path $syncStateDir | Out-Null
}

$syncState = @{
    lastSyncTimestamp = (Get-Date).AddMinutes(-$SyncIntervalMinutes)
    channels = @{}
    processedMessages = @{}
    startTime = Get-Date
    totalMessagesSynced = 0
    errors = @()
}

# Load existing sync state if available
if (Test-Path $syncStateFile) {
    $existingState = Read-JsonFile -Path $syncStateFile
    $syncState.lastSyncTimestamp = [DateTime]::Parse($existingState.lastSyncTimestamp)
    $syncState.channels = $existingState.channels
    $syncState.processedMessages = $existingState.processedMessages
    Write-Log -Level Info -Message "Loaded existing sync state from $(Get-Date $syncState.lastSyncTimestamp)" -Context "Phase11"
}

function Get-SlackChannelMessagesSince {
    param([string]$ChannelId, [DateTime]$Since)

    # This would integrate with Slack API to get recent messages
    # For now, return mock data structure
    Write-Log -Level Info -Message "Checking for new messages in channel $ChannelId since $Since" -Context "Phase11"

    # Mock implementation - in real scenario, this would call Slack API
    return @()
}

function Sync-MessageToTeams {
    param([object]$SlackMessage, [string]$TeamId, [string]$ChannelId, [hashtable]$UserMap)

    $authorId = $SlackMessage.user
    $teamsUserId = $null

    if ($UserMap.ContainsKey($authorId)) {
        $teamsUserId = $UserMap[$authorId].M365UserId
    }

    if (-not $teamsUserId) {
        Write-Log -Level Warn -Message "No Teams user mapping found for Slack user $authorId" -Context "Phase11"
        return $false
    }

    $messageBody = @{
        contentType = "html"
        content = $SlackMessage.text
    }

    if ($DryRun) {
        Write-Log -Level Info -Message "DryRun: Would sync message from $($SlackMessage.user) to Teams channel $ChannelId" -Context "Phase11"
        return $true
    }

    try {
        # Post message to Teams
        $messageParams = @{
            TeamId = $TeamId
            ChannelId = $ChannelId
            Content = $messageBody.content
        }

        Post-ChannelMessage @messageParams
        Write-Log -Level Info -Message "Synced message $($SlackMessage.ts) to Teams" -Context "Phase11"
        return $true
    } catch {
        Write-Log -Level Error -Message "Failed to sync message $($SlackMessage.ts): $_" -Context "Phase11"
        $syncState.errors += "Message sync failed for $($SlackMessage.ts): $_"
        return $false
    }
}

function Save-SyncState {
    param([object]$State)

    $State.lastSyncTimestamp = (Get-Date)
    $stateJson = $State | ConvertTo-Json -Depth 5
    $stateJson | Set-Content -Path $syncStateFile -Encoding UTF8
    Write-Log -Level Info -Message "Sync state saved" -Context "Phase11"
}

# Main sync loop
$startTime = Get-Date
$maxEndTime = $startTime.AddHours($MaxRuntimeHours)

Write-Log -Level Info -Message "Starting real-time sync loop. Interval: $SyncIntervalMinutes minutes, Max runtime: $MaxRuntimeHours hours" -Context "Phase11"

do {
    $currentTime = Get-Date

    if ($currentTime -gt $maxEndTime) {
        Write-Log -Level Info -Message "Maximum runtime reached. Stopping sync." -Context "Phase11"
        break
    }

    Write-Log -Level Info -Message "Starting sync cycle at $currentTime" -Context "Phase11"

    # Process each provisioned channel
    foreach ($channel in $provision.channels) {
        if ($ChannelFilter -and $channel.slack_channel_name -notin $ChannelFilter) {
            continue
        }

        Write-Log -Level Info -Message "Processing channel: $($channel.slack_channel_name)" -Context "Phase11"

        # Get new messages since last sync
        $newMessages = Get-SlackChannelMessagesSince -ChannelId $channel.slack_channel_name -Since $syncState.lastSyncTimestamp

        foreach ($message in $newMessages) {
            # Check if message already processed
            $messageKey = "$($channel.slack_channel_name)-$($message.ts)"
            if ($syncState.processedMessages.ContainsKey($messageKey)) {
                continue
            }

            # Apply user filter if specified
            if ($UserFilter -and $message.user -notin $UserFilter) {
                continue
            }

            # Sync message to Teams
            if (Sync-MessageToTeams -SlackMessage $message -TeamId $provision.team.id -ChannelId $channel.teams_channel_id -UserMap $userMap) {
                $syncState.processedMessages[$messageKey] = @{
                    syncedAt = (Get-Date)
                    slackTs = $message.ts
                }
                $syncState.totalMessagesSynced++
            }
        }

        # Update channel sync timestamp
        $syncState.channels[$channel.slack_channel_name] = @{
            lastSync = (Get-Date)
            messagesSynced = $syncState.totalMessagesSynced
        }
    }

    # Save sync state
    Save-SyncState -State $syncState

    # Wait for next sync cycle (unless in continuous mode with very short interval)
    if (-not $ContinuousMode -or $SyncIntervalMinutes -gt 0) {
        $nextSyncTime = (Get-Date).AddMinutes($SyncIntervalMinutes)
        Write-Log -Level Info -Message "Sync cycle completed. Next sync at $nextSyncTime" -Context "Phase11"

        if ($SyncIntervalMinutes -gt 0) {
            Start-Sleep -Seconds ($SyncIntervalMinutes * 60)
        }
    }

} while ($ContinuousMode -or ((Get-Date) -lt $maxEndTime))

# Final summary
$endTime = Get-Date
$duration = $endTime - $startTime

$summary = @{
    startTime = $startTime
    endTime = $endTime
    duration = $duration.TotalMinutes
    totalMessagesSynced = $syncState.totalMessagesSynced
    channelsProcessed = $syncState.channels.Count
    errors = $syncState.errors
    finalSyncTimestamp = $syncState.lastSyncTimestamp
}

$summaryFile = "Output\Phase11-RealTimeSync\sync-summary.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryFile -Encoding UTF8

Write-Log -Level Info -Message "Real-time sync completed. Duration: $($duration.TotalMinutes) minutes, Messages synced: $($syncState.totalMessagesSynced)" -Context "Phase11"
Write-Log -Level Info -Message "Summary saved to: $summaryFile" -Context "Phase11"

Write-Log -Level Info -Message "Phase11-RealTimeSync completed." -Context "Phase11"