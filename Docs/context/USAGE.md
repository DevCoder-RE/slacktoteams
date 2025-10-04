# Usage & Instructions

## 1. Prepare Environment
- Install PowerShell 7+
- Install Microsoft Graph PowerShell SDK
- Obtain Slack export (JSON + files)
- Create Azure AD app for Graph API access

## 2. Configure Settings
- Edit `config.json` or `appsettings.json`
- Minimal example:
```json
{
  "Slack": {
    "Token": "xoxb-your-slack-token"
  },
  "Teams": {
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "ClientSecret": "your-client-secret"
  }
}

- Full example with explanations:
{
  "Slack": {
    "Token": "xoxb-your-slack-token", // Bot/User token with export access
    "WorkspaceName": "your-workspace", // Slack workspace name
    "ExportPath": "C:\\Exports\\slack" // Path to unzipped Slack export
  },
  "Teams": {
    "TenantId": "your-tenant-id", // Azure AD tenant
    "ClientId": "your-client-id", // App registration ID
    "ClientSecret": "your-client-secret", // App secret
    "DefaultTeamOwner": "owner@domain.com" // Fallback owner for new Teams
  },
  "Migration": {
    "ArchiveRoot": "Archives", // Where Phase9 stores archives
    "RetryLimit": 3, // Max retries for failed posts/uploads
    "LogLevel": "Info" // Verbosity: Info, Warn, Error, Debug
  }
}

## 3. Run Phases
- Run individually:
.\Phases\Phase1-ParseSlack.ps1

- Or run all:
.\Bootstrap\Bootstrap-RunAll.ps1

## 4. Retry & Archive
- Use Phase8 to retry failed messages/files.
- Use Phase9 to archive the run.

## 5. Testing
- Use Tests\TestChecklist.md to verify each phase.
- Use Tests\TestData for dry runs.