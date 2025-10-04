# API Reference

## Run-All.ps1 Parameters

### Core Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Mode` | `Offline` \| `Live` | Yes | - | Migration mode |
| `ExecutionMode` | `Auto` \| `ConfirmOnError` \| `ConfirmEachPhase` | No | `Auto` | Confirmation behavior |
| `DryRun` | `switch` | No | `false` | Preview mode without changes |
| `Rollback` | `switch` | No | `false` | Enable rollback mode |
| `FullRollback` | `switch` | No | `false` | Perform full team/channel removal |
| `SelectiveRollback` | `switch` | No | `false` | Perform selective rollback |
| `BackupPath` | `string` | No | - | Custom backup path for rollback |
| `RealTimeSync` | `switch` | No | `false` | Enable real-time sync mode |
| `SyncIntervalMinutes` | `int` | No | `5` | Sync interval in minutes |
| `MaxRuntimeHours` | `int` | No | `24` | Maximum sync runtime |
| `ContinuousMode` | `switch` | No | `false` | Continuous sync without pauses |
| `EnableParallel` | `switch` | No | `false` | Enable parallel processing |
| `MaxConcurrentChannels` | `int` | No | `3` | Max concurrent channel processing |
| `MaxConcurrentFiles` | `int` | No | `5` | Max concurrent file processing |

### Filtering Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ChannelFilter` | `string[]` | No | - | Target specific Slack channels |
| `UserFilter` | `string[]` | No | - | Target specific Slack users |
| `SkipPhases` | `string[]` | No | - | Skip specific phases |

### Operational Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DeltaMode` | `switch` | No | `false` | Skip already processed items |
| `EmailNotifications` | `switch` | No | `false` | Send email alerts |
| `SkipProvision` | `switch` | No | `false` | Skip Teams provisioning |
| `SkipFiles` | `switch` | No | `false` | Skip file operations |

## Phase-Specific Parameters

### Phase 1: ParseSlack
```powershell
.\Phase1-ParseSlack.ps1 -Mode <Offline|Live> [-ChannelFilter <string[]>] [-UserFilter <string[]>] [-DeltaMode] [-DryRun]
```

### Phase 2: MapUsers
```powershell
.\Phase2-MapUsers.ps1 -Mode <Offline|Live> [-DryRun]
```

### Phase 3: ProvisionTeams
```powershell
.\Phase3-ProvisionTeams.ps1 -Mode <Offline|Live> [-ChannelFilter <string[]>] [-DeltaMode] [-DryRun]
```

### Phase 4: PostMessages
```powershell
.\Phase4-PostMessages.ps1 -Mode <Offline|Live> [-ChannelFilter <string[]>] [-UserFilter <string[]>] [-DeltaMode] [-DryRun]
```

### Phase 5: DownloadFiles
```powershell
.\Phase5-DownloadFiles.ps1 -Mode <Offline|Live> [-ChannelFilter <string[]>] [-UserFilter <string[]>] [-DeltaMode] [-DryRun]
```

### Phase 6: UploadFiles
```powershell
.\Phase6-UploadFiles.ps1 -Mode <Offline|Live> [-ChannelFilter <string[]>] [-DeltaMode] [-DryRun]
```

### Phase 7: VerifyMigration
```powershell
.\Phase7-VerifyMigration.ps1 -Mode <Offline|Live> [-DryRun]
```

### Phase 8: RetryAndFixups
```powershell
.\Phase8-RetryAndFixups.ps1 -Mode <Offline|Live> [-DryRun]
```

### Phase 9: ArchiveRun
```powershell
.\Phase9-ArchiveRun.ps1 -Mode <Offline|Live> [-DryRun]
```

### Phase 10: Rollback
```powershell
.\Phase10-Rollback.ps1 -Mode <Offline|Live> [-ChannelFilter <string[]>] [-UserFilter <string[]>] [-DryRun] [-FullRollback] [-SelectiveRollback] [-BackupPath <string>]
```

### Phase 11: RealTimeSync
```powershell
.\Phase11-RealTimeSync.ps1 -Mode <Offline|Live> [-ChannelFilter <string[]>] [-UserFilter <string[]>] [-DryRun] [-SyncIntervalMinutes <int>] [-MaxRuntimeHours <int>] [-ContinuousMode]
```

## Configuration File Reference

### appsettings.json
```json
{
  "Graph": {
    "TenantId": "string",           // Azure tenant ID
    "ClientId": "string",           // Azure app client ID
    "ClientSecret": "string",       // Azure app client secret
    "ApiBaseUrl": "string"          // Graph API base URL (optional)
  },
  "Slack": {
    "Token": "string",              // Slack API token
    "ApiBaseUrl": "string"          // Slack API base URL (optional)
  },
  "Posting": {
    "DefaultTeamName": "string",    // Default Teams name
    "DefaultTeamDescription": "string", // Default Teams description
    "DryRunMaxMessages": "number"   // Max messages in dry run
  },
  "Email": {
    "SmtpServer": "string",         // SMTP server address
    "From": "string",                // From email address
    "To": "string"                   // To email address
  },
  "Paths": {
    "SlackExport": "string",        // Slack export path
    "Output": "string",              // Output directory
    "Logs": "string"                 // Logs directory
  }
}
```

### .env File
```bash
# Microsoft Graph API
GRAPH_TENANT_ID=your-tenant-id
GRAPH_CLIENT_ID=your-client-id
GRAPH_CLIENT_SECRET=your-client-secret

# Slack API
SLACK_TOKEN=xoxb-your-slack-token

# Email (optional)
SMTP_SERVER=smtp.company.com
EMAIL_FROM=migration@company.com
EMAIL_TO=admin@company.com
```

### message-filters.json
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

### users.csv
```csv
slack_id,email,display_name
U123456,user1@company.com,John Doe
U789012,user2@company.com,Jane Smith
```

### channels.csv
```csv
slack_channel_name,channel_name,visibility
general,General,standard
random,Random,standard
private-hr,HR,private
```

### emoji-map.json
```json
{
  ":thumbsup:": "👍",
  ":heart:": "❤️",
  ":smile:": "😊"
}
```

## Shared Module Functions

### Shared-Logging.ps1
```powershell
Write-Log -Level <Info|Warn|Error|Fatal> -Message "string" [-Context "string"]
```

### Shared-Config.ps1
```powershell
Get-Config -Key "string" [-Default "string"]
Load-AppConfig -AppSettingsPath "string" -EnvPath "string"
```

### Shared-Json.ps1
```powershell
Read-JsonFile -Path "string"
Write-JsonFile -Path "string" -Object $object
```

### Shared-Retry.ps1
```powershell
Invoke-WithRetry -ScriptBlock { ... } [-MaxRetries <number>] [-DelaySeconds <number>]
```

### Shared-Graph.ps1
```powershell
Connect-Graph -TenantId "string" -ClientId "string" -ClientSecret "string"
New-Team -DisplayName "string" -Description "string"
New-TeamChannel -TeamId "string" -DisplayName "string" -MembershipType <standard|private>
Post-ChannelMessage -TeamId "string" -ChannelId "string" -Content "string"
Upload-FileToChannel -TeamId "string" -ChannelId "string" -FilePath "string"
```

### Shared-Slack.ps1
```powershell
Get-SlackUsers
Get-SlackChannels
Get-SlackChannelMessageFiles
Download-SlackFile -UrlPrivate "string" -OutFile "string"
Convert-SlackMarkdownToHtml -Text "string" -EmojiMap $map
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Configuration error |
| 3 | Authentication error |
| 4 | Network error |
| 5 | API rate limit error |

## Error Messages

### Common Errors
- `Phase X failed: API rate limit exceeded` - Automatic retry will be attempted
- `No provisioned channel for 'channel-name'` - Run Phase 3 first or check channel mapping
- `Failed to authenticate with Microsoft Graph` - Check Azure AD app configuration
- `Slack export not found` - Verify export path in configuration

### Warning Messages
- `Delta mode: Skipping channel (already processed)` - Normal for delta sync
- `File not found locally` - File may have been deleted from Slack
- `User not found in mapping` - User will appear as "unknown" in Teams

## Log Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| INFO | General information | Normal operations |
| WARN | Warning conditions | Non-critical issues |
| ERROR | Error conditions | Failures that may be retried |
| FATAL | Critical errors | Failures that stop execution |

## Performance Metrics

### Typical Throughput
- Message posting: 50-100 messages/minute
- File downloads: 10-20 files/minute
- File uploads: 5-10 files/minute

### Memory Usage
- Base consumption: 100-200 MB
- Per 1000 messages: +50 MB
- Large file processing: +100 MB per GB of files

### Disk Usage
- Logs: 1-5 MB per hour
- Temporary files: 2x size of downloaded files
- Final output: 1.5x size of processed data