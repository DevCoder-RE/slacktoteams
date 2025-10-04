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