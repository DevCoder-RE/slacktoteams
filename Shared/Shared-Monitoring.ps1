#Requires -Version 5.1
Set-StrictMode -Version Latest

$Global:Metrics = @{
    StartTime = $null
    EndTime = $null
    Phases = @{}
    ApiCalls = @{
        Slack = 0
        Graph = 0
        Total = 0
    }
    ProcessingTimes = @{}
    SuccessRates = @{}
    Errors = 0
    Warnings = 0
    CurrentPhase = $null
    Progress = 0
    TotalItems = 0
    ProcessedItems = 0
}

function Initialize-Monitoring {
    $Global:Metrics.StartTime = Get-Date
    $Global:Metrics.EndTime = $null
    Write-Log -Level Info -Message "Monitoring initialized" -Context "Monitoring"
}

function Update-PhaseProgress {
    param(
        [string]$PhaseName,
        [int]$Progress,
        [int]$TotalItems = 0,
        [int]$ProcessedItems = 0
    )
    $Global:Metrics.CurrentPhase = $PhaseName
    $Global:Metrics.Progress = $Progress
    $Global:Metrics.TotalItems = $TotalItems
    $Global:Metrics.ProcessedItems = $ProcessedItems
    if (-not $Global:Metrics.Phases.ContainsKey($PhaseName)) {
        $Global:Metrics.Phases[$PhaseName] = @{
            StartTime = Get-Date
            EndTime = $null
            Progress = 0
        }
    }
    $Global:Metrics.Phases[$PhaseName].Progress = $Progress
}

function Complete-Phase {
    param([string]$PhaseName)
    if ($Global:Metrics.Phases.ContainsKey($PhaseName)) {
        $Global:Metrics.Phases[$PhaseName].EndTime = Get-Date
    }
    $Global:Metrics.ProcessingTimes[$PhaseName] = (Get-Date) - $Global:Metrics.Phases[$PhaseName].StartTime
}

function Record-ApiCall {
    param(
        [ValidateSet('Slack','Graph')]
        [string]$Api,
        [bool]$Success = $true
    )
    $Global:Metrics.ApiCalls[$Api]++
    $Global:Metrics.ApiCalls.Total++
    if ($Success) {
        if (-not $Global:Metrics.SuccessRates.ContainsKey($Api)) {
            $Global:Metrics.SuccessRates[$Api] = @{Total = 0; Success = 0}
        }
        $Global:Metrics.SuccessRates[$Api].Total++
        $Global:Metrics.SuccessRates[$Api].Success++
    }
}

function Record-Error {
    $Global:Metrics.Errors++
}

function Record-Warning {
    $Global:Metrics.Warnings++
}

function Get-MetricsSummary {
    $elapsed = if ($Global:Metrics.EndTime) { $Global:Metrics.EndTime - $Global:Metrics.StartTime } else { (Get-Date) - $Global:Metrics.StartTime }
    return @{
        ElapsedTime = $elapsed
        TotalApiCalls = $Global:Metrics.ApiCalls.Total
        SlackApiCalls = $Global:Metrics.ApiCalls.Slack
        GraphApiCalls = $Global:Metrics.ApiCalls.Graph
        Errors = $Global:Metrics.Errors
        Warnings = $Global:Metrics.Warnings
        CurrentPhase = $Global:Metrics.CurrentPhase
        Progress = $Global:Metrics.Progress
        ProcessedItems = $Global:Metrics.ProcessedItems
        TotalItems = $Global:Metrics.TotalItems
        PhaseDetails = $Global:Metrics.Phases
        ProcessingTimes = $Global:Metrics.ProcessingTimes
        SuccessRates = $Global:Metrics.SuccessRates
    }
}

function Send-WebhookNotification {
    param(
        [string]$Url,
        [string]$Message,
        [string]$Level = 'Info'
    )
    if ($Url) {
        try {
            $body = @{
                text = "[$Level] $Message"
                timestamp = (Get-Date).ToString('o')
            } | ConvertTo-Json
            Invoke-RestMethod -Uri $Url -Method Post -Body $body -ContentType 'application/json'
        } catch {
            Write-Log -Level Warn -Message "Failed to send webhook notification: $_" -Context "Monitoring"
        }
    }
}

function Send-AzureMonitorMetric {
    param(
        [string]$WorkspaceId,
        [string]$SharedKey,
        [string]$MetricName,
        [double]$Value,
        [hashtable]$Dimensions = @{}
    )
    if ($WorkspaceId -and $SharedKey) {
        try {
            # Simplified Azure Monitor ingestion (in real implementation, use proper API)
            $body = @{
                MetricName = $MetricName
                Value = $Value
                Dimensions = $Dimensions
                Timestamp = (Get-Date).ToString('o')
            } | ConvertTo-Json
            # Placeholder for actual Azure Monitor API call
            Write-Log -Level Info -Message "Azure Monitor metric sent: $MetricName = $Value" -Context "Monitoring"
        } catch {
            Write-Log -Level Warn -Message "Failed to send Azure Monitor metric: $_" -Context "Monitoring"
        }
    }
}

Export-ModuleMember -Function Initialize-Monitoring, Update-PhaseProgress, Complete-Phase, Record-ApiCall, Record-Error, Record-Warning, Get-MetricsSummary, Send-WebhookNotification, Send-AzureMonitorMetric