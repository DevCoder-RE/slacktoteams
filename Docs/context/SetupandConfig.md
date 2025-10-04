Setup and operations guide
A task‑centric guide for preparing settings, credentials, and running the migration.

Prerequisites
PowerShell: 7.2+ recommended.

Modules: Microsoft.Graph (for interactive auth).

Access: Admin rights to grant Graph permissions; Slack app with required scopes.

OS: Windows (this guide), with permission to run scripts (Set‑ExecutionPolicy RemoteSigned for current user).

Install required PowerShell modules
Microsoft Graph SDK:

Install: Install-Module Microsoft.Graph -Scope CurrentUser

Update: Update-Module Microsoft.Graph

Credentials and permissions
Slack app/token:

Create app: From Slack API dashboard.

Add scopes (minimum): users:read, channels:read, groups:read, im:read, mpim:read, channels:history, groups:history, im:history, mpim:history, files:read.

Install to workspace: Generate token (bot or user as your policy allows).

Note: The orchestrator validates token and attempts scope verification; missing scopes produce WARN.

Microsoft Graph (choose one):

Interactive delegated:

Scopes to consent: Group.ReadWrite.All, ChannelMessage.Send, Chat.ReadWrite, Files.ReadWrite.All, User.ReadBasic.All, Sites.ReadWrite.All, Mail.Send (optional notifications).

Consent: Global admin consent if required by your tenant policy.

App registration (client credentials):

Create app: In Entra ID (Azure AD) App registrations.

Certificates & secrets: Create client secret or upload certificate.

API permissions (Application): Group.ReadWrite.All, Channel.ReadWrite.All, Chat.ReadWrite.All, Files.ReadWrite.All, User.Read.All, Sites.ReadWrite.All. Grant admin consent.

Record: TenantId, ClientId, ClientSecret (or cert details).

Configuration files
You can use both .env and appsettings.json. CLI overrides win.

Minimal examples (required variables only)
.env (minimal)

dotenv
SLACK_TOKEN=xoxb-your-slack-token
TENANT_ID=your-tenant-guid
CLIENT_ID=your-app-client-id
CLIENT_SECRET=your-client-secret
appsettings.json (minimal)

json
{
  "Run": {
    "ApplyDefaultDateRange": true,
    "DefaultDateRangeDays": 365
  },
  "Paths": {
    "ExportRoot": ".\\testdata\\slack_export",
    "StatePath": ".\\state"
  }
}
Full examples (all variables and options)
.env (full)

dotenv
# Auth
SLACK_TOKEN=xoxb-your-slack-token
TENANT_ID=your-tenant-guid
CLIENT_ID=your-client-id
CLIENT_SECRET=your-client-secret

# Notifications
SMTP_SERVER=smtp.example.test
SMTP_PORT=587
SMTP_USER=notifier@example.test
SMTP_PASSWORD=your-smtp-password
NOTIFY_FROM=notifier@example.test
NOTIFY_TO=ops@example.test
appsettings.json (full)

json
{
  "Auth": {
    "GraphAuthMode": "Interactive",
    "GraphScopes": [
      "Group.ReadWrite.All",
      "ChannelMessage.Send",
      "Chat.ReadWrite",
      "Files.ReadWrite.All",
      "User.ReadBasic.All",
      "Sites.ReadWrite.All",
      "Mail.Send"
    ]
  },
  "Structure": {
    "TeamLayout": "SingleTeamManyChannels",
    "ValidatePreexisting": true,
    "PreexistingBehavior": "Align",
    "PrivateChannelsAsPrivate": true,
    "UseImportMode": true,
    "DMStrategy": "ActualChats"
  },
  "Files": {
    "PreservePseudoStructure": true,
    "ChunkedUploads": true,
    "DuplicateHandling": "Suffix",
    "AttachmentLinking": "SeparateMessage"
  },
  "Run": {
    "DeltaMode": true,
    "OfflineMode": false,
    "Mode": "Auto",
    "StartAt": 0,
    "EndAt": 99,
    "MaxDop": 4,
    "StartDate": null,
    "EndDate": null,
    "ApplyDefaultDateRange": true,
    "DefaultDateRangeDays": 365,
    "DateRangeTargets": "All",
    "IncludeFilesInRange": true,
    "FileDateBasis": "Message",
    "SkipMessagesContaining": ["test channel"],
    "SkipFileTypes": ["exe", "bat"],
    "SkipFileMaxSizeMB": 50,
    "LogJson": false,
    "LogToFile": true,
    "LogFilePath": ".\\state\\run.log",
    "ContinueOnError": true,
    "SaveReportPath": ".\\state\\runreport.json"
  },
  "Notify": {
    "Enabled": true,
    "Method": "SMTP",
    "From": "notifier@example.test",
    "To": "ops@example.test",
    "Smtp": { "Server": "smtp.example.test", "Port": 587, "UseTls": true, "User": "notifier@example.test", "Password": "your-smtp-password" }
  },
  "Paths": {
    "ExportRoot": ".\\testdata\\slack_export",
    "StatePath": ".\\state"
  }
}
How options affect logic (by phase)
Phase 0 (Discovery):

ExportRoot: Source of truth; inventory.json output to StatePath.

Skip rules/date filters: Not applied here; inventory is complete for targeting.

Phase 1 (Parse):

No filters: Produces normalized slack_data.json; later phases filter.

Phase 2 (Map Users):

GraphAuthMode/Scopes: Determines auth path; success influences authorship handling later.

Notifications: Errors can trigger alerts if enabled.

Phase 3 (Create Targets):

TeamLayout/PrivateChannelsAsPrivate: Controls Teams structure and privacy.

ValidatePreexisting/PreexistingBehavior: Reuse vs align vs fail; affects idempotency.

Phase 4 (Post Messages):

DateRangeTargets/StartDate/EndDate: Limits which messages post.

SkipMessagesContaining: Omits sensitive/test chatter.

UseImportMode: Preserves authorship/timestamps; otherwise posts as service account with prefix.

DMStrategy: Controls DM migration target.

Phase 5 (Download Files):

IncludeFilesInRange/FileDateBasis: Filters files by message or file timestamp.

SkipFileTypes/SkipFileMaxSizeMB: Omits undesired or too‑large files.

DeltaMode: Only downloads missing files.

Phase 6 (Upload Files):

PreservePseudoStructure: Creates SharePoint folders per channel/thread/date.

DuplicateHandling: Suffix strategy when same filename exists.

ChunkedUploads: Enables large‑file upload sessions; respects rate‑limit policies.

Phase 7 (Validate & Report):

SaveReportPath: Emits JSON summary for audits.

Notifications: Can send end‑of‑run summary.

Running common scenarios
Generate test dataset:

Run: .\Generate-TestSlackExport.ps1 -Root .\testdata

List inventory:

Run: .\Migrate.ps1 -ListChannels -AsTable

Run: .\Migrate.ps1 -ListFiles -AsMarkdown > files.md

Dry‑run limited date window (messages + files by message date):

Run: .\Migrate.ps1 -StartDate "2025-07-01" -EndDate "2025-07-31" -IncludeFilesInDateRange -OnlyPhases 4,5,6 -Mode ConfirmEachPhase

Skip undesired content and stress chunked uploads:

Set: SkipFileTypes=[], SkipFileMaxSizeMB large (e.g., 100), ChunkedUploads=true

Run: .\Migrate.ps1 -OnlyPhases 5,6

Selective phases with dependency caution:

Run: .\Migrate.ps1 -Phases 3,5-6

Tips and gotchas
Time zones: Slack timestamps are epoch seconds (UTC). Keep StartDate/EndDate in UTC or ISO 8601 (Z).

Import mode lifecycle: Teams channels in import mode are read‑only for normal users until “complete migration” is called; plan cutovers.

Rate limits: Expect 429s under load; back‑off and jitter are enabled; consider lowering MaxDop if you see persistent throttling.

User mapping gaps: Unmapped users trigger authorship fallback; review user_map.json coverage before large runs.

Idempotency: DeltaMode avoids duplicates; safe to re‑run phases if a run fails mid‑flight.

Diagram (ASCII, alternative)
Code
[Slack Export] -> [Phase 0 Inventory] -> [Phase 1 Parse] -> [Phase 2 Map]
       \                                                    /
        \--(Filters/Skip/Date)-> [Phase 4 Messages] -> [Phase 7 Report]
                               \-> [Phase 5 Download] -> [Phase 6 Upload]
And the mermaid code is provided above in the Master summary document.