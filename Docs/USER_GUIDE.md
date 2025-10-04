# Slack to Teams Migration Tool - User Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Running Migrations](#running-migrations)
6. [Advanced Scenarios](#advanced-scenarios)
7. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
8. [Best Practices](#best-practices)

## Introduction

The Slack to Teams Migration Tool provides a comprehensive solution for migrating Slack workspaces to Microsoft Teams. This guide covers everything from initial setup to advanced migration scenarios.

### Key Capabilities
- Complete workspace migration (messages, files, users, channels)
- Targeted and incremental migrations
- Enterprise-grade error handling and monitoring
- Multiple execution modes for different operational needs

## Prerequisites

### System Requirements
- Windows PowerShell 5.1 or PowerShell 7+
- Windows 10/11 or Windows Server 2016+
- 4GB RAM minimum (8GB recommended for large migrations)
- 10GB free disk space

### Access Requirements
- **Slack**: Full workspace export OR Slack API token with appropriate scopes
- **Microsoft**: Azure AD app registration with Microsoft Graph permissions
- **Network**: Internet access for API operations

### Permissions Needed
**Slack API Scopes:**
- `channels:history`
- `files:read`
- `users:read`

**Microsoft Graph Permissions:**
- `TeamMember.ReadWrite.All`
- `ChannelMessage.Send`
- `Files.ReadWrite.All`
- `Sites.ReadWrite.All`

## Installation

1. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd slack-to-teams-migration
   ```

2. **Run Setup**
   ```powershell
   .\Setup.ps1
   ```

3. **Verify Installation**
   ```powershell
   .\Tests\Run-Tests.sh
   ```

## Configuration

### 1. Environment Variables
Create `Config\.env`:
```bash
SLACK_TOKEN=xoxb-your-slack-token
GRAPH_CLIENT_ID=your-azure-app-id
GRAPH_CLIENT_SECRET=your-client-secret
GRAPH_TENANT_ID=your-tenant-id
```

### 2. Application Settings
Update `Config\appsettings.json`:
```json
{
  "Graph": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-app-id",
    "ClientSecret": "your-secret"
  },
  "Slack": {
    "Token": "xoxb-your-token",
    "ApiBaseUrl": "https://slack.com/api"
  },
  "Posting": {
    "DefaultTeamName": "Slack Migration",
    "DryRunMaxMessages": 100
  },
  "Email": {
    "SmtpServer": "smtp.company.com",
    "From": "migration@company.com",
    "To": "admin@company.com"
  }
}
```

### 3. User Mapping
Configure `Config\mappings\users.csv`:
```csv
slack_id,email,display_name
U123456,user1@company.com,John Doe
U789012,user2@company.com,Jane Smith
```

### 4. Channel Mapping (Optional)
Configure `Config\mappings\channels.csv`:
```csv
slack_channel_name,channel_name,visibility
general,General,standard
random,Random,standard
private-hr,HR,private
```

## Running Migrations

### Basic Migration
```powershell
# Offline mode (Slack export only)
.\Run-All.ps1 -Mode Offline

# Live mode (with API access)
.\Run-All.ps1 -Mode Live
```

### Targeted Migrations
```powershell
# Specific channels
.\Run-All.ps1 -Mode Live -ChannelFilter "engineering","product"

# Specific users
.\Run-All.ps1 -Mode Live -UserFilter "U123456","U789012"

# Combined filters
.\Run-All.ps1 -Mode Live -ChannelFilter "engineering" -UserFilter "U123456"
```

### Execution Modes
```powershell
# Fully automated
.\Run-All.ps1 -Mode Live -ExecutionMode Auto

# Pause on errors only
.\Run-All.ps1 -Mode Live -ExecutionMode ConfirmOnError

# Confirm each phase
.\Run-All.ps1 -Mode Live -ExecutionMode ConfirmEachPhase
```

### Delta Sync
```powershell
# Skip already processed items
.\Run-All.ps1 -Mode Live -DeltaMode

# Resume with error handling
.\Run-All.ps1 -Mode Live -DeltaMode -ExecutionMode ConfirmOnError
```

### With Notifications
```powershell
# Enable email alerts
.\Run-All.ps1 -Mode Live -EmailNotifications

# Combined with other options
.\Run-All.ps1 -Mode Live -ExecutionMode ConfirmOnError -EmailNotifications -DeltaMode
```

## Advanced Scenarios

### Large Workspace Migration
```powershell
# Phase-by-phase execution for large workspaces
.\Run-All.ps1 -Mode Live -SkipPhases "Phase5-DownloadFiles","Phase6-UploadFiles"
# Then run file phases separately
.\Run-All.ps1 -Mode Live -SkipPhases "Phase1-ParseSlack","Phase2-MapUsers","Phase3-ProvisionTeams","Phase4-PostMessages","Phase7-VerifyMigration","Phase8-RetryAndFixups","Phase9-ArchiveRun"
```

### Test Migration
```powershell
# Dry run with limited messages
.\Run-All.ps1 -Mode Live -DryRun

# Test specific channels
.\Run-All.ps1 -Mode Live -ChannelFilter "test-channel" -DryRun
```

### Custom Filtering
Configure `Config\message-filters.json`:
```json
{
  "excludeSystemMessages": true,
  "excludeMessageTypes": ["bot_message", "channel_join"],
  "dateRange": {
    "from": "2024-01-01",
    "to": "2024-12-31"
  },
  "textFilters": [
    {
      "pattern": "confidential",
      "action": "exclude"
    }
  ]
}
```

## Monitoring and Troubleshooting

### Log Analysis
```powershell
# View recent logs
Get-Content Logs\*.log | Select-Object -Last 20

# Filter errors
Get-Content Logs\*.log | Where-Object { $_ -match "\[ERROR\]" }

# Check phase status
Get-ChildItem Output\ | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) }
```

### Common Issues

#### API Rate Limits
**Symptoms:** HTTP 429 errors in logs
**Solution:** Automatic retry with backoff (no action needed)
**Prevention:** Use `ExecutionMode ConfirmOnError` for manual oversight

#### Permission Errors
**Symptoms:** Authentication or authorization failures
**Solution:**
- Verify Azure AD app permissions
- Check Slack token scopes
- Confirm user has Teams admin rights

#### Large File Failures
**Symptoms:** File upload failures for large files
**Solution:** Files over 2GB are automatically skipped
**Workaround:** Manually upload large files after migration

#### User Mapping Issues
**Symptoms:** Messages appear from "unknown" users
**Solution:**
- Update `Config\mappings\users.csv`
- Run Phase 2 again: `.\Run-All.ps1 -SkipPhases "Phase1-ParseSlack","Phase3-ProvisionTeams","Phase4-PostMessages"`

### Performance Monitoring
```powershell
# Monitor phase progress
Get-Content Logs\run-all.log | Where-Object { $_ -match "Phase.*completed" }

# Check file processing
Get-ChildItem Output\Phase5-DownloadFiles\ -Recurse | Measure-Object

# Validate message counts
Get-Content Output\Phase7-VerifyMigration\validation-report.json | ConvertFrom-Json
```

## Best Practices

### Pre-Migration
1. **Test with Small Dataset**
   ```powershell
   .\Run-All.ps1 -Mode Live -ChannelFilter "test-channel" -DryRun
   ```

2. **Verify Permissions**
   - Test API tokens before full migration
   - Confirm Teams admin access

3. **Backup Data**
   - Keep Slack export as backup
   - Document all configuration settings

### During Migration
1. **Monitor Progress**
   - Use email notifications for unattended runs
   - Check logs regularly for errors

2. **Handle Interruptions**
   - Use `-DeltaMode` to resume interrupted migrations
   - Keep logs for troubleshooting

### Post-Migration
1. **Validate Results**
   - Run Phase 7 verification
   - Spot-check important channels
   - Verify file attachments

2. **User Communication**
   - Notify users of migration completion
   - Provide Teams access instructions
   - Share any known limitations

### Enterprise Considerations
1. **Schedule During Maintenance Windows**
   ```powershell
   # Use Windows Task Scheduler
   schtasks /create /tn "SlackMigration" /tr "powershell.exe -File C:\Path\To\Run-All.ps1 -Mode Live -ExecutionMode Auto" /sc once /st 02:00
   ```

2. **Implement Monitoring**
   - Set up log aggregation
   - Configure alerting for failures
   - Create runbooks for common issues

3. **Compliance and Security**
   - Audit all configuration files
   - Secure API tokens and secrets
   - Document data handling procedures

## Support and Resources

### Getting Help
- Check logs in `Logs\` directory
- Review test results in `Tests\TestReport.md`
- Validate configuration with `Tests\Validate-Config.ps1`

### Additional Resources
- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/)
- [Slack Web API Documentation](https://api.slack.com/web)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)

---

For questions or issues, please check the troubleshooting section or create an issue in the repository.