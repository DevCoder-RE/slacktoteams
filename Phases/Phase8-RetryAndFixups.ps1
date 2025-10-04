[CmdletBinding()]
param(
    [switch]$RetryFailedMessages,
    [switch]$RetryFailedFiles,
    [switch]$FixUserMappings
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"
. "$PSScriptRoot\..\Shared\Shared-Graph.ps1"
. "$PSScriptRoot\..\Shared\Shared-Slack.ps1"

Write-Log -Level Info -Message "Phase8-RetryAndFixups started." -Context "Phase8"

# Retry failed messages
if ($RetryFailedMessages) {
    $postSummaryFile = "Output\Phase4-PostMessages\post-summary.json"
    if (-not (Test-Path $postSummaryFile)) {
        Write-Log -Level Warn -Message "No post-summary.json found. Skipping message retries." -Context "Phase8"
    } else {
        $postSummary = Read-JsonFile -Path $postSummaryFile
        foreach ($entry in $postSummary) {
            if ($entry.failed -and $entry.failed.Count -gt 0) {
                Write-Log -Level Info -Message "Retrying $($entry.failed.Count) failed messages in channel $($entry.channel)" -Context "Phase8"
                foreach ($msg in $entry.failed) {
                    try {
                        Post-ChannelMessage -TeamId $entry.team_id -ChannelId $entry.channel_id -Content $msg.html
                        Write-Log -Level Info -Message "Retried message in $($entry.channel)" -Context "Phase8"
                    } catch {
                        Write-Log -Level Error -Message "Retry failed for message in $($entry.channel): $_" -Context "Phase8"
                    }
                }
            }
        }
    }
}

# Retry failed files
if ($RetryFailedFiles) {
    $uploadSummaryFile = "Output\Phase6-UploadFiles\upload-summary.json"
    if (-not (Test-Path $uploadSummaryFile)) {
        Write-Log -Level Warn -Message "No upload-summary.json found. Skipping file retries." -Context "Phase8"
    } else {
        $uploadSummary = Read-JsonFile -Path $uploadSummaryFile
        foreach ($entry in $uploadSummary) {
            if ($entry.failed -and $entry.failed.Count -gt 0) {
                Write-Log -Level Info -Message "Retrying $($entry.failed.Count) failed files in channel $($entry.channel)" -Context "Phase8"
                foreach ($file in $entry.failed) {
                    try {
                        Upload-FileToChannel -TeamId $entry.team_id -ChannelId $entry.channel_id -FilePath $file.local_path
                        Write-Log -Level Info -Message "Retried file $($file.name) in $($entry.channel)" -Context "Phase8"
                    } catch {
                        Write-Log -Level Error -Message "Retry failed for file $($file.name) in $($entry.channel): $_" -Context "Phase8"
                    }
                }
            }
        }
    }
}

# Fix user mappings
if ($FixUserMappings) {
    $userMapFile = "Output\Phase2-MapUsers\user-map.json"
    if (-not (Test-Path $userMapFile)) {
        Write-Log -Level Warn -Message "No user-map.json found. Skipping user mapping fixups." -Context "Phase8"
    } else {
        $userMap = Read-JsonFile -Path $userMapFile
        foreach ($user in $userMap) {
            if (-not $user.teams_upn -and $user.slack_email) {
                $found = Find-AadUserByEmail -Email $user.slack_email
                if ($found) {
                    $user.teams_upn = $found.userPrincipalName
                    Write-Log -Level Info -Message "Fixed mapping for $($user.slack_display_name)" -Context "Phase8"
                }
            }
        }
        Write-JsonFile -Path $userMapFile -Object $userMap
    }
}

Write-Log -Level Info -Message "Phase8-RetryAndFixups completed." -Context "Phase8"
