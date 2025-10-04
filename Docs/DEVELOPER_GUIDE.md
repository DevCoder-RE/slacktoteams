# Developer Extension Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Adding Custom Phases](#adding-custom-phases)
4. [Creating Custom Modules](#creating-custom-modules)
5. [Configuration Extensions](#configuration-extensions)
6. [Testing Extensions](#testing-extensions)
7. [Best Practices](#best-practices)

## Introduction

The Slack to Teams Migration Tool is designed to be extensible, allowing developers to add custom phases, modules, and configurations to meet specific migration requirements. This guide provides comprehensive instructions for extending the tool.

## Architecture Overview

### Core Components
- **Run-All.ps1**: Main orchestration script
- **Phases/**: Individual migration phases (Phase1-Phase11)
- **Shared/**: Reusable modules (Config, Logging, Graph, Slack, etc.)
- **Config/**: Configuration files and mappings
- **Tests/**: Test suites and validation scripts

### Extension Points
- Custom phases for specialized processing
- Shared modules for common functionality
- Configuration extensions for new settings
- Custom filters and transformations

## Adding Custom Phases

### Phase Structure
Each phase follows a consistent pattern:

```powershell
#Requires -Version 5.1
Set-StrictMode -Version Latest

# Import shared modules
. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
# ... other imports

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Offline','Live')]
    [string]$Mode,

    [switch]$DryRun,
    [string[]]$ChannelFilter,
    [string[]]$UserFilter
)

# Phase implementation
function Invoke-PhaseX {
    param([string]$Mode, [switch]$DryRun)

    Write-Log -Level Info -Message "Starting Phase X" -Context "PhaseX"

    try {
        # Phase logic here

        Write-Log -Level Info -Message "Phase X completed successfully" -Context "PhaseX"
    } catch {
        Write-Log -Level Error -Message "Phase X failed: $($_.Exception.Message)" -Context "PhaseX"
        throw
    }
}

# Main execution
if ($PSCmdlet.ParameterSetName -eq '__AllParameterSets' -or $true) {
    Invoke-PhaseX -Mode $Mode -DryRun:$DryRun
}
```

### Phase Naming Convention
- Use `Phase{Number}-{DescriptiveName}.ps1`
- Number should be unique (after existing phases)
- Descriptive name should be camelCase

### Integration with Run-All.ps1
1. Add phase file to `Phases/` directory
2. Update `Run-All.ps1` to include the new phase in the execution sequence
3. Add phase parameters to the main parameter set if needed

### Example: Custom Validation Phase

```powershell
# Phase12-CustomValidation.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Offline','Live')]
    [string]$Mode,

    [switch]$DryRun
)

function Invoke-CustomValidation {
    param([string]$Mode, [switch]$DryRun)

    Write-Log -Level Info -Message "Running custom validation checks" -Context "CustomValidation"

    # Custom validation logic
    $validationResults = @()

    # Example: Check for required channels
    $requiredChannels = @("general", "announcements")
    $teamsChannels = Get-Content "Output/Phase3-ProvisionTeams/channels.json" | ConvertFrom-Json

    foreach ($channel in $requiredChannels) {
        if ($channel -notin $teamsChannels.name) {
            $validationResults += "Missing required channel: $channel"
        }
    }

    # Write validation report
    $validationResults | Out-File "Output/Phase12-CustomValidation/validation-report.txt"

    if ($validationResults.Count -gt 0) {
        Write-Log -Level Warn -Message "Validation found $($validationResults.Count) issues" -Context "CustomValidation"
    } else {
        Write-Log -Level Info -Message "All custom validations passed" -Context "CustomValidation"
    }
}

Invoke-CustomValidation -Mode $Mode -DryRun:$DryRun
```

## Creating Custom Modules

### Module Structure
Custom modules should be placed in the `Shared/` directory and follow the naming convention `Shared-{ModuleName}.ps1`.

```powershell
#Requires -Version 5.1
Set-StrictMode -Version Latest

# Import dependencies
. "$PSScriptRoot\Shared-Logging.ps1"
. "$PSScriptRoot\Shared-Config.ps1"

# Module functions
function New-CustomFunction {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Parameter1,

        [int]$Parameter2 = 10
    )

    Write-Log -Level Info -Message "Executing custom function" -Context "CustomModule"

    # Function implementation
    return "Result"
}

# Export functions
Export-ModuleMember -Function New-CustomFunction
```

### Best Practices for Modules
- Use consistent error handling with try/catch
- Log important operations
- Validate parameters
- Return structured data (hashtables, custom objects)
- Document functions with comment-based help

### Example: Custom Reporting Module

```powershell
# Shared-CustomReporting.ps1
. "$PSScriptRoot\Shared-Logging.ps1"
. "$PSScriptRoot\Shared-Json.ps1"

function New-MigrationReport {
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [hashtable]$Metrics
    )

    $report = @{
        GeneratedAt = (Get-Date).ToString('o')
        Metrics = $Metrics
        Summary = @{
            TotalChannels = $Metrics.ChannelsProcessed
            TotalMessages = $Metrics.MessagesProcessed
            TotalFiles = $Metrics.FilesProcessed
            Duration = $Metrics.Duration
        }
    }

    Write-JsonFile -Path $OutputPath -Object $report
    Write-Log -Level Info -Message "Migration report generated: $OutputPath" -Context "CustomReporting"
}

function Send-EmailReport {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ReportPath,

        [Parameter(Mandatory=$true)]
        [string]$Recipient,

        [string]$Subject = "Slack to Teams Migration Report"
    )

    $smtpServer = Get-Config 'Email.SmtpServer'
    $from = Get-Config 'Email.From'

    if (-not $smtpServer -or -not $from) {
        Write-Log -Level Warn -Message "Email configuration not found. Skipping email report." -Context "CustomReporting"
        return
    }

    $body = Get-Content $ReportPath -Raw | ConvertFrom-Json | ConvertTo-Html

    Send-MailMessage -From $from -To $Recipient -Subject $Subject -Body $body -BodyAsHtml -SmtpServer $smtpServer

    Write-Log -Level Info -Message "Email report sent to $Recipient" -Context "CustomReporting"
}

Export-ModuleMember -Function New-MigrationReport, Send-EmailReport
```

## Configuration Extensions

### Adding New Configuration Sections
Extend `appsettings.json` with new sections:

```json
{
  "Graph": { ... },
  "Slack": { ... },
  "CustomModule": {
    "Enabled": true,
    "CustomSetting": "value",
    "AdvancedOptions": {
      "Option1": "value1",
      "Option2": 42
    }
  }
}
```

### Environment Variables
Add support for environment variable overrides in `Shared-Config.ps1`:

```powershell
$envMap = @{
    # ... existing mappings
    'CustomModule.Enabled' = $env:CUSTOM_MODULE_ENABLED
    'CustomModule.CustomSetting' = $env:CUSTOM_MODULE_SETTING
}
```

### Configuration Validation
Add validation in your custom modules:

```powershell
function Test-CustomConfiguration {
    $enabled = Get-Config 'CustomModule.Enabled' $false
    if ($enabled) {
        $setting = Get-Config 'CustomModule.CustomSetting'
        if (-not $setting) {
            throw "CustomModule.CustomSetting is required when CustomModule is enabled"
        }
    }
}

# Call validation during module load
Test-CustomConfiguration
```

## Testing Extensions

### Unit Tests
Create test files in the `Tests/` directory:

```powershell
# Test-CustomModule.ps1
. "$PSScriptRoot\..\Shared\Shared-CustomModule.ps1"

function Test-NewCustomFunction {
    $result = New-CustomFunction -Parameter1 "test"
    if ($result -ne "ExpectedResult") {
        throw "Test failed: expected 'ExpectedResult', got '$result'"
    }
    Write-Host "Test-NewCustomFunction: PASSED"
}

# Run tests
Test-NewCustomFunction
```

### Integration Tests
Test phase integration in `Run-All.ps1`:

```powershell
# Add to Run-All.ps1 test execution
if ($TestMode) {
    # ... existing tests
    & "$PSScriptRoot\Tests\Test-CustomModule.ps1"
}
```

### Performance Testing
Use the existing performance testing framework:

```powershell
# In Tests/Performance-Tests.ps1
function Test-CustomFunctionPerformance {
    $testData = # Generate test data

    $result = Measure-Command {
        for ($i = 0; $i -lt 1000; $i++) {
            New-CustomFunction -Parameter1 $testData[$i]
        }
    }

    Write-Host "Custom function performance: $($result.TotalSeconds) seconds for 1000 iterations"
}
```

## Best Practices

### Code Quality
- Use `Set-StrictMode -Version Latest`
- Add parameter validation
- Include error handling
- Write comprehensive logs
- Follow PowerShell naming conventions

### Documentation
- Add comment-based help to all functions
- Document parameters and return values
- Include usage examples
- Update this guide for new extension patterns

### Performance
- Use streaming for large data sets
- Implement parallel processing where appropriate
- Cache expensive operations
- Monitor memory usage

### Security
- Never log sensitive information
- Validate all inputs
- Use secure parameter handling
- Follow principle of least privilege

### Version Control
- Create feature branches for extensions
- Write clear commit messages
- Update version numbers appropriately
- Document breaking changes

### Maintenance
- Keep extensions modular
- Avoid tight coupling between modules
- Test thoroughly before production use
- Monitor for side effects on existing functionality

## Support and Resources

### Getting Help
- Check existing code for patterns
- Review shared modules for utilities
- Run tests to validate changes
- Check logs for debugging information

### Examples
- Review existing phases for structure
- Examine shared modules for best practices
- Check test files for testing patterns

For questions or contributions, please create an issue in the repository.