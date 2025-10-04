[CmdletBinding()]
param(
    [switch]$Detailed
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"

Write-Log -Level Info -Message "Phase7-VerifyMigration started." -Context "Phase7"

$provisionFile = "Output\Phase3-Provision\provision-summary.json"
$postSummaryFile = "Output\Phase4-PostMessages\post-summary.json"
$downloadDir = "Output\Phase5-DownloadFiles"

if (-not (Test-Path $provisionFile)) { throw "Provision summary not found." }
if (-not (Test-Path $postSummaryFile)) { throw "Post summary not found." }

$provision = Read-JsonFile -Path $provisionFile
$postSummary = Read-JsonFile -Path $postSummaryFile

$report = @()

foreach ($chan in $provision.channels) {
    $posted = ($postSummary | Where-Object { $_.channel -eq $chan.slack_channel_name }).posted
    $filesCount = 0
    $chanDir = Join-Path $downloadDir $chan.slack_channel_name
    if (Test-Path $chanDir) {
        $filesCount = (Get-ChildItem $chanDir -File).Count
    }

    $report += [pscustomobject]@{
        SlackChannel   = $chan.slack_channel_name
        TeamsChannel   = $chan.teams_channel_name
        MessagesPosted = $posted
        FilesUploaded  = $filesCount
    }
}

if ($Detailed) {
    $report | Format-Table -AutoSize
} else {
    $totalMessages = ($report.MessagesPosted | Measure-Object -Sum).Sum
    $totalFiles    = ($report.FilesUploaded | Measure-Object -Sum).Sum
    Write-Log -Level Info -Message "Total messages posted: $totalMessages" -Context "Phase7"
    Write-Log -Level Info -Message "Total files uploaded: $totalFiles" -Context "Phase7"
}

Write-JsonFile -Path "Output\Phase7-VerifyMigration\verify-summary.json" -Object $report
Write-Log -Level Info -Message "Phase7-VerifyMigration completed." -Context "Phase7"
