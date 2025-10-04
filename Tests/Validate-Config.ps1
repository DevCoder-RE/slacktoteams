[CmdletBinding()]
param()

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"

Write-Log -Level Info -Message "Validating configuration files" -Context "Validation"

# Test appsettings.json
Write-Log -Level Info -Message "Testing appsettings.json" -Context "Validation"
try {
    $config = Read-JsonFile -Path "$PSScriptRoot\..\Config\appsettings.sample.json"
    if ($config.Graph -and $config.Slack -and $config.Posting) {
        Write-Log -Level Info -Message "✓ Config structure is valid" -Context "Validation"
    } else {
        Write-Log -Level Warn -Message "⚠ Config missing expected sections" -Context "Validation"
    }
} catch {
    Write-Log -Level Error -Message "✗ Config validation failed: $_" -Context "Validation"
}

# Test channels.csv
Write-Log -Level Info -Message "Testing channels.csv" -Context "Validation"
try {
    $channels = Import-Csv "$PSScriptRoot\..\Config\mappings\channels.csv"
    if ($channels.Count -gt 0) {
        Write-Log -Level Info -Message "✓ Channels mapping has $($channels.Count) entries" -Context "Validation"
    } else {
        Write-Log -Level Warn -Message "⚠ Channels mapping is empty" -Context "Validation"
    }
} catch {
    Write-Log -Level Error -Message "✗ Channels mapping validation failed: $_" -Context "Validation"
}

# Test emoji-map.json
Write-Log -Level Info -Message "Testing emoji-map.json" -Context "Validation"
try {
    $emojis = Read-JsonFile -Path "$PSScriptRoot\..\Config\mappings\emoji-map.json"
    if ($emojis.Count -gt 0) {
        Write-Log -Level Info -Message "✓ Emoji mapping has $($emojis.Count) entries" -Context "Validation"
    } else {
        Write-Log -Level Warn -Message "⚠ Emoji mapping is empty" -Context "Validation"
    }
} catch {
    Write-Log -Level Error -Message "✗ Emoji mapping validation failed: $_" -Context "Validation"
}

# Test message-filters.json
Write-Log -Level Info -Message "Testing message-filters.json" -Context "Validation"
try {
    $filters = Read-JsonFile -Path "$PSScriptRoot\..\Config\message-filters.json"
    Write-Log -Level Info -Message "✓ Message filters loaded successfully" -Context "Validation"
} catch {
    Write-Log -Level Error -Message "✗ Message filters validation failed: $_" -Context "Validation"
}

Write-Log -Level Info -Message "Configuration validation completed" -Context "Validation"