#Requires -Version 5.1
param(
    [int]$RefreshIntervalSeconds = 5,
    [switch]$Continuous
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptRoot

# Load shared modules
. .\Shared\Shared-Logging.ps1
. .\Shared\Shared-Monitoring.ps1

Initialize-Logging -LogDirectory "$scriptRoot\Logs"

Write-Host "Slack to Teams Migration Dashboard" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

function Show-Dashboard {
    Clear-Host
    Write-Host "Slack to Teams Migration Dashboard" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""

    $metrics = Get-MetricsSummary

    # Overall progress
    Write-Host "Overall Progress:" -ForegroundColor Yellow
    $overallProgress = if ($metrics.TotalItems -gt 0) { [math]::Round(($metrics.ProcessedItems / $metrics.TotalItems) * 100, 2) } else { 0 }
    Write-Host "  Progress: $overallProgress% ($($metrics.ProcessedItems)/$($metrics.TotalItems) items)" -ForegroundColor White
    Write-Host "  Elapsed Time: $($metrics.ElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host "  Current Phase: $($metrics.CurrentPhase)" -ForegroundColor White
    Write-Host ""

    # API Calls
    Write-Host "API Calls:" -ForegroundColor Yellow
    Write-Host "  Total: $($metrics.TotalApiCalls)" -ForegroundColor White
    Write-Host "  Slack: $($metrics.SlackApiCalls)" -ForegroundColor White
    Write-Host "  Graph: $($metrics.GraphApiCalls)" -ForegroundColor White
    Write-Host ""

    # Errors and Warnings
    Write-Host "Issues:" -ForegroundColor Yellow
    Write-Host "  Errors: $($metrics.Errors)" -ForegroundColor Red
    Write-Host "  Warnings: $($metrics.Warnings)" -ForegroundColor Yellow
    Write-Host ""

    # Phase Details
    Write-Host "Phase Details:" -ForegroundColor Yellow
    foreach ($phase in $metrics.PhaseDetails.Keys) {
        $phaseInfo = $metrics.PhaseDetails[$phase]
        $status = if ($phaseInfo.EndTime) { "Completed" } elseif ($phase -eq $metrics.CurrentPhase) { "Running" } else { "Pending" }
        $time = if ($phaseInfo.EndTime) { ($phaseInfo.EndTime - $phaseInfo.StartTime).ToString('mm\:ss') } else { "-" }
        Write-Host "  $phase ($status): $($phaseInfo.Progress)% - Time: $time" -ForegroundColor White
    }
    Write-Host ""

    # Success Rates
    Write-Host "Success Rates:" -ForegroundColor Yellow
    foreach ($api in $metrics.SuccessRates.Keys) {
        $rate = $metrics.SuccessRates[$api]
        $percentage = if ($rate.Total -gt 0) { [math]::Round(($rate.Success / $rate.Total) * 100, 2) } else { 0 }
        Write-Host "  $api: $percentage% ($($rate.Success)/$($rate.Total))" -ForegroundColor White
    }
    Write-Host ""

    # ETA Calculation (simplified)
    if ($metrics.Progress -gt 0 -and $metrics.Progress -lt 100) {
        $eta = [TimeSpan]::FromSeconds(($metrics.ElapsedTime.TotalSeconds / $metrics.Progress) * (100 - $metrics.Progress))
        Write-Host "Estimated Time to Completion: $($eta.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    }
}

if ($Continuous) {
    while ($true) {
        Show-Dashboard
        Start-Sleep -Seconds $RefreshIntervalSeconds
    }
} else {
    Show-Dashboard
}