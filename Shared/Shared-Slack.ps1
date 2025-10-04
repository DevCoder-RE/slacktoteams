#Requires -Version 5.1
Set-StrictMode -Version Latest
. "$PSScriptRoot\Shared-Logging.ps1"
. "$PSScriptRoot\Shared-Config.ps1"
. "$PSScriptRoot\Shared-Json.ps1"
. "$PSScriptRoot\Shared-Retry.ps1"

function Get-SlackExportPath {
  $p = Get-Config 'Paths.SlackExport' 'Data/SlackExport'
  return (Resolve-Path $p).Path
}

function Get-SlackUsers {
  $export = Get-SlackExportPath
  $usersPath = Join-Path $export (Get-Config 'Slack.ExportUsersFile' 'users.json')
  Read-JsonFile -Path $usersPath
}

function Get-SlackChannels {
  $export = Get-SlackExportPath
  $chPath = Join-Path $export (Get-Config 'Slack.ExportChannelsFile' 'channels.json')
  Read-JsonFile -Path $chPath
}

function Get-SlackChannelMessageFiles {
  $export = Get-SlackExportPath
  Get-ChildItem -Path $export -Directory | ForEach-Object {
    $channelName = $_.Name
    $files = Get-ChildItem $_.FullName -Filter '*.json' -File
    foreach ($f in $files) {
      [pscustomobject]@{
        Channel = $channelName
        File    = $f.FullName
      }
    }
  }
}

function Convert-SlackMarkdownToHtml {
  param([string]$Text, [hashtable]$EmojiMap)
  if (-not $Text) { return '' }
  $out = $Text
  # Mentions <@U123> -> @user (left as text; Teams mention API is complex)
  $out = $out -replace '<@([A-Z0-9]+)>','@user'
  # Channel refs <#C123|name> -> #name
  $out = $out -replace '<#([A-Z0-9]+)\|([^>]+)>','#$2'
  # Links <http://url|text> -> <a>
  $out = $out -replace '<(https?[^|>]+)\|([^>]+)>','<a href="$1">$2</a>'
  $out = $out -replace '<(https?[^>]+)>','<a href="$1">$1</a>'
  # Basic formatting
  $out = $out -replace '\*([^\*]+)\*','<b>$1</b>'
  $out = $out -replace '\_([^\_]+)\_','<i>$1</i>'
  $out = $out -replace '\~([^\~]+)\~','<s>$1</s>'
  # Emojis :smile:
  if ($EmojiMap) {
    $out = [regex]::Replace($out, ':(\w+):', {
      param($m)
      $name = $m.Groups[1].Value
      if ($EmojiMap.ContainsKey($name)) { $EmojiMap[$name] } else { $m.Value }
    })
  }
  # Newlines
  $out = $out -replace "`n","<br/>"
  return $out
}

function Invoke-SlackApi {
  param([string]$Method='GET',[string]$Path,[hashtable]$Body)
  $base = Get-Config 'Slack.ApiBaseUrl' 'https://slack.com/api'
  $token = (Get-Config 'Slack.Token' $env:SLACK_TOKEN)
  if (-not $token) { throw "Slack token not configured." }
  $headers = @{ Authorization = "Bearer $token" }
  $uri = "$base/$Path"
  $sb = {
    param($Method,$Uri,$Headers,$Body)
    if ($Method -in 'POST') {
      Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $Body
    } else {
      Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
    }
  }
  Invoke-WithRetry -ScriptBlock { & $sb $Method $uri $headers $Body } -Context "Slack:$Method $Path"
}

function Get-SlackFileById {
  param([string]$FileId)
  Invoke-SlackApi -Method GET -Path "files.info?file=$FileId"
}

function Download-SlackFile {
  param([string]$UrlPrivate,[string]$OutFile)
  $token = (Get-Config 'Slack.Token' $env:SLACK_TOKEN)
  $headers = @{ Authorization = "Bearer $token" }
  $dir = Split-Path -Parent $OutFile
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Invoke-WebRequest -Uri $UrlPrivate -Headers $headers -OutFile $OutFile
}

Export-ModuleMember -Function Get-SlackExportPath, Get-SlackUsers, Get-SlackChannels, Get-SlackChannelMessageFiles, Convert-SlackMarkdownToHtml, Invoke-SlackApi, Get-SlackFileById, Download-SlackFile
