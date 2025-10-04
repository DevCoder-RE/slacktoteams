# CI/CD Build Script

param(
    [switch]$RunTests,
    [switch]$RunLint,
    [switch]$RunSecurityScan,
    [switch]$RunPerformanceTests,
    [switch]$RunDataAccuracyTests
)

. "$PSScriptRoot\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\Shared\Shared-Config.ps1"

function Install-Dependencies {
    Write-Log -Level Info -Message "Installing dependencies" -Context "Build"

    # Install Pester if not present
    if (-not (Get-Module -Name Pester -ListAvailable)) {
        Install-Module -Name Pester -Force -Scope CurrentUser
    }

    # Install PSScriptAnalyzer for linting
    if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    }
}

function Run-PesterTests {
    Write-Log -Level Info -Message "Running Pester unit tests" -Context "Build"

    $testResults = Invoke-Pester -Path "$PSScriptRoot\Tests\*.Tests.ps1" -PassThru -OutputFormat NUnitXml -OutputFile "$PSScriptRoot\Output\TestResults.xml"

    if ($testResults.FailedCount -gt 0) {
        Write-Log -Level Error -Message "Tests failed: $($testResults.FailedCount) failed out of $($testResults.TotalCount)" -Context "Build"
        throw "Test failures detected"
    }

    Write-Log -Level Info -Message "All tests passed: $($testResults.PassedCount) passed" -Context "Build"
}

function Run-Linting {
    Write-Log -Level Info -Message "Running code quality checks" -Context "Build"

    $results = Invoke-ScriptAnalyzer -Path "$PSScriptRoot\Shared" -Recurse -Severity Warning,Error

    if ($results) {
        foreach ($result in $results) {
            Write-Log -Level Warn -Message "$($result.RuleName): $($result.Message) in $($result.ScriptPath):$($result.Line)" -Context "Build"
        }
        throw "Code quality issues found"
    }

    Write-Log -Level Info -Message "Code quality checks passed" -Context "Build"
}

function Run-SecurityScan {
    Write-Log -Level Info -Message "Running security scan" -Context "Build"

    # Check for hardcoded secrets
    $secretPatterns = @(
        'password\s*=',
        'secret\s*=',
        'key\s*=',
        'token\s*='
    )

    $files = Get-ChildItem -Path "$PSScriptRoot\Shared" -Filter "*.ps1" -Recurse
    $issues = @()

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern) {
                $issues += @{
                    File = $file.FullName
                    Pattern = $pattern
                }
            }
        }
    }

    if ($issues) {
        foreach ($issue in $issues) {
            Write-Log -Level Error -Message "Potential security issue: $($issue.Pattern) found in $($issue.File)" -Context "Build"
        }
        throw "Security scan failed"
    }

    Write-Log -Level Info -Message "Security scan passed" -Context "Build"
}

function Run-PerformanceTests {
    Write-Log -Level Info -Message "Running performance tests" -Context "Build"

    & "$PSScriptRoot\Tests\Performance-Tests.ps1"

    Write-Log -Level Info -Message "Performance tests completed" -Context "Build"
}

function Run-DataAccuracyTests {
    Write-Log -Level Info -Message "Running data accuracy tests" -Context "Build"

    & "$PSScriptRoot\Tests\Data-Accuracy-Tests.ps1"

    Write-Log -Level Info -Message "Data accuracy tests completed" -Context "Build"
}

# Main build process
try {
    Write-Log -Level Info -Message "Starting build process" -Context "Build"

    Install-Dependencies

    if ($RunLint) {
        Run-Linting
    }

    if ($RunSecurityScan) {
        Run-SecurityScan
    }

    if ($RunTests) {
        Run-PesterTests
    }

    if ($RunPerformanceTests) {
        Run-PerformanceTests
    }

    if ($RunDataAccuracyTests) {
        Run-DataAccuracyTests
    }

    Write-Log -Level Info -Message "Build completed successfully" -Context "Build"

} catch {
    Write-Log -Level Error -Message "Build failed: $($_.Exception.Message)" -Context "Build"
    throw
}