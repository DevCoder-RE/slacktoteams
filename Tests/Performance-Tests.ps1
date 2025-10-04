# Performance and Load Testing

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"

function Measure-PhasePerformance {
    param(
        [string]$PhaseScript,
        [hashtable]$Parameters = @{},
        [int]$Iterations = 3
    )

    Write-Log -Level Info -Message "Starting performance test for $PhaseScript" -Context "PerfTest"

    $results = @()
    for ($i = 1; $i -le $Iterations; $i++) {
        Write-Log -Level Info -Message "Iteration $i of $Iterations" -Context "PerfTest"

        $startTime = Get-Date
        try {
            & $PhaseScript @Parameters
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds

            $results += @{
                Iteration = $i
                Duration = $duration
                Success = $true
                Error = $null
            }

            Write-Log -Level Info -Message "Iteration $i completed in $duration seconds" -Context "PerfTest"
        } catch {
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds

            $results += @{
                Iteration = $i
                Duration = $duration
                Success = $false
                Error = $_.Exception.Message
            }

            Write-Log -Level Error -Message "Iteration $i failed after $duration seconds: $($_.Exception.Message)" -Context "PerfTest"
        }
    }

    # Calculate statistics
    $successfulRuns = $results | Where-Object { $_.Success }
    $stats = @{
        Phase = $PhaseScript
        TotalIterations = $Iterations
        SuccessfulRuns = $successfulRuns.Count
        FailedRuns = $Iterations - $successfulRuns.Count
        AverageDuration = if ($successfulRuns) { ($successfulRuns | Measure-Object -Property Duration -Average).Average } else { 0 }
        MinDuration = if ($successfulRuns) { ($successfulRuns | Measure-Object -Property Duration -Minimum).Minimum } else { 0 }
        MaxDuration = if ($successfulRuns) { ($successfulRuns | Measure-Object -Property Duration -Maximum).Maximum } else { 0 }
        Results = $results
    }

    return $stats
}

function Test-JsonParsingPerformance {
    param([string]$TestDataPath = "$PSScriptRoot\testdata\slack_export")

    Write-Log -Level Info -Message "Testing JSON parsing performance" -Context "PerfTest"

    $jsonFiles = Get-ChildItem $TestDataPath -Filter "*.json" -Recurse
    $totalSize = ($jsonFiles | Measure-Object -Property Length -Sum).Sum / 1MB

    Write-Log -Level Info -Message "Found $($jsonFiles.Count) JSON files, total size: $([math]::Round($totalSize, 2)) MB" -Context "PerfTest"

    $startTime = Get-Date
    $totalMessages = 0

    foreach ($file in $jsonFiles) {
        try {
            $data = Read-JsonFile -Path $file.FullName
            if ($data -is [array]) {
                $totalMessages += $data.Count
            }
        } catch {
            Write-Log -Level Warn -Message "Failed to parse $($file.Name): $($_.Exception.Message)" -Context "PerfTest"
        }
    }

    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    $messagesPerSecond = $totalMessages / $duration

    $result = @{
        Operation = "JSON Parsing"
        TotalFiles = $jsonFiles.Count
        TotalSizeMB = $totalSize
        TotalMessages = $totalMessages
        Duration = $duration
        MessagesPerSecond = $messagesPerSecond
        MBPerSecond = $totalSize / $duration
    }

    Write-Log -Level Info -Message "JSON parsing: $totalMessages messages in $duration seconds ($([math]::Round($messagesPerSecond, 0)) msg/sec)" -Context "PerfTest"

    return $result
}

function Test-MemoryUsage {
    param([scriptblock]$TestScript)

    $initialMemory = [System.GC]::GetTotalMemory($true) / 1MB

    & $TestScript

    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    $finalMemory = [System.GC]::GetTotalMemory($true) / 1MB
    $memoryDelta = $finalMemory - $initialMemory

    return @{
        InitialMemoryMB = [math]::Round($initialMemory, 2)
        FinalMemoryMB = [math]::Round($finalMemory, 2)
        MemoryDeltaMB = [math]::Round($memoryDelta, 2)
    }
}

function Run-PerformanceTestSuite {
    Write-Log -Level Info -Message "Starting comprehensive performance test suite" -Context "PerfTest"

    $results = @{}

    # Test JSON parsing performance
    $results.JsonParsing = Test-JsonParsingPerformance

    # Test Phase 1 performance
    $results.Phase1 = Measure-PhasePerformance -PhaseScript "$PSScriptRoot\..\Phases\Phase1-ParseSlack.ps1" -Parameters @{ Mode = "Offline"; DryRun = $true }

    # Test memory usage
    $results.MemoryUsage = Test-MemoryUsage -TestScript {
        & "$PSScriptRoot\..\Phases\Phase1-ParseSlack.ps1" -Mode Offline -DryRun
    }

    # Save results
    $outputPath = "$PSScriptRoot\..\Output\Performance-Results.json"
    $results | ConvertTo-Json -Depth 10 | Set-Content $outputPath

    Write-Log -Level Info -Message "Performance test suite completed. Results saved to $outputPath" -Context "PerfTest"

    return $results
}

# Run the tests if this script is executed directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Run-PerformanceTestSuite
}