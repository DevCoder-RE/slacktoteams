[CmdletBinding()]
param(
    [ValidateSet('Offline','Live')]
    [string]$Mode = 'Offline',
    [string[]]$ChannelFilter,
    [switch]$DeltaMode,
    [switch]$DryRun
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"
. "$PSScriptRoot\..\Shared\Shared-Graph.ps1"
. "$PSScriptRoot\..\Shared\Shared-Parallel.ps1"

Write-Log -Level Info -Message "Phase6-UploadFiles started. Mode=$Mode ChannelFilter=$($ChannelFilter -join ',') DeltaMode=$DeltaMode DryRun=$DryRun" -Context "Phase6"

$downloadDir = "Output\Phase5-DownloadFiles"
$provisionFile = "Output\Phase3-Provision\provision-summary.json"
if (-not (Test-Path $provisionFile)) { throw "Provision summary not found. Run Phase3 first." }
$provision = Read-JsonFile -Path $provisionFile

# Apply channel filter
if ($ChannelFilter) {
    $provision.channels = $provision.channels | Where-Object { $_.slack_channel_name -in $ChannelFilter }
    Write-Log -Level Info -Message "Filtered to $($provision.channels.Count) channels: $($ChannelFilter -join ',')" -Context "Phase6"
}

$allUploads = @()

foreach ($chan in Get-ChildItem $downloadDir -Directory) {
    if ($ChannelFilter -and $chan.Name -notin $ChannelFilter) { continue }
    $target = $provision.channels | Where-Object { $_.slack_channel_name -eq $chan.Name }
    if (-not $target) {
        Write-Log -Level Warn -Message "No provisioned channel for '$($chan.Name)'. Skipping." -Context "Phase6"
        continue
    }

    foreach ($file in Get-ChildItem $chan.FullName -File) {
        $allUploads += @{
            TeamId = $provision.team.id
            ChannelId = $target.teams_channel_id
            FilePath = $file.FullName
            FileName = $file.Name
            ChannelName = $target.teams_channel_name
        }
    }
}

if ($DryRun) {
    Write-Log -Level Info -Message "DryRun: Would upload $($allUploads.Count) files" -Context "Phase6"
} else {
    $maxConcurrent = [int](Get-Config 'Parallel.MaxConcurrentUploads' 2)
    Start-ParallelFileUpload -FileUploads $allUploads -MaxConcurrentUploads $maxConcurrent
}

Write-Log -Level Info -Message "Phase6-UploadFiles completed." -Context "Phase6"
