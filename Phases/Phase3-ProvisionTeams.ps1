[CmdletBinding()]
param(
    [ValidateSet('Offline','Live')]
    [string]$Mode = 'Offline',
    [string[]]$ChannelFilter,
    [switch]$DeltaMode,
    [switch]$DryRun
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"
. "$PSScriptRoot\..\Shared\Shared-Graph.ps1"
. "$PSScriptRoot\..\Shared\Shared-Slack.ps1"

Write-Log -Level Info -Message "Phase3-ProvisionTeams started. Mode=$Mode ChannelFilter=$($ChannelFilter -join ',') DeltaMode=$DeltaMode DryRun=$DryRun" -Context "Phase3"

$discoverPath = "Output\Phase1-ParseSlack\discovery-summary.json"
if (-not (Test-Path $discoverPath)) { throw "Discovery summary not found. Run Phase1 first." }
$discovery = Read-JsonFile -Path $discoverPath

$channelMapPath = "Config\mappings\channels.csv"
$channelMap = @{}
if (Test-Path $channelMapPath) {
    (Import-Csv $channelMapPath) | ForEach-Object {
        $channelMap[$_.slack_channel_name] = $_
    }
}

$teamName = Get-Config 'Posting.DefaultTeamName' 'Slack Migration'
$teamDesc = Get-Config 'Posting.DefaultTeamDescription' 'Imported from Slack'

$provision = @{
    team     = $null
    channels = @()
}

# Delta mode: check if already provisioned
$provisionFile = "Output\Phase3-Provision\provision-summary.json"
if ($DeltaMode -and (Test-Path $provisionFile)) {
    Write-Log -Level Info -Message "Delta mode: Provision already exists, skipping" -Context "Phase3"
    return
}

$userMapPath = "Output\Phase2-MapUsers\user-map.json"
if (-not (Test-Path $userMapPath)) { throw "User map not found. Run Phase2 first." }
$userMap = Read-JsonFile -Path $userMapPath

if ($DryRun) {
    Write-Log -Level Info -Message "DryRun: Would create Team '$teamName' and channels from discovery." -Context "Phase3"
} else {
    $team = New-Team -DisplayName $teamName -Description $teamDesc
    $provision.team = $team
    Write-Log -Level Info -Message "Created Team '$teamName' (ID: $($team.id))" -Context "Phase3"

    # Add owners
    $owners = $userMap | Where-Object { $_.teams_role -eq 'owner' -and $_.teams_upn }
    if ($owners) {
        foreach ($owner in $owners) {
            try {
                $userId = (Find-AadUserByEmail -Email $owner.teams_upn).id
                if ($userId) {
                    Add-TeamMember -TeamId $team.id -UserId $userId -Role 'owner'
                    Write-Log -Level Info -Message "Added owner $($owner.teams_upn) to team" -Context "Phase3"
                }
            } catch {
                Write-Log -Level Warn -Message "Failed to add owner $($owner.teams_upn): $($_.Exception.Message)" -Context "Phase3"
            }
        }
    }

    foreach ($ch in $discovery) {
        $map = $channelMap[$ch.channel]
        $targetName = if ($map) { $map.channel_name } else { $ch.channel }
        $visibility = if ($map) { $map.visibility } else { 'standard' }
        $chan = New-TeamChannel -TeamId $team.id -DisplayName $targetName -MembershipType $visibility
        $provision.channels += [pscustomobject]@{
            slack_channel_name = $ch.channel
            teams_channel_id   = $chan.id
            teams_channel_name = $targetName
        }
        Write-Log -Level Info -Message "Created channel '$targetName' in Team '$teamName'" -Context "Phase3"
    }
}

Write-JsonFile -Path "Output\Phase3-Provision\provision-summary.json" -Object $provision
Write-Log -Level Info -Message "Phase3-ProvisionTeams completed." -Context "Phase3"
