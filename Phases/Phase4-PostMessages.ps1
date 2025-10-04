[CmdletBinding()]
param(
    [ValidateSet('Offline','Live')]
    [string]$Mode = 'Offline',
    [string[]]$ChannelFilter,
    [string[]]$UserFilter,
    [switch]$DeltaMode,
    [switch]$DryRun
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"
. "$PSScriptRoot\..\Shared\Shared-Graph.ps1"

Write-Log -Level Info -Message "Phase4-PostMessages started. Mode=$Mode ChannelFilter=$($ChannelFilter -join ',') UserFilter=$($UserFilter -join ',') DeltaMode=$DeltaMode DryRun=$DryRun" -Context "Phase4"

$parsedDir = "Output\Phase1-ParseSlack"
$provisionFile = "Output\Phase3-Provision\provision-summary.json"
if (-not (Test-Path $provisionFile)) { throw "Provision summary not found. Run Phase3 first." }
$provision = Read-JsonFile -Path $provisionFile

$postSummary = @()

$parsedFiles = Get-ChildItem $parsedDir -Filter "*-parsed-messages.json"

# Apply channel filter
if ($ChannelFilter) {
    $parsedFiles = $parsedFiles | Where-Object { ($_.BaseName -replace '-parsed-messages$','') -in $ChannelFilter }
    Write-Log -Level Info -Message "Filtered to $($parsedFiles.Count) channels: $($ChannelFilter -join ',')" -Context "Phase4"
}

foreach ($file in $parsedFiles) {
    $channelName = $file.BaseName -replace '-parsed-messages$',''
    $messages = Read-JsonFile -Path $file.FullName

    # Apply user filter
    if ($UserFilter) {
        $messages = $messages | Where-Object { $_.slack_user_id -in $UserFilter }
        Write-Log -Level Info -Message "Filtered to $($messages.Count) messages for users: $($UserFilter -join ',')" -Context "Phase4"
    }

    $target = $provision.channels | Where-Object { $_.slack_channel_name -eq $channelName }
    if (-not $target) {
        Write-Log -Level Warn -Message "No provisioned channel for '$channelName'. Skipping." -Context "Phase4"
        continue
    }

    # Delta mode: check if already posted
    if ($DeltaMode) {
        $existingSummary = "Output\Phase4-PostMessages\post-summary.json"
        if (Test-Path $existingSummary) {
            $existing = Read-JsonFile -Path $existingSummary
            if ($existing | Where-Object { $_.channel -eq $channelName -and $_.posted -gt 0 }) {
                Write-Log -Level Info -Message "Delta mode: Skipping $channelName (already posted)" -Context "Phase4"
                continue
            }
        }
    }

    # Sort messages by timestamp for threading
    $messages = $messages | Sort-Object { [DateTime]::Parse($_.timestamp) }

    # Group messages by thread
    $threads = @{}
    $rootMessages = @()
    foreach ($m in $messages) {
        if ($m.thread_ts) {
            if (-not $threads.ContainsKey($m.thread_ts)) {
                $threads[$m.thread_ts] = @()
            }
            $threads[$m.thread_ts] += $m
        } else {
            $rootMessages += $m
        }
    }

    $postedCount = 0
    $messageIdMap = @{}  # Map slack ts to teams message id

    # Post root messages first
    foreach ($m in $rootMessages) {
        $content = "<p><b>$($m.author)</b> ($($m.timestamp))</p>$($m.text_html)"
        if ($DryRun) {
            Write-Log -Level Info -Message "DryRun: Would post root message to '$channelName'" -Context "Phase4"
            $postedCount++
        } else {
            try {
                $response = Post-ChannelMessage -TeamId $provision.team.id -ChannelId $target.teams_channel_id -Content $content
                $messageIdMap[$m.raw.ts] = $response.id
                $postedCount++
                # Add reactions
                if ($m.reactions) {
                    foreach ($r in $m.reactions) {
                        # Map Slack emoji to Teams reaction type (simplified)
                        $reactionType = switch ($r.name) {
                            'thumbsup' { 'like' }
                            'heart' { 'heart' }
                            default { 'like' }  # Default to like
                        }
                        try {
                            Add-MessageReaction -TeamId $provision.team.id -ChannelId $target.teams_channel_id -MessageId $response.id -ReactionType $reactionType
                        } catch {
                            Write-Log -Level Warn -Message "Failed to add reaction to message: $($_.Exception.Message)" -Context "Phase4"
                        }
                    }
                }
            } catch {
                Write-Log -Level Error -Message "Root message posting failed: $($_.Exception.Message)" -Context "Phase4"
            }
        }
    }

    # Post thread replies
    foreach ($threadTs in $threads.Keys) {
        $replies = $threads[$threadTs] | Sort-Object { [DateTime]::Parse($_.timestamp) }
        $parentId = $messageIdMap[$threadTs]
        if (-not $parentId) {
            Write-Log -Level Warn -Message "Parent message not found for thread $threadTs, posting as root" -Context "Phase4"
            $parentId = $null
        }
        foreach ($m in $replies) {
            $content = "<p><b>$($m.author)</b> ($($m.timestamp))</p>$($m.text_html)"
            if ($DryRun) {
                Write-Log -Level Info -Message "DryRun: Would post reply to '$channelName'" -Context "Phase4"
                $postedCount++
            } else {
                try {
                    if ($parentId) {
                        $response = Reply-ChannelMessage -TeamId $provision.team.id -ChannelId $target.teams_channel_id -MessageId $parentId -Content $content
                    } else {
                        $response = Post-ChannelMessage -TeamId $provision.team.id -ChannelId $target.teams_channel_id -Content $content
                    }
                    $messageIdMap[$m.raw.ts] = $response.id
                    $postedCount++
                    # Add reactions
                    if ($m.reactions) {
                        foreach ($r in $m.reactions) {
                            $reactionType = switch ($r.name) {
                                'thumbsup' { 'like' }
                                'heart' { 'heart' }
                                default { 'like' }
                            }
                            try {
                                Add-MessageReaction -TeamId $provision.team.id -ChannelId $target.teams_channel_id -MessageId $response.id -ReactionType $reactionType
                            } catch {
                                Write-Log -Level Warn -Message "Failed to add reaction to reply: $($_.Exception.Message)" -Context "Phase4"
                            }
                        }
                    }
                } catch {
                    Write-Log -Level Error -Message "Reply posting failed: $($_.Exception.Message)" -Context "Phase4"
                }
            }
        }
    }
    $postSummary += [pscustomobject]@{
        channel = $channelName
        posted  = $postedCount
    }
}

Write-JsonFile -Path "Output\Phase4-PostMessages\post-summary.json" -Object $postSummary
Write-Log -Level Info -Message "Phase4-PostMessages completed." -Context "Phase4"
