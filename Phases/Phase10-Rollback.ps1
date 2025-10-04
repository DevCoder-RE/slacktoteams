[CmdletBinding()]
param(
    [ValidateSet('Offline','Live')]
    [string]$Mode = 'Offline',
    [string[]]$ChannelFilter,
    [string[]]$UserFilter,
    [switch]$DryRun,
    [switch]$FullRollback,
    [switch]$SelectiveRollback,
    [string]$BackupPath
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"
. "$PSScriptRoot\..\Shared\Shared-Graph.ps1"

Write-Log -Level Info -Message "Phase10-Rollback started. Mode=$Mode DryRun=$DryRun FullRollback=$FullRollback SelectiveRollback=$SelectiveRollback" -Context "Phase10"

# Validate rollback parameters
if (-not $FullRollback -and -not $SelectiveRollback) {
    throw "Must specify either -FullRollback or -SelectiveRollback"
}

if ($FullRollback -and $SelectiveRollback) {
    throw "Cannot specify both -FullRollback and -SelectiveRollback"
}

# Set default backup path
if (-not $BackupPath) {
    $BackupPath = "Output\Phase10-Rollback\$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss')"
}

$backupDir = $BackupPath
$summary = @{
    startTime = Get-Date
    mode = $Mode
    rollbackType = if ($FullRollback) { "Full" } elseif ($SelectiveRollback) { "Selective" } else { "Unknown" }
    channelsProcessed = 0
    messagesRemoved = 0
    filesRemoved = 0
    errors = @()
}

function Backup-TeamData {
    param([string]$TeamId, [string]$BackupPath)

    Write-Log -Level Info -Message "Backing up Team data for TeamId: $TeamId" -Context "Phase10"

    $teamData = @{
        team = $null
        channels = @()
        messages = @()
        files = @()
    }

    try {
        # Get team info
        $team = Get-MgTeam -TeamId $TeamId
        $teamData.team = $team

        # Get channels
        $channels = Get-MgTeamChannel -TeamId $TeamId
        $teamData.channels = $channels

        # Backup messages and files for each channel
        foreach ($channel in $channels) {
            Write-Log -Level Info -Message "Backing up channel: $($channel.DisplayName)" -Context "Phase10"

            try {
                $messages = Get-MgTeamChannelMessage -TeamId $TeamId -ChannelId $channel.Id -All
                $channelMessages = @()

                foreach ($message in $messages) {
                    $channelMessages += @{
                        id = $message.Id
                        createdDateTime = $message.CreatedDateTime
                        from = $message.From
                        body = $message.Body
                        attachments = $message.Attachments
                    }
                }

                $teamData.messages += @{
                    channelId = $channel.Id
                    channelName = $channel.DisplayName
                    messages = $channelMessages
                }

                # Get files in channel
                $files = Get-MgTeamChannelFile -TeamId $TeamId -ChannelId $channel.Id
                if ($files) {
                    $teamData.files += @{
                        channelId = $channel.Id
                        channelName = $channel.DisplayName
                        files = $files
                    }
                }

            } catch {
                Write-Log -Level Warn -Message "Failed to backup channel $($channel.DisplayName): $_" -Context "Phase10"
                $summary.errors += "Backup failed for channel $($channel.DisplayName): $_"
            }
        }

        # Save backup
        $backupFile = Join-Path $BackupPath "team-backup-$TeamId.json"
        $teamData | ConvertTo-Json -Depth 10 | Set-Content -Path $backupFile -Encoding UTF8

        Write-Log -Level Info -Message "Backup completed for TeamId: $TeamId" -Context "Phase10"
        return $backupFile

    } catch {
        Write-Log -Level Error -Message "Failed to backup team $TeamId : $_" -Context "Phase10"
        $summary.errors += "Team backup failed: $_"
        return $null
    }
}

function Remove-TeamChannel {
    param([string]$TeamId, [string]$ChannelId, [string]$ChannelName)

    if ($DryRun) {
        Write-Log -Level Info -Message "DryRun: Would remove channel '$ChannelName' ($ChannelId)" -Context "Phase10"
        return $true
    }

    try {
        Remove-MgTeamChannel -TeamId $TeamId -ChannelId $ChannelId
        Write-Log -Level Info -Message "Removed channel '$ChannelName' ($ChannelId)" -Context "Phase10"
        return $true
    } catch {
        Write-Log -Level Error -Message "Failed to remove channel '$ChannelName': $_" -Context "Phase10"
        $summary.errors += "Channel removal failed for '$ChannelName': $_"
        return $false
    }
}

function Remove-TeamMessages {
    param([string]$TeamId, [string]$ChannelId, [string]$ChannelName, [array]$MessageIds)

    if ($DryRun) {
        Write-Log -Level Info -Message "DryRun: Would remove $($MessageIds.Count) messages from '$ChannelName'" -Context "Phase10"
        return $MessageIds.Count
    }

    $removedCount = 0
    foreach ($messageId in $MessageIds) {
        try {
            Remove-MgTeamChannelMessage -TeamId $TeamId -ChannelId $ChannelId -ChatMessageId $messageId
            $removedCount++
        } catch {
            Write-Log -Level Warn -Message "Failed to remove message $messageId from '$ChannelName': $_" -Context "Phase10"
            $summary.errors += "Message removal failed for $messageId in '$ChannelName': $_"
        }
    }

    Write-Log -Level Info -Message "Removed $removedCount messages from '$ChannelName'" -Context "Phase10"
    return $removedCount
}

function Remove-TeamFiles {
    param([string]$TeamId, [string]$ChannelId, [string]$ChannelName, [array]$FileIds)

    if ($DryRun) {
        Write-Log -Level Info -Message "DryRun: Would remove $($FileIds.Count) files from '$ChannelName'" -Context "Phase10"
        return $FileIds.Count
    }

    $removedCount = 0
    foreach ($fileId in $FileIds) {
        try {
            # Note: File removal would require additional Graph permissions and logic
            # This is a placeholder for file deletion implementation
            Write-Log -Level Warn -Message "File removal not yet implemented for file $fileId" -Context "Phase10"
        } catch {
            Write-Log -Level Warn -Message "Failed to remove file $fileId from '$ChannelName': $_" -Context "Phase10"
            $summary.errors += "File removal failed for $fileId in '$ChannelName': $_"
        }
    }

    return $removedCount
}

# Main rollback logic
try {
    # Load migration data
    $provisionFile = "Output\Phase3-Provision\provision-summary.json"
    if (-not (Test-Path $provisionFile)) {
        throw "No migration data found. Cannot perform rollback."
    }

    $provision = Read-JsonFile -Path $provisionFile
    $teamId = $provision.team.id
    $teamName = $provision.team.displayName

    Write-Log -Level Info -Message "Starting rollback for Team: $teamName ($teamId)" -Context "Phase10"

    # Create backup directory
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir | Out-Null
    }

    # Backup current state
    Write-Log -Level Info -Message "Creating backup before rollback..." -Context "Phase10"
    $backupFile = Backup-TeamData -TeamId $teamId -BackupPath $backupDir

    if (-not $backupFile) {
        throw "Backup failed. Aborting rollback to prevent data loss."
    }

    # Apply filters if specified
    $channelsToProcess = $provision.channels
    if ($ChannelFilter) {
        $channelsToProcess = $channelsToProcess | Where-Object { $_.slack_channel_name -in $ChannelFilter }
        Write-Log -Level Info -Message "Filtered to $($channelsToProcess.Count) channels for rollback" -Context "Phase10"
    }

    # Perform rollback based on type
    if ($FullRollback) {
        Write-Log -Level Info -Message "Performing FULL rollback - removing entire team" -Context "Phase10"

        if (-not $DryRun) {
            # Remove all channels first
            foreach ($channel in $channelsToProcess) {
                Remove-TeamChannel -TeamId $teamId -ChannelId $channel.teams_channel_id -ChannelName $channel.teams_channel_name
                $summary.channelsProcessed++
            }

            # Remove the team itself
            try {
                Remove-MgTeam -TeamId $teamId
                Write-Log -Level Info -Message "Removed team '$teamName' ($teamId)" -Context "Phase10"
            } catch {
                Write-Log -Level Error -Message "Failed to remove team '$teamName': $_" -Context "Phase10"
                $summary.errors += "Team removal failed: $_"
            }
        } else {
            Write-Log -Level Info -Message "DryRun: Would remove team '$teamName' and all $($channelsToProcess.Count) channels" -Context "Phase10"
        }

    } elseif ($SelectiveRollback) {
        Write-Log -Level Info -Message "Performing SELECTIVE rollback" -Context "Phase10"

        # Load migration tracking data to identify migrated content
        $migrationDataPath = "Output\Phase4-PostMessages\post-summary.json"
        if (Test-Path $migrationDataPath) {
            $migrationData = Read-JsonFile -Path $migrationDataPath

            foreach ($channel in $channelsToProcess) {
                $channelMigration = $migrationData | Where-Object { $_.channel -eq $channel.slack_channel_name }

                if ($channelMigration) {
                    # This is a simplified approach - in reality, you'd need to track which messages were migrated
                    Write-Log -Level Info -Message "Processing selective rollback for channel: $($channel.teams_channel_name)" -Context "Phase10"

                    # Placeholder for selective message/file removal
                    # Would need actual message IDs from migration tracking
                    $summary.channelsProcessed++
                }
            }
        } else {
            Write-Log -Level Warn -Message "No migration tracking data found. Selective rollback limited." -Context "Phase10"
        }
    }

    # Save rollback summary
    $summary.endTime = Get-Date
    $summary.duration = ($summary.endTime - $summary.startTime).TotalSeconds
    $summary.backupLocation = $backupFile

    $summaryPath = Join-Path $backupDir "rollback-summary.json"
    $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8

    Write-Log -Level Info -Message "Rollback completed. Summary saved to: $summaryPath" -Context "Phase10"
    Write-Log -Level Info -Message "Backup location: $backupFile" -Context "Phase10"

} catch {
    Write-Log -Level Error -Message "Rollback failed: $_" -Context "Phase10"
    throw
}

Write-Log -Level Info -Message "Phase10-Rollback completed." -Context "Phase10"