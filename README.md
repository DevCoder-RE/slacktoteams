# Slack to Teams Migration Tool

A comprehensive, enterprise-ready PowerShell solution for migrating Slack workspaces to Microsoft Teams. This tool provides a complete migration pipeline with advanced features for production environments.

## ✨ Key Features

- **🔄 Full Migration Pipeline**: 9-phase process covering parsing, mapping, provisioning, posting, file handling, and validation
- **🎯 Targeted Migrations**: Filter by channels, users, or run incremental delta syncs
- **⚡ Multiple Execution Modes**: Auto, ConfirmOnError, or ConfirmEachPhase for different operational needs
- **📧 Email Notifications**: Automated alerts for phase completions and errors
- **🔁 API Resilience**: Built-in retry mechanisms and graceful failure handling
- **📊 Comprehensive Logging**: Detailed logs with timestamps and severity levels
- **🧪 Test Suite**: Complete test framework with realistic test data
- **📈 Enterprise Ready**: Production-tested with error recovery and monitoring

## 📋 Migration Pipeline

| Phase | Script | Description |
|-------|--------|-------------|
| 1 | `Phase1-ParseSlack.ps1` | Parse Slack export JSON files and normalize data |
| 2 | `Phase2-MapUsers.ps1` | Map Slack users to Microsoft 365 accounts |
| 3 | `Phase3-ProvisionTeams.ps1` | Create Teams team and channels |
| 4 | `Phase4-PostMessages.ps1` | Post messages with proper timestamps and threading |
| 5 | `Phase5-DownloadFiles.ps1` | Download files from Slack (API or local) |
| 6 | `Phase6-UploadFiles.ps1` | Upload files to Teams channels |
| 7 | `Phase7-VerifyMigration.ps1` | Validate migration success and generate reports |
| 8 | `Phase8-RetryAndFixups.ps1` | Retry failed operations and apply fixes |
| 9 | `Phase9-ArchiveRun.ps1` | Archive logs, outputs, and reports |
| 10 | `Phase10-Rollback.ps1` | Rollback migration with backup and selective undo |
| 11 | `Phase11-RealTimeSync.ps1` | Continuous sync of new Slack messages to Teams |

## 📋 Requirements

- **Platform**: Windows PowerShell 5.1+ or PowerShell 7+
- **Dependencies**: No external modules required (uses built-in PowerShell)
- **Slack Data**: Full Slack export (unzipped) or Slack API token for live file access
- **Microsoft**: Azure AD app registration with Graph API permissions (for Teams operations)
- **Optional**: SMTP server for email notifications

## 🚀 Quick Start

> 📖 **New to the tool?** Start with **[Quick Start Guide](QUICKSTART.md)** for a 15-minute setup!

1. **Clone and Setup**
   ```powershell
   git clone <repository-url>
   cd slack-to-teams-migration
   .\Setup.ps1
   ```

2. **Configure Credentials**
   - Update `Config\.env` with API tokens and secrets
   - Update `Config\appsettings.json` with your settings
   - Configure `Config\mappings\users.csv` for user mapping
   - Optional: Configure email settings for notifications

3. **Prepare Data**
   - Place Slack export in `Data\SlackExport\` (for offline mode)
   - Or configure API access for live mode

4. **Run Migration**
   ```powershell
   # Full migration
   .\Run-All.ps1 -Mode Live

   # Targeted migration with notifications
   .\Run-All.ps1 -Mode Live -ChannelFilter "engineering","finance" -ExecutionMode ConfirmOnError -EmailNotifications

   # Delta sync
   .\Run-All.ps1 -Mode Live -DeltaMode -ExecutionMode Auto
   ```

2. **Configure Credentials**
   - Update `Config\.env` with API tokens and secrets
   - Update `Config\appsettings.json` with your settings
   - Configure `Config\mappings\users.csv` for user mapping
   - Optional: Configure email settings for notifications

3. **Prepare Data**
   - Place Slack export in `Data\SlackExport\`
   - Or configure API access for live mode

4. **Run Migration**
   ```powershell
   # Full migration
   .\Run-All.ps1 -Mode Live

   # Targeted migration with notifications
   .\Run-All.ps1 -Mode Live -ChannelFilter "engineering","finance" -ExecutionMode ConfirmOnError -EmailNotifications

   # Delta sync
   .\Run-All.ps1 -Mode Live -DeltaMode -ExecutionMode Auto
   ```

## ⚙️ Configuration

### Core Configuration Files
- **`Config\appsettings.json`**: Main application settings
- **`Config\.env`**: Environment variables and secrets
- **`Config\mappings\users.csv`**: Slack to Microsoft 365 user mapping
- **`Config\mappings\channels.csv`**: Slack to Teams channel mapping
- **`Config\message-filters.json`**: Message filtering rules
- **`Config\mappings\emoji-map.json`**: Slack emoji to text mapping

### Run-All.ps1 Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `Mode` | `Offline`/`Live` | Migration mode |
| `ExecutionMode` | `Auto`/`ConfirmOnError`/`ConfirmEachPhase` | Confirmation behavior |
| `ChannelFilter` | `string[]` | Target specific channels |
| `UserFilter` | `string[]` | Target specific users |
| `DeltaMode` | `switch` | Skip already processed items |
| `EmailNotifications` | `switch` | Send email alerts |
| `SkipPhases` | `string[]` | Skip specific phases |
| `SkipProvision` | `switch` | Skip Teams provisioning |
| `SkipFiles` | `switch` | Skip file operations |
| `DryRun` | `switch` | Preview mode without changes |

### Email Configuration
Add to `Config\appsettings.json`:
```json
{
  "Email": {
    "SmtpServer": "smtp.company.com",
    "From": "migration@company.com",
    "To": "admin@company.com"
  }
}
```

## 📁 Outputs and Logs

### Directory Structure
```
Output/
├── Phase1-ParseSlack/          # Parsed message data
├── Phase2-MapUsers/            # User mapping results
├── Phase3-Provision/           # Teams provisioning data
├── Phase4-PostMessages/        # Message posting results
├── Phase5-DownloadFiles/       # Downloaded files by channel
├── Phase6-UploadFiles/         # File upload results
├── Phase7-VerifyMigration/     # Validation reports
├── Phase8-RetryAndFixups/      # Retry operation logs
└── Phase9-ArchiveRun/          # Archived run data

Logs/                           # Detailed execution logs
Reports/                        # Summary reports and metrics
```

### Log Format
```
[timestamp][LEVEL] message
[2025-09-11 14:30:15][INFO] Phase 1 completed successfully
[2025-09-11 14:30:16][ERROR] Failed to post message: API rate limit exceeded
```

## 🔧 Advanced Usage

### Targeted Migrations
```powershell
# Migrate specific channels
.\Run-All.ps1 -ChannelFilter "engineering","product","hr"

# Migrate messages from specific users
.\Run-All.ps1 -UserFilter "U123456","U789012"

# Combine filters
.\Run-All.ps1 -ChannelFilter "engineering" -UserFilter "U123456"
```

### Delta Sync
```powershell
# Skip already processed items
.\Run-All.ps1 -DeltaMode

# Resume interrupted migration
.\Run-All.ps1 -DeltaMode -ExecutionMode ConfirmOnError
```

### Custom Execution
```powershell
# Interactive mode with confirmations
.\Run-All.ps1 -ExecutionMode ConfirmEachPhase

# Automated with error handling
.\Run-All.ps1 -ExecutionMode ConfirmOnError -EmailNotifications

# Skip specific phases
.\Run-All.ps1 -SkipPhases "Phase5-DownloadFiles","Phase6-UploadFiles"
```

## 🧪 Testing

### Run Test Suite
```bash
# Run all tests
./Tests/Run-AllTests.sh

# Validate configuration
./Tests/Validate-Config.ps1

# Validate test data
./Tests/Validate-TestData.ps1
```

### Test Data
The `Tests/testdata/` directory contains:
- Complete Slack export sample with 7 channels
- Various file types (PDF, images, videos, text)
- Realistic user and message data
- Edge cases for validation

## 🔍 Troubleshooting

### Common Issues

**API Rate Limits**
- Solution: Built-in retry mechanisms handle this automatically
- Monitor: Check logs for retry attempts

**Permission Errors**
- Teams: Ensure Azure AD app has `TeamMember.ReadWrite.All` and `ChannelMessage.Send`
- Slack: Verify token has `files:read` scope

**Large Files**
- Teams has 2GB limit per file
- Large files are automatically skipped with warnings

**User Mapping**
- Unmapped users appear as "unknown" in Teams
- Check `Config\mappings\users.csv` for completeness

### Log Analysis
```powershell
# View recent errors
Get-Content Logs\*.log | Where-Object { $_ -match "\[ERROR\]" } | Select-Object -Last 10

# Check phase completion
Get-ChildItem Logs\ | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) }
```

## 📊 Monitoring and Reporting

### Real-time Monitoring
- Logs are written continuously during execution
- Email notifications for phase completions and errors
- Progress indicators in console output

### Post-Migration Reports
- `Output/Phase7-VerifyMigration/validation-report.json`
- Message count comparisons
- File attachment verification
- User mapping success rates

## ⚠️ Important Notes

- **Timestamps**: Teams messages show posting time, not original Slack timestamps
- **Threading**: Slack threads are preserved as replies in Teams
- **Private Channels**: Require proper Slack export permissions
- **File Attachments**: Linked in Teams messages with download links
- **Rate Limits**: Automatic handling with exponential backoff

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests: `./Tests/Run-AllTests.sh`
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**⚡ Ready for Production**: This tool has been tested with enterprise-scale migrations and includes comprehensive error handling and monitoring capabilities.

## 📂 Project Structure

```
slack-to-teams-migration/
├── 📄 README.md                    # This documentation
├── 📄 LICENSE                      # MIT License
├── 📄 .gitignore                   # Git ignore rules
├── 🔧 Setup.ps1                    # Initial setup and prerequisites
├── 🎯 Run-All.ps1                  # Main orchestration script
├── 📋 TestChecklist.md             # Migration testing checklist
├── 📊 TestReport.md                # Test execution results
│
├── ⚙️ Config/                      # Configuration files
│   ├── appsettings.json            # Main application settings
│   ├── appsettings.sample.json     # Configuration template
│   ├── .env                        # Environment variables and secrets
│   ├── message-filters.json        # Message filtering rules
│   └── mappings/                   # Data mapping files
│       ├── users.csv               # Slack → M365 user mapping
│       ├── channels.csv            # Slack → Teams channel mapping
│       └── emoji-map.json          # Emoji translation map
│
├── 🔧 Shared/                      # Shared utility modules
│   ├── Shared-Config.ps1           # Configuration management
│   ├── Shared-Json.ps1             # JSON file operations
│   ├── Shared-Logging.ps1          # Logging utilities
│   ├── Shared-Retry.ps1            # Retry mechanisms
│   ├── Shared-Graph.ps1            # Microsoft Graph API helpers
│   └── Shared-Slack.ps1            # Slack API helpers
│
├── 📂 Phases/                      # Migration phase scripts
│   ├── Phase1-ParseSlack.ps1       # Parse Slack export data
│   ├── Phase2-MapUsers.ps1         # User identity mapping
│   ├── Phase3-ProvisionTeams.ps1   # Teams/Channels creation
│   ├── Phase4-PostMessages.ps1     # Message migration
│   ├── Phase5-DownloadFiles.ps1    # File downloading
│   ├── Phase6-UploadFiles.ps1      # File uploading
│   ├── Phase7-VerifyMigration.ps1  # Validation and reporting
│   ├── Phase8-RetryAndFixups.ps1   # Error recovery
│   └── Phase9-ArchiveRun.ps1       # Run archiving
│
├── 🧪 Tests/                       # Test framework
│   ├── Run-AllTests.sh             # Complete test suite
│   ├── Run-Tests.sh                # Basic structure tests
│   ├── Run-Tests.ps1               # PowerShell test runner
│   ├── Validate-Config.ps1         # Configuration validator
│   ├── Validate-TestData.ps1       # Test data validator
│   ├── TestChecklist.md            # Test checklist
│   ├── TestReport.md               # Test results
│   └── testdata/                   # Test datasets
│       ├── slack_export/           # Sample Slack export
│       └── file_payloads/          # Sample files
│
├── 📚 Docs/                        # Documentation
│   ├── context/                    # Detailed context docs
│   ├── prd.md                      # Product requirements
│   ├── project-brief.md            # Project overview
│   ├── iterations.md               # Development iterations
│   └── idea.md                     # Original concept
│
├── 🚀 Bootstrap/                   # Bootstrap scripts
│   ├── Bootstrap-NewMigration.ps1  # New project setup
│   ├── Bootstrap-RunAll.ps1        # Full migration bootstrap
│   └── Bootstrap-Config.ps1        # Configuration bootstrap
│
└── 📦 Data/                        # Data directory
    └── Readme.md                   # Data placement guide
```

## 🔗 Documentation Links

### 📚 Core Documentation
- **[User Guide](Docs/USER_GUIDE.md)** - Complete usage instructions
- **[API Reference](Docs/API_REFERENCE.md)** - Detailed parameter and function reference
- **[Product Requirements](Docs/prd.md)** - Technical specifications
- **[Project Brief](Docs/project-brief.md)** - Project overview and goals

### 🧪 Testing & Validation
- **[Test Checklist](Tests/TestChecklist.md)** - Migration testing checklist
- **[Test Report](Tests/TestReport.md)** - Test execution results
- **[Test Suite Runner](Tests/Run-AllTests.sh)** - Execute all tests

### 📋 Project Management
- **[Development Iterations](Docs/iterations.md)** - Change history and updates
- **[Original Concept](Docs/idea.md)** - Initial project idea

### 🔧 Configuration Examples
- **[App Settings Example](Docs/context/APPSETTINGS_EXAMPLES.md)** - Configuration samples
- **[Setup Guide](Docs/context/SetupandConfig.md)** - Detailed setup instructions
