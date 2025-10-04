[CmdletBinding()]
param()

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"

Write-Log -Level Info -Message "Validating test data" -Context "Validation"

# Test Slack export structure
Write-Log -Level Info -Message "Testing Slack export structure" -Context "Validation"
$exportPath = "$PSScriptRoot\testdata\slack_export"

if (Test-Path "$exportPath\channels.json") {
    try {
        $channels = Read-JsonFile -Path "$exportPath\channels.json"
        Write-Log -Level Info -Message "✓ Found $($channels.Count) channels in export" -Context "Validation"
    } catch {
        Write-Log -Level Error -Message "✗ Failed to parse channels.json: $_" -Context "Validation"
    }
} else {
    Write-Log -Level Error -Message "✗ channels.json not found" -Context "Validation"
}

if (Test-Path "$exportPath\users.json") {
    try {
        $users = Read-JsonFile -Path "$exportPath\users.json"
        Write-Log -Level Info -Message "✓ Found $($users.Count) users in export" -Context "Validation"
    } catch {
        Write-Log -Level Error -Message "✗ Failed to parse users.json: $_" -Context "Validation"
    }
} else {
    Write-Log -Level Error -Message "✗ users.json not found" -Context "Validation"
}

# Test channel directories
$channelDirs = Get-ChildItem $exportPath -Directory
Write-Log -Level Info -Message "✓ Found $($channelDirs.Count) channel directories" -Context "Validation"

foreach ($dir in $channelDirs) {
    $jsonFiles = Get-ChildItem "$exportPath\$($dir.Name)" -Filter "*.json"
    Write-Log -Level Info -Message "  - $($dir.Name): $($jsonFiles.Count) message files" -Context "Validation"
}

# Test file payloads
Write-Log -Level Info -Message "Testing file payloads" -Context "Validation"
$filePayloads = Get-ChildItem "$PSScriptRoot\testdata\file_payloads" -File
Write-Log -Level Info -Message "✓ Found $($filePayloads.Count) test files" -Context "Validation"

foreach ($file in $filePayloads) {
    $size = [math]::Round($file.Length / 1MB, 2)
    Write-Log -Level Info -Message "  - $($file.Name): $size MB" -Context "Validation"
}

Write-Log -Level Info -Message "Test data validation completed" -Context "Validation"