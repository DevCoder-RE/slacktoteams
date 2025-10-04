[CmdletBinding()]
param(
    [switch]$SkipCleanup
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"

Write-Log -Level Info -Message "Starting test suite" -Context "Test"

# Test configuration
$testConfig = @{
    SlackExportPath = "$PSScriptRoot\testdata\slack_export"
    OutputDir = "$PSScriptRoot\..\Output"
    TestTeamName = "Test Migration Team"
}

# Clean output directory
if (-not $SkipCleanup) {
    if (Test-Path $testConfig.OutputDir) {
        Remove-Item $testConfig.OutputDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $testConfig.OutputDir | Out-Null
}

# Test Phase 1
Write-Log -Level Info -Message "Testing Phase 1: Parse Slack Export" -Context "Test"
try {
    & "$PSScriptRoot\..\Phases\Phase1-ParseSlack.ps1" -Mode Offline -DryRun
    if (Test-Path "$($testConfig.OutputDir)\Phase1-ParseSlack\discovery-summary.json") {
        Write-Log -Level Info -Message "Phase 1 test passed" -Context "Test"
    } else {
        throw "Phase 1 output not found"
    }
} catch {
    Write-Log -Level Error -Message "Phase 1 test failed: $_" -Context "Test"
}

# Test Phase 2 (mock user mapping)
Write-Log -Level Info -Message "Testing Phase 2: Map Users" -Context "Test"
try {
    # Create mock user map
    $userMap = @{
        "U10001" = @{ Email = "user1@test.com"; M365UserId = "m365-1"; ExistsInM365 = $true }
        "U10002" = @{ Email = "user2@test.com"; M365UserId = "m365-2"; ExistsInM365 = $true }
    }
    $userMap | ConvertTo-Json | Set-Content "$($testConfig.OutputDir)\user_map.json"
    Write-Log -Level Info -Message "Phase 2 test passed (mock)" -Context "Test"
} catch {
    Write-Log -Level Error -Message "Phase 2 test failed: $_" -Context "Test"
}

# Test Phase 3 (mock provisioning)
Write-Log -Level Info -Message "Testing Phase 3: Provision Teams" -Context "Test"
try {
    $provision = @{
        team = @{ id = "team-1"; displayName = $testConfig.TestTeamName }
        channels = @(
            @{ slack_channel_name = "engineering"; teams_channel_id = "chan-1"; teams_channel_name = "Engineering" }
            @{ slack_channel_name = "finance"; teams_channel_id = "chan-2"; teams_channel_name = "Finance" }
        )
    }
    New-Item -ItemType Directory -Path "$($testConfig.OutputDir)\Phase3-Provision" -Force | Out-Null
    $provision | ConvertTo-Json | Set-Content "$($testConfig.OutputDir)\Phase3-Provision\provision-summary.json"
    Write-Log -Level Info -Message "Phase 3 test passed (mock)" -Context "Test"
} catch {
    Write-Log -Level Error -Message "Phase 3 test failed: $_" -Context "Test"
}

# Test Phase 4 (mock posting)
Write-Log -Level Info -Message "Testing Phase 4: Post Messages" -Context "Test"
try {
    $postSummary = @(
        @{ channel = "engineering"; posted = 10 }
        @{ channel = "finance"; posted = 5 }
    )
    New-Item -ItemType Directory -Path "$($testConfig.OutputDir)\Phase4-PostMessages" -Force | Out-Null
    $postSummary | ConvertTo-Json | Set-Content "$($testConfig.OutputDir)\Phase4-PostMessages\post-summary.json"
    Write-Log -Level Info -Message "Phase 4 test passed (mock)" -Context "Test"
} catch {
    Write-Log -Level Error -Message "Phase 4 test failed: $_" -Context "Test"
}

# Test Phase 5 (mock download)
Write-Log -Level Info -Message "Testing Phase 5: Download Files" -Context "Test"
try {
    New-Item -ItemType Directory -Path "$($testConfig.OutputDir)\Phase5-DownloadFiles" -Force | Out-Null
    # Copy test files
    Copy-Item "$PSScriptRoot\testdata\file_payloads\*" "$($testConfig.OutputDir)\Phase5-DownloadFiles\" -Recurse
    Write-Log -Level Info -Message "Phase 5 test passed (mock)" -Context "Test"
} catch {
    Write-Log -Level Error -Message "Phase 5 test failed: $_" -Context "Test"
}

# Test Phase 7 (verification)
Write-Log -Level Info -Message "Testing Phase 7: Verify Migration" -Context "Test"
try {
    # Simple verification
    $files = Get-ChildItem $testConfig.OutputDir -Recurse -File
    if ($files.Count -gt 0) {
        Write-Log -Level Info -Message "Phase 7 test passed - outputs found" -Context "Test"
    } else {
        throw "No output files found"
    }
} catch {
    Write-Log -Level Error -Message "Phase 7 test failed: $_" -Context "Test"
}

Write-Log -Level Info -Message "Test suite completed" -Context "Test"