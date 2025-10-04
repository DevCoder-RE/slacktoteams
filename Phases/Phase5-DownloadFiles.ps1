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
. "$PSScriptRoot\..\Shared\Shared-Slack.ps1"
. "$PSScriptRoot\..\Shared\Shared-Parallel.ps1"

Write-Log -Level Info -Message "Phase5-DownloadFiles started. Mode=$Mode ChannelFilter=$($ChannelFilter -join ',') UserFilter=$($UserFilter -join ',') DeltaMode=$DeltaMode DryRun=$DryRun" -Context "Phase5"

$parsedDir = "Output\Phase1-ParseSlack"
$downloadDir = "Output\Phase5-DownloadFiles"
if (-not (Test-Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir | Out-Null }

$parsedFiles = Get-ChildItem $parsedDir -Filter "*-parsed-messages.json"

# Apply channel filter
if ($ChannelFilter) {
    $parsedFiles = $parsedFiles | Where-Object { ($_.BaseName -replace '-parsed-messages$','') -in $ChannelFilter }
    Write-Log -Level Info -Message "Filtered to $($parsedFiles.Count) channels: $($ChannelFilter -join ',')" -Context "Phase5"
}

$allDownloads = @()

foreach ($file in $parsedFiles) {
    $channelName = $file.BaseName -replace '-parsed-messages$',''
    $messages = Read-JsonFile -Path $file.FullName

    # Apply user filter
    if ($UserFilter) {
        $messages = $messages | Where-Object { $_.slack_user_id -in $UserFilter }
        Write-Log -Level Info -Message "Filtered to $($messages.Count) messages for users: $($UserFilter -join ',')" -Context "Phase5"
    }

    $chanDir = Join-Path $downloadDir $channelName
    if (-not (Test-Path $chanDir)) { New-Item -ItemType Directory -Path $chanDir | Out-Null }
    foreach ($m in $messages) {
        foreach ($f in $m.files) {
            $dest = Join-Path $chanDir $f.name
            if ($DeltaMode -and (Test-Path $dest)) {
                Write-Log -Level Info -Message "Delta mode: Skipping '$($f.name)' (already downloaded)" -Context "Phase5"
                continue
            }
            $allDownloads += @{
                UrlPrivate = $f.url_private
                Dest = $dest
                FileName = $f.name
            }
        }
    }
}

if ($DryRun) {
    Write-Log -Level Info -Message "DryRun: Would download $($allDownloads.Count) files" -Context "Phase5"
} else {
    $maxConcurrent = [int](Get-Config 'Parallel.MaxConcurrentDownloads' 3)
    Start-ParallelFileDownload -FileDownloads $allDownloads -MaxConcurrentDownloads $maxConcurrent -Mode $Mode
}

Write-Log -Level Info -Message "Phase5-DownloadFiles completed." -Context "Phase5"
