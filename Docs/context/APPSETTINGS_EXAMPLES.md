# appsettings.json Examples

## Minimal
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

## Full with Explanations

{
  "Slack": {
    "Token": "xoxb-your-slack-token", // Required for Slack API calls
    "WorkspaceName": "acme-corp", // Used for logging and verification
    "ExportPath": "C:\\Exports\\slack" // Path to unzipped Slack export
  },
  "Teams": {
    "TenantId": "00000000-0000-0000-0000-000000000000", // Azure AD tenant ID
    "ClientId": "11111111-1111-1111-1111-111111111111", // App registration ID
    "ClientSecret": "your-client-secret", // App secret
    "DefaultTeamOwner": "owner@acme.com" // Fallback owner for provisioned Teams
  },
  "Migration": {
    "ArchiveRoot": "Archives", // Archive location
    "RetryLimit": 3, // Max retries for failed operations
    "LogLevel": "Info" // Logging verbosity
  }
}
