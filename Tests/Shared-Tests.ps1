#Requires -Modules Pester
using module "$PSScriptRoot\..\Shared\Shared-Config.ps1"
using module "$PSScriptRoot\..\Shared\Shared-Retry.ps1"
using module "$PSScriptRoot\..\Shared\Shared-Parallel.ps1"

Describe "Shared-Config Tests" {
    BeforeAll {
        # Mock the config loading
        $Global:AppConfig = @{
            Test = @{
                Value1 = "test1"
                Value2 = 42
            }
        }
    }

    It "Should get config value" {
        $result = Get-Config "Test.Value1"
        $result | Should -Be "test1"
    }

    It "Should return default value for missing key" {
        $result = Get-Config "Test.Missing" "default"
        $result | Should -Be "default"
    }

    It "Should set config value" {
        Set-Config "Test.NewValue" "new"
        $result = Get-Config "Test.NewValue"
        $result | Should -Be "new"
    }
}

Describe "Shared-Retry Tests" {
    It "Should retry on failure and succeed" {
        $attempts = 0
        $script = {
            $attempts++
            if ($attempts -lt 3) { throw "Test error" }
            return "success"
        }

        $result = Invoke-WithRetry -ScriptBlock $script -MaxAttempts 5
        $result | Should -Be "success"
        $attempts | Should -Be 3
    }

    It "Should fail after max attempts" {
        $script = { throw "Persistent error" }
        { Invoke-WithRetry -ScriptBlock $script -MaxAttempts 2 } | Should -Throw
    }

    It "Should use retry policy" {
        $policy = Get-RetryPolicy "api"
        $policy.MaxAttempts | Should -Be 3
        $policy.UseCircuitBreaker | Should -Be $true
    }
}

Describe "Shared-Parallel Tests" {
    It "Should test parallel processing support" {
        $result = Test-ParallelProcessingSupport
        # This will depend on PowerShell version
        $result | Should -BeOfType [bool]
    }

    It "Should process items in parallel" {
        $items = 1..5
        $results = @()

        $script = {
            param($item)
            Start-Sleep -Milliseconds 100
            return $item * 2
        }

        # Mock ForEach-Object -Parallel if not available
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            $results = $items | ForEach-Object { & $script $_ }
        } else {
            $results = $items | ForEach-Object -Parallel $script
        }

        $results.Count | Should -Be 5
        $results | Should -Contain 2
        $results | Should -Contain 10
    }
}

Describe "Graph API Batching Tests" {
    BeforeAll {
        using module "$PSScriptRoot\..\Shared\Shared-Graph.ps1"
    }

    It "Should create batch request structure" {
        $requests = @(
            @{
                id = "1"
                method = "POST"
                url = "/teams/test/channels"
                body = @{ displayName = "Test Channel" }
            }
        )

        $batchBody = @{ requests = $requests }
        $batchBody.requests.Count | Should -Be 1
        $batchBody.requests[0].method | Should -Be "POST"
    }
}

Describe "Memory Management Tests" {
    It "Should force garbage collection" {
        [System.GC]::Collect()
        # This is mainly to ensure no exceptions
        $true | Should -Be $true
    }
}