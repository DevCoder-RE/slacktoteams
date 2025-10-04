#Requires -Version 5.1
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
Set-Location $projectRoot

. .\Shared\Shared-Monitoring.ps1

Describe "Shared-Monitoring" {
    BeforeEach {
        # Reset global metrics
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
    }

    It "Initializes monitoring correctly" {
        Initialize-Monitoring
        $Global:Metrics.StartTime | Should -Not -BeNullOrEmpty
        $Global:Metrics.EndTime | Should -BeNullOrEmpty
    }

    It "Updates phase progress correctly" {
        Update-PhaseProgress -PhaseName "TestPhase" -Progress 50 -TotalItems 100 -ProcessedItems 50
        $Global:Metrics.CurrentPhase | Should -Be "TestPhase"
        $Global:Metrics.Progress | Should -Be 50
        $Global:Metrics.TotalItems | Should -Be 100
        $Global:Metrics.ProcessedItems | Should -Be 50
        $Global:Metrics.Phases["TestPhase"] | Should -Not -BeNullOrEmpty
    }

    It "Completes phase correctly" {
        Update-PhaseProgress -PhaseName "TestPhase" -Progress 0
        Start-Sleep -Milliseconds 100
        Complete-Phase -PhaseName "TestPhase"
        $Global:Metrics.Phases["TestPhase"].EndTime | Should -Not -BeNullOrEmpty
        $Global:Metrics.ProcessingTimes["TestPhase"] | Should -Not -BeNullOrEmpty
    }

    It "Records API calls correctly" {
        Record-ApiCall -Api "Slack" -Success $true
        Record-ApiCall -Api "Graph" -Success $false
        $Global:Metrics.ApiCalls.Slack | Should -Be 1
        $Global:Metrics.ApiCalls.Graph | Should -Be 1
        $Global:Metrics.ApiCalls.Total | Should -Be 2
        $Global:Metrics.SuccessRates["Slack"].Success | Should -Be 1
        $Global:Metrics.SuccessRates["Graph"].Total | Should -Be 1
        $Global:Metrics.SuccessRates["Graph"].Success | Should -Be 0
    }

    It "Records errors and warnings correctly" {
        Record-Error
        Record-Warning
        $Global:Metrics.Errors | Should -Be 1
        $Global:Metrics.Warnings | Should -Be 1
    }

    It "Generates metrics summary correctly" {
        Initialize-Monitoring
        Update-PhaseProgress -PhaseName "TestPhase" -Progress 100
        Record-ApiCall -Api "Slack"
        Record-Error
        $summary = Get-MetricsSummary
        $summary.TotalApiCalls | Should -Be 1
        $summary.Errors | Should -Be 1
        $summary.CurrentPhase | Should -Be "TestPhase"
        $summary.Progress | Should -Be 100
    }
}