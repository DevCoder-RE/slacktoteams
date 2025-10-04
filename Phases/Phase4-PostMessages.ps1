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
    $postedCount = 0
    foreach ($m in $messages) {
        if ($DryRun) {
            Write-Log -Level Info -Message "DryRun: Would post message from '$($m.author)' to '$channelName'" -Context "Phase4"
        } else {
            $content = "<p><b>$($m.author)</b> ($($m.timestamp))</p>$($m.text_html)"
            Post-ChannelMessage -TeamId $provision.team.id -ChannelId $target.teams_channel_id -Content $content
            $postedCount++
        }
    }
    $postSummary += [pscustomobject]@{
        channel = $channelName
        posted  = $postedCount
    }
}

Write-JsonFile -Path "Output\Phase4-PostMessages\post-summary.json" -Object $postSummary
Write-Log -Level Info -Message "Phase4-PostMessages completed." -Context "Phase4"
