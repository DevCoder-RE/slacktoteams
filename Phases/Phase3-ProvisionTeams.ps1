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

if ($DryRun) {
    Write-Log -Level Info -Message "DryRun: Would create Team '$teamName' and channels from discovery." -Context "Phase3"
} else {
    $team = New-Team -DisplayName $teamName -Description $teamDesc
    $provision.team = $team
    Write-Log -Level Info -Message "Created Team '$teamName' (ID: $($team.id))" -Context "Phase3"

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
