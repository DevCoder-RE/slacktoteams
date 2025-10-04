[CmdletBinding()]
param(
  [ValidateSet('Offline','Live')]
  [string]$Mode = 'Offline',
  [string[]]$ChannelFilter,
  [string[]]$UserFilter,
  [switch]$DeltaMode,
  [switch]$DryRun
)

. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"
. "$PSScriptRoot\..\Shared\Shared-Json.ps1"
. "$PSScriptRoot\..\Shared\Shared-Slack.ps1"

Write-Log -Level Info -Message "Phase1-ParseSlack started. Mode=$Mode ChannelFilter=$($ChannelFilter -join ',') UserFilter=$($UserFilter -join ',') DeltaMode=$DeltaMode DryRun=$DryRun" -Context "Phase1"

$exportPath = Get-Config 'Paths.SlackExport' 'Data/SlackExport'
$emojiMapPath = 'Config\mappings\emoji-map.json'
$emojiMap = @{}
if (Test-Path $emojiMapPath) {
  $emojiMap = (Read-JsonFile -Path $emojiMapPath) | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
}

$filtersPath = Get-Config 'Slack.MessageFiltersPath' 'Config\message-filters.json'
$filters = $null
if (Test-Path $filtersPath) { $filters = Read-JsonFile -Path $filtersPath }

$users = Get-SlackUsers
$channels = Get-SlackChannels
$inventory = @()
$parsedOutDir = "Output\Phase1-ParseSlack"
if (-not (Test-Path $parsedOutDir)) { New-Item -ItemType Directory -Path $parsedOutDir | Out-Null }

function Should-ExcludeMessage {
  param($m)
  if (-not $filters) { return $false }
  if ($filters.excludeSystemMessages -and $m.subtype) { return $true }
  if ($filters.excludeMessageTypes -and ($m.subtype -in $filters.excludeMessageTypes)) { return $true }
  if ($filters.dateRange) {
    if ($filters.dateRange.from) {
      $from = Get-Date $filters.dateRange.from
      $ts = [DateTimeOffset]::FromUnixTimeSeconds([int][double]$m.ts).DateTime
      if ($ts -lt $from) { return $true }
    }
    if ($filters.dateRange.to) {
      $to = Get-Date $filters.dateRange.to
      $ts = [DateTimeOffset]::FromUnixTimeSeconds([int][double]$m.ts).DateTime
      if ($ts -gt $to) { return $true }
    }
  }
  if ($filters.textFilters) {
    foreach ($f in $filters.textFilters) {
      if ($f.action -eq 'exclude' -and $m.text -match $f.pattern) { return $true }
    }
  }
  return $false
}

# Build user lookup
$userById = @{}
foreach ($u in $users) {
  $userById[$u.id] = $u
}

# Iterate channel message files
$msgFiles = Get-SlackChannelMessageFiles
$dryLimit = [int](Get-Config 'Posting.DryRunMaxMessages' 100)

# Apply channel filter
if ($ChannelFilter) {
    $msgFiles = $msgFiles | Where-Object { $_.Channel -in $ChannelFilter }
    Write-Log -Level Info -Message "Filtered to $($msgFiles.Count) channels: $($ChannelFilter -join ',')" -Context "Phase1"
}

foreach ($mf in $msgFiles) {
  $channelName = $mf.Channel
  $file = $mf.File
  $messages = Read-JsonFile -Path $file

  # Apply user filter
  if ($UserFilter) {
    $messages = $messages | Where-Object { $_.user -in $UserFilter }
    Write-Log -Level Info -Message "Filtered to $($messages.Count) messages for users: $($UserFilter -join ',')" -Context "Phase1"
  }

  $out = @()
  $count = 0
  $firstTs = $null; $lastTs = $null
  foreach ($m in $messages) {
    if (Should-ExcludeMessage -m $m) { continue }
    $author = if ($m.user -and $userById.ContainsKey($m.user)) { $userById[$m.user].profile.real_name } elseif ($m.username) { $m.username } else { 'unknown' }
    $html = Convert-SlackMarkdownToHtml -Text $m.text -EmojiMap $emojiMap
    $ts = if ($m.ts) { [DateTimeOffset]::FromUnixTimeSeconds([int][double]$m.ts).ToString('o') } else { (Get-Date).ToString('o') }
    $files = @()
    if ($m.files) {
      foreach ($f in $m.files) {
        $files += [pscustomobject]@{
          id = $f.id
          name = $f.name
          mimetype = $f.mimetype
          url_private = $f.url_private
        }
      }
    }
    $out += [pscustomobject]@{
      channel = $channelName
      author = $author
      slack_user_id = $m.user
      timestamp = $ts
      text_html = $html
      files = $files
      raw = $m
    }
    $count++
    $dt = [DateTime]::Parse($ts)
    if (-not $firstTs -or $dt -lt $firstTs) { $firstTs = $dt }
    if (-not $lastTs -or $dt -gt $lastTs) { $lastTs = $dt }
    if ($DryRun -and $count -ge $dryLimit) { break }
  }
  $outPath = Join-Path $parsedOutDir "$($channelName)-parsed-messages.json"
  Write-JsonFile -Path $outPath -Object $out
  $inventory += [pscustomobject]@{
    channel = $channelName
    message_count = $out.Count
    first_message = if ($firstTs) { $firstTs.ToString('o') } else { $null }
    last_message = if ($lastTs) { $lastTs.ToString('o') } else { $null }
    file_refs = ($out | ForEach-Object { $_.files.Count } | Measure-Object -Sum).Sum
  }
  Write-Log -Level Info -Message "Parsed $($out.Count) messages from $channelName" -Context "Phase1"
}

Write-JsonFile -Path "Output\Phase1-ParseSlack\discovery-summary.json" -Object $inventory
Write-Log -Level Info -Message "Phase1-ParseSlack completed." -Context "Phase1"
