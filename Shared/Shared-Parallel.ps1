# Shared-Parallel.ps1 - Parallel processing utilities

function Invoke-ParallelProcessing {
    param(
        [Parameter(Mandatory)]
        [array]$Items,
        [Parameter(Mandatory)]
        [scriptblock]$ProcessScript,
        [int]$MaxThreads = 4,
        [switch]$UseRunspacePool
    )

    if ($UseRunspacePool) {
        # Advanced runspace pool implementation
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
        $runspacePool.Open()

        $jobs = @()
        foreach ($item in $Items) {
            $job = [powershell]::Create().AddScript($ProcessScript).AddArgument($item)
            $job.RunspacePool = $runspacePool
            $jobs += @{
                Job = $job
                Handle = $job.BeginInvoke()
                Item = $item
            }
        }

        # Wait for all jobs to complete
        $results = @()
        foreach ($job in $jobs) {
            $result = $job.Job.EndInvoke($job.Handle)
            $results += $result
            $job.Job.Dispose()
        }

        $runspacePool.Close()
        $runspacePool.Dispose()

        return $results
    } else {
        # Simple ForEach-Object parallel implementation
        $Items | ForEach-Object -Parallel $ProcessScript -ThrottleLimit $MaxThreads
    }
}

function Start-ChannelParallelProcessing {
    param(
        [Parameter(Mandatory)]
        [array]$Channels,
        [Parameter(Mandatory)]
        [scriptblock]$ChannelScript,
        [int]$MaxConcurrentChannels = 3
    )

    Write-Log -Level Info -Message "Starting parallel processing of $($Channels.Count) channels with max $MaxConcurrentChannels concurrent" -Context "Parallel"

    $channelJobs = @()

    foreach ($channel in $Channels) {
        $channelJobs += @{
            Channel = $channel
            Script = $ChannelScript
        }
    }

    # Process channels in batches
    for ($i = 0; $i -lt $channelJobs.Count; $i += $MaxConcurrentChannels) {
        $batch = $channelJobs[$i..([math]::Min($i + $MaxConcurrentChannels - 1, $channelJobs.Count - 1))]

        Write-Log -Level Info -Message "Processing batch of $($batch.Count) channels" -Context "Parallel"

        $batch | ForEach-Object -Parallel {
            param($job)
            try {
                Write-Log -Level Info -Message "Processing channel: $($job.Channel.Name)" -Context "Parallel"
                & $job.Script $job.Channel
                Write-Log -Level Info -Message "Completed channel: $($job.Channel.Name)" -Context "Parallel"
            } catch {
                Write-Log -Level Error -Message "Failed to process channel $($job.Channel.Name): $_" -Context "Parallel"
            }
        } -ThrottleLimit $MaxConcurrentChannels

        # Small delay between batches to prevent overwhelming the API
        Start-Sleep -Milliseconds 500
    }

    Write-Log -Level Info -Message "Parallel channel processing completed" -Context "Parallel"
}

function Start-FileParallelProcessing {
    param(
        [Parameter(Mandatory)]
        [array]$Files,
        [Parameter(Mandatory)]
        [scriptblock]$FileScript,
        [int]$MaxConcurrentFiles = 5
    )

    Write-Log -Level Info -Message "Starting parallel processing of $($Files.Count) files with max $MaxConcurrentFiles concurrent" -Context "Parallel"

    $fileJobs = @()

    foreach ($file in $Files) {
        $fileJobs += @{
            File = $file
            Script = $FileScript
        }
    }

    # Process files in batches
    for ($i = 0; $i -lt $fileJobs.Count; $i += $MaxConcurrentFiles) {
        $batch = $fileJobs[$i..([math]::Min($i + $MaxConcurrentFiles - 1, $fileJobs.Count - 1))]

        Write-Log -Level Info -Message "Processing batch of $($batch.Count) files" -Context "Parallel"

        $batch | ForEach-Object -Parallel {
            param($job)
            try {
                Write-Log -Level Info -Message "Processing file: $($job.File.Name)" -Context "Parallel"
                & $job.Script $job.File
                Write-Log -Level Info -Message "Completed file: $($job.File.Name)" -Context "Parallel"
            } catch {
                Write-Log -Level Error -Message "Failed to process file $($job.File.Name): $_" -Context "Parallel"
            }
        } -ThrottleLimit $MaxConcurrentFiles

        # Small delay between batches
        Start-Sleep -Milliseconds 200
    }

    Write-Log -Level Info -Message "Parallel file processing completed" -Context "Parallel"
}

function Test-ParallelProcessingSupport {
    # Check if ForEach-Object -Parallel is available (PowerShell 7+)
    $parallelSupported = $PSVersionTable.PSVersion.Major -ge 7

    if (-not $parallelSupported) {
        Write-Log -Level Warn -Message "Parallel processing requires PowerShell 7+. Falling back to sequential processing." -Context "Parallel"
    }

    return $parallelSupported
}

# Export functions
Export-ModuleMember -Function Invoke-ParallelProcessing, Start-ChannelParallelProcessing, Start-FileParallelProcessing, Test-ParallelProcessingSupport