[CmdletBinding()]
param(
    [switch]$RemoveTemp,
    [switch]$RemoveOutput
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"

Write-Log -Level Info -Message "Phase8-Cleanup started." -Context "Phase8"

if ($RemoveTemp) {
    $tempPath = "Temp"
    if (Test-Path $tempPath) {
        Remove-Item -Path $tempPath -Recurse -Force
        Write-Log -Level Info -Message "Removed Temp folder." -Context "Phase8"
    }
}

if ($RemoveOutput) {
    $outputPath = "Output"
    if (Test-Path $outputPath) {
        Remove-Item -Path $outputPath -Recurse -Force
        Write-Log -Level Info -Message "Removed Output folder." -Context "Phase8"
    }
}

Write-Log -Level Info -Message "Phase8-Cleanup completed." -Context "Phase8"
