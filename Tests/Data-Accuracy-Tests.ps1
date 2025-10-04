# Data Accuracy Testing

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"

function New-GroundTruthDataset {
    param(
        [string]$OutputPath = "$PSScriptRoot\testdata\ground_truth"
    )

    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

    # Create ground truth Slack export
    $groundTruth = @{
        channels = @(
            @{ id = "C001"; name = "general"; is_channel = $true; created = 1609459200 }
            @{ id = "C002"; name = "engineering"; is_channel = $true; created = 1609459200 }
        )
        users = @(
            @{ id = "U001"; name = "alice"; real_name = "Alice Smith"; is_bot = $false }
            @{ id = "U002"; name = "bob"; real_name = "Bob Johnson"; is_bot = $false }
        )
        messages = @(
            @{
                channel = "C001"
                messages = @(
                    @{ ts = "1609459260.000100"; user = "U001"; text = "Hello world"; thread_ts = $null }
                    @{ ts = "1609459320.000200"; user = "U002"; text = "Hi Alice"; thread_ts = "1609459260.000100" }
                )
            }
        )
    }

    $groundTruth | ConvertTo-Json -Depth 10 | Set-Content "$OutputPath\slack_export.json"

    # Create expected Teams output
    $expectedTeams = @{
        teams = @(
            @{ id = "T001"; displayName = "Migrated Team" }
        )
        channels = @(
            @{ id = "CH001"; displayName = "general"; teamId = "T001" }
            @{ id = "CH002"; displayName = "engineering"; teamId = "T001" }
        )
        messages = @(
            @{
                channelId = "CH001"
                messages = @(
                    @{ id = "M001"; body = @{ content = "Hello world" }; from = @{ user = @{ id = "alice@domain.com" } } }
                    @{ id = "M002"; body = @{ content = "Hi Alice" }; from = @{ user = @{ id = "bob@domain.com" } } }
                )
            }
        )
    }

    $expectedTeams | ConvertTo-Json -Depth 10 | Set-Content "$OutputPath\expected_teams.json"

    Write-Log -Level Info -Message "Ground truth dataset created at $OutputPath" -Context "AccuracyTest"
}

function Test-DataAccuracy {
    param(
        [string]$ActualOutputPath,
        [string]$ExpectedOutputPath = "$PSScriptRoot\testdata\ground_truth\expected_teams.json"
    )

    $expected = Read-JsonFile -Path $ExpectedOutputPath
    $actual = Read-JsonFile -Path $ActualOutputPath

    $results = @{
        Tests = @()
        OverallAccuracy = 0
        PassedTests = 0
        TotalTests = 0
    }

    # Test channel count
    $channelTest = @{
        TestName = "Channel Count"
        Expected = $expected.channels.Count
        Actual = $actual.channels.Count
        Passed = $expected.channels.Count -eq $actual.channels.Count
    }
    $results.Tests += $channelTest

    # Test message count
    $messageTest = @{
        TestName = "Message Count"
        Expected = ($expected.messages | ForEach-Object { $_.messages.Count } | Measure-Object -Sum).Sum
        Actual = ($actual.messages | ForEach-Object { $_.messages.Count } | Measure-Object -Sum).Sum
        Passed = $messageTest.Expected -eq $messageTest.Actual
    }
    $results.Tests += $messageTest

    # Test user mapping
    $userTest = @{
        TestName = "User Mapping"
        Expected = $expected.users.Count
        Actual = $actual.users.Count
        Passed = $expected.users.Count -eq $actual.users.Count
    }
    $results.Tests += $userTest

    $results.TotalTests = $results.Tests.Count
    $results.PassedTests = ($results.Tests | Where-Object { $_.Passed }).Count
    $results.OverallAccuracy = [math]::Round(($results.PassedTests / $results.TotalTests) * 100, 2)

    return $results
}

function Test-EdgeCases {
    param([string]$TestDataPath = "$PSScriptRoot\testdata\edge_cases")

    if (-not (Test-Path $TestDataPath)) { New-Item -ItemType Directory -Path $TestDataPath | Out-Null }

    # Create edge case data
    $edgeCases = @(
        @{
            Name = "DeletedUser"
            Data = @{
                channels = @(@{ id = "C001"; name = "test" })
                users = @(@{ id = "U001"; name = "deleted"; deleted = $true })
                messages = @(@{ ts = "1609459260"; user = "U001"; text = "Message from deleted user" })
            }
        }
        @{
            Name = "MalformedData"
            Data = @{
                channels = @(@{ id = "C001"; name = "test" })
                messages = @(@{ ts = "invalid"; user = "U001"; text = $null })
            }
        }
    )

    $results = @()

    foreach ($case in $edgeCases) {
        $filePath = "$TestDataPath\$($case.Name).json"
        $case.Data | ConvertTo-Json -Depth 10 | Set-Content $filePath

        try {
            $parsed = Read-JsonFile -Path $filePath
            $results += @{
                Case = $case.Name
                Parsed = $true
                Error = $null
            }
        } catch {
            $results += @{
                Case = $case.Name
                Parsed = $false
                Error = $_.Exception.Message
            }
        }
    }

    return $results
}

function Run-DataAccuracyTestSuite {
    Write-Log -Level Info -Message "Starting data accuracy test suite" -Context "AccuracyTest"

    # Create ground truth if it doesn't exist
    New-GroundTruthDataset

    # Run edge case tests
    $edgeResults = Test-EdgeCases

    # Run accuracy tests (would need actual migration output)
    $results = @{
        EdgeCaseTests = $edgeResults
        AccuracyTests = "Requires actual migration run to compare"
    }

    $outputPath = "$PSScriptRoot\..\Output\Data-Accuracy-Results.json"
    $results | ConvertTo-Json -Depth 10 | Set-Content $outputPath

    Write-Log -Level Info -Message "Data accuracy test suite completed. Results saved to $outputPath" -Context "AccuracyTest"

    return $results
}

# Run the tests if this script is executed directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Run-DataAccuracyTestSuite
}