[CmdletBinding()]
param(
    [string]$ArchiveRoot = "Archives"
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"

Write-Log -Level Info -Message "Phase9-ArchiveRun started." -Context "Phase9"

if (-not (Test-Path $ArchiveRoot)) {
    New-Item -ItemType Directory -Path $ArchiveRoot | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archiveDir = Join-Path $ArchiveRoot "Migration_$timestamp"
New-Item -ItemType Directory -Path $archiveDir | Out-Null

$itemsToArchive = @("Output", "Logs", "Reports")
foreach ($item in $itemsToArchive) {
    if (Test-Path $item) {
        $dest = Join-Path $archiveDir $item
        Copy-Item -Path $item -Destination $dest -Recurse -Force
        Write-Log -Level Info -Message "Archived $item to $dest" -Context "Phase9"
    }
}

Write-Log -Level Info -Message "Phase9-ArchiveRun completed. Archive stored at $archiveDir" -Context "Phase9"
