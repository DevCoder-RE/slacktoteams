[CmdletBinding()]
param(
    [string]$ConfigPath = ".\config.json"
)

$config = @{
    Slack = @{
        Token = "xoxb-your-slack-token"
        WorkspaceName = "your-workspace"
    }
    Teams = @{
        TenantId = "your-tenant-id"
        ClientId = "your-client-id"
        ClientSecret = "your-client-secret"
    }
    Migration = @{
        DefaultTeamOwner = "owner@domain.com"
        ArchiveRoot = "Archives"
    }
}

$config | ConvertTo-Json -Depth 5 | Out-File -FilePath $ConfigPath -Encoding UTF8
Write-Host "Config file created at $ConfigPath"
