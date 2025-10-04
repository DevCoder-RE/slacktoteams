# 🚀 Quick Start Guide

Get the Slack to Teams Migration Tool running in under 15 minutes!

## Prerequisites Check

✅ Windows PowerShell 5.1+ or PowerShell 7+  
✅ Azure AD app with Microsoft Graph permissions  
✅ Slack workspace export or API token  

## Step 1: Setup (2 minutes)

```powershell
# Clone and setup
git clone <repository-url>
cd slack-to-teams-migration
.\Setup.ps1
```

## Step 2: Configure (5 minutes)

### Edit Config\.env
```bash
# Microsoft Graph API
GRAPH_TENANT_ID=your-tenant-id
GRAPH_CLIENT_ID=your-app-id
GRAPH_CLIENT_SECRET=your-secret

# Slack API (if using live mode)
SLACK_TOKEN=xoxb-your-token
```

### Edit Config\appsettings.json
```json
{
  "Graph": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-app-id",
    "ClientSecret": "your-secret"
  },
  "Posting": {
    "DefaultTeamName": "My Slack Migration"
  }
}
```

### Prepare Data
- Place Slack export in `Data\SlackExport\` (for offline mode)
- Or ensure Slack token is configured (for live mode)

## Step 3: Test (2 minutes)

```powershell
# Run basic tests
.\Tests\Run-Tests.sh

# Validate configuration
.\Tests\Validate-Config.ps1
```

## Step 4: Migrate (5 minutes)

### Basic Migration
```powershell
# Test run (recommended first)
.\Run-All.ps1 -Mode Offline -DryRun

# Full migration
.\Run-All.ps1 -Mode Offline
```

### Advanced Options
```powershell
# Live mode with API access
.\Run-All.ps1 -Mode Live

# Specific channels only
.\Run-All.ps1 -Mode Live -ChannelFilter "general","random"

# With email notifications
.\Run-All.ps1 -Mode Live -EmailNotifications

# Interactive mode
.\Run-All.ps1 -Mode Live -ExecutionMode ConfirmEachPhase
```

## Step 5: Verify (1 minute)

```powershell
# Check results
Get-ChildItem Output\Phase7-VerifyMigration\

# View summary
Get-Content Output\Phase7-VerifyMigration\validation-report.json | ConvertFrom-Json
```

## 🎉 Success!

Your Slack workspace has been migrated to Microsoft Teams!

### What Happened
1. ✅ Parsed all Slack messages and files
2. ✅ Created Teams team and channels
3. ✅ Migrated messages with proper timestamps
4. ✅ Uploaded file attachments
5. ✅ Generated validation report

### Next Steps
- [ ] Notify team members about the migration
- [ ] Test key channels and conversations
- [ ] Archive the original Slack workspace
- [ ] Clean up temporary files if needed

## Troubleshooting

### Common Issues

**"Command not found"**
```powershell
# Ensure you're using PowerShell, not Command Prompt
powershell.exe -File .\Setup.ps1
```

**"Authentication failed"**
- Verify Azure AD app permissions
- Check tenant ID and client secret
- Ensure Slack token is valid

**"No data found"**
- Confirm Slack export is in `Data\SlackExport\`
- Check export was created with proper permissions

### Get Help
```powershell
# View detailed logs
Get-Content Logs\*.log | Select-Object -Last 20

# Run diagnostics
.\Tests\Validate-Config.ps1
.\Tests\Validate-TestData.ps1
```

## 📞 Need More Help?

- 📖 **[Full User Guide](Docs/USER_GUIDE.md)** - Complete documentation
- 🔧 **[API Reference](Docs/API_REFERENCE.md)** - All parameters and functions
- 🧪 **[Test Suite](Tests/Run-AllTests.sh)** - Validate your setup
- 📋 **[Test Checklist](Tests/TestChecklist.md)** - Pre-migration verification

---

**Time to complete:** 15 minutes  
**Skills required:** Basic PowerShell knowledge  
**Support:** Check logs in `Logs\` directory for detailed error information