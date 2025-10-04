[CmdletBinding()]
param(
  [ValidateSet('Offline','Live')]
  [string]$Mode = 'Offline',
  [switch]$DryRun
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"
. "$PSScriptRoot\..\Shared\Shared-Graph.ps1"
. "$PSScriptRoot\..\Shared\Shared-Slack.ps1"

Write-Log -Level Info -Message "Phase2-MapUsers started. Mode=$Mode DryRun=$DryRun" -Context "Phase2"

$users = Get-SlackUsers
$mapCsvPath = "Config\mappings\users.csv"
$manualMap = @{}
if (Test-Path $mapCsvPath) {
  (Import-Csv $mapCsvPath) | ForEach-Object {
    $manualMap[$_.slack_user_id] = $_
  }
}

$mapOut = @()
foreach ($u in $users) {
  $slackId = $u.id
  $display = $u.profile.real_name
  $email = $u.profile.email
  $resolved = $null
  $method = 'none'

  if ($manualMap.ContainsKey($slackId)) {
    $resolved = $manualMap[$slackId].teams_user_principal_name
    $method = 'manual'
  } elseif ($Mode -eq 'Live' -and $email) {
    $found = Find-AadUserByEmail -Email $email
    if ($found) { $resolved = $found.userPrincipalName; $method = 'graph' }
  }

  $slackRole = if ($u.is_owner) { 'owner' } elseif ($u.is_admin) { 'owner' } else { 'member' }
  $teamsRole = $slackRole  # Direct mapping for simplicity
  $mapOut += [pscustomobject]@{
    slack_user_id = $slackId
    slack_display_name = $display
    slack_email = $email
    slack_role = $slackRole
    teams_upn = $resolved
    teams_role = $teamsRole
    method = $method
  }
}

$outPath = "Output\Phase2-MapUsers\user-map.json"
Write-JsonFile -Path $outPath -Object $mapOut
Write-Log -Level Info -Message "User mapping written to $outPath" -Context "Phase2"
Write-Log -Level Info -Message "Phase2-MapUsers completed." -Context "Phase2"
