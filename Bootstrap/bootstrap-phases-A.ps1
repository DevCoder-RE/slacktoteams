# bootstrap-phases-A.ps1
#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$SolutionRoot = (Join-Path (Get-Location).Path 'SlackToTeamsSolution')
)

$ErrorActionPreference = 'Stop'

function Write-PhaseFile {
    param([string]$Name,[string]$Body)
    $path = Join-Path $SolutionRoot "Phases\$Name"
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $path -Value $Body -Encoding UTF8 -Force
    Write-Host "Created: $path"
}

# --------------------------
# Phase 0: Discovery
# --------------------------
$phase0 = @'
param()
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"

function Get-ConfigValue {
    param([object]$Cfg,[string]$Path,[object]$Default=$null)
    $parts = $Path -split "\."
    $cur = $Cfg
    foreach ($p in $parts) {
        if ($null -eq $cur) { return $Default }
        if ($cur -is [System.Collections.IDictionary] -and $cur.Contains($p)) { $cur = $cur[$p]; continue }
        $cur = $cur | Select-Object -ExpandProperty $p -ErrorAction SilentlyContinue
    }
    if ($null -eq $cur) { return $Default } else { return $cur }
}

function Ensure-Dir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }

function Invoke-SlackApi {
    param(
        [string]$Method,
        [hashtable]$Params,
        [string]$Token
    )
    $uri = "https://slack.com/api/$Method"
    $headers = @{ Authorization = "Bearer $Token" }
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $Params -ContentType 'application/x-www-form-urlencoded'
    if (-not $resp.ok) {
        throw "Slack API $Method failed: $($resp.error)"
    }
    return $resp
}

Write-Log "Starting Phase 0: Discovery" "INFO"
$config = Get-Config
$solutionRoot = (Resolve-Path "$PSScriptRoot\..").Path
$reportsDir = Join-Path $solutionRoot "Output\Reports"
Ensure-Dir $reportsDir

$executionMode = Get-ConfigValue -Cfg $config.App -Path "ExecutionMode" -Default "Offline"

$discovery = [ordered]@{
    mode     = $executionMode
    ts       = (Get-Date).ToString("o")
    channels = @()
    users    = @()
}

if ($executionMode -eq 'Live') {
    $slackToken = $config.Env.SLACK_BOT_TOKEN
    if ([string]::IsNullOrWhiteSpace($slackToken)) { throw "SLACK_BOT_TOKEN not found in .env" }

    # Conversations
    $cursor = $null
    do {
        $params = @{ types = "public_channel,private_channel"; limit = 200 }
        if ($cursor) { $params.cursor = $cursor }
        $resp = Invoke-SlackApi -Method "conversations.list" -Params $params -Token $slackToken
        foreach ($c in $resp.channels) {
            $discovery.channels += [pscustomobject]@{
                id          = $c.id
                name        = $c.name
                is_private  = [bool]$c.is_private
                created     = $c.created
                num_members = $c.num_members
            }
        }
        $cursor = $resp.response_metadata.next_cursor
    } while ($cursor)

    # Users
    $uCursor = $null
    do {
        $params = @{ limit = 200 }
        if ($uCursor) { $params.cursor = $uCursor }
        $resp = Invoke-SlackApi -Method "users.list" -Params $params -Token $slackToken
        foreach ($u in $resp.members) {
            $email = $null
            if ($u.profile -and $u.profile.email) { $email = $u.profile.email }
            $discovery.users += [pscustomobject]@{
                id           = $u.id
                name         = $u.real_name
                displayName  = $u.profile.display_name
                email        = $email
                is_bot       = [bool]$u.is_bot
                deleted      = [bool]$u.deleted
            }
        }
        $uCursor = $resp.response_metadata.next_cursor
    } while ($uCursor)
    Write-Log "Live discovery complete: $($discovery.channels.Count) channels, $($discovery.users.Count) users" "INFO"
}
else {
    $datasetPath = Get-ConfigValue -Cfg $config.App -Path "Paths.Dataset" -Default (Join-Path $solutionRoot "Dataset\Default")
    if (-not (Test-Path $datasetPath)) { throw "Dataset path not found: $datasetPath" }

    $usersFile = Join-Path $datasetPath "users.json"
    if (Test-Path $usersFile) {
        $users = Get-Content $usersFile | ConvertFrom-Json
        foreach ($u in $users) {
            $discovery.users += [pscustomobject]@{
                id           = $u.id
                name         = $u.real_name
                displayName  = $u.profile.display_name
                email        = $u.profile.email
                is_bot       = [bool]$u.is_bot
                deleted      = [bool]$u.deleted
            }
        }
    }

    $channelsRoot = Join-Path $datasetPath "channels"
    if (-not (Test-Path $channelsRoot)) { throw "Offline dataset missing 'channels' folder: $channelsRoot" }
    Get-ChildItem -Path $channelsRoot -Directory | ForEach-Object {
        $discovery.channels += [pscustomobject]@{
            id          = $_.Name # offline surrogate id
            name        = $_.Name
            is_private  = $false
            created     = $null
            num_members = $null
        }
    }
    Write-Log "Offline discovery complete: $($discovery.channels.Count) channels, $($discovery.users.Count) users" "INFO"
}

$discoveryFile = Join-Path $reportsDir "discovery.json"
$discovery | ConvertTo-Json -Depth 6 | Set-Content -Path $discoveryFile -Encoding UTF8
Write-Log "Discovery written to $discoveryFile" "INFO"
Write-Log "Phase 0 complete" "INFO"
'@

# --------------------------
# Phase 1: Parse
# --------------------------
$phase1 = @'
param()
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"

function Ensure-Dir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }

function Get-ConfigValue {
    param([object]$Cfg,[string]$Path,[object]$Default=$null)
    $parts = $Path -split "\."
    $cur = $Cfg
    foreach ($p in $parts) {
        if ($null -eq $cur) { return $Default }
        if ($cur -is [System.Collections.IDictionary] -and $cur.Contains($p)) { $cur = $cur[$p]; continue }
        $cur = $cur | Select-Object -ExpandProperty $p -ErrorAction SilentlyContinue
    }
    if ($null -eq $cur) { return $Default } else { return $cur }
}

function HtmlEscape([string]$s) {
    if ($null -eq $s) { return "" }
    $s = $s -replace '&','&amp;'
    $s = $s -replace '<','&lt;'
    $s = $s -replace '>','&gt;'
    $s = $s -replace '"','&quot;'
    $s = $s -replace "'","&#39;"
    return $s
}

function SlackToHtml([string]$text) {
    $t = HtmlEscape $text
    # bold/italic/strike/code
    $t = $t -replace '\*(.+?)\*','<strong>$1</strong>'
    $t = $t -replace '_(.+?)_','<em>$1</em>'
    $t = $t -replace '~(.+?)~','<del>$1</del>'
    $t = $t -replace '`(.+?)`','<code>$1</code>'
    # links <url|text> and <url>
    $t = $t -replace '&lt;(https?://[^|&]+)\|([^&]+)&gt;','<a href="$1">$2</a>'
    $t = $t -replace '&lt;(https?://[^&]+)&gt;','<a href="$1">$1</a>'
    # line breaks
    $t = $t -replace "\\n","<br/>"
    return "<p>$t</p>"
}

function Invoke-SlackApi {
    param(
        [string]$Method,
        [hashtable]$Params,
        [string]$Token
    )
    $uri = "https://slack.com/api/$Method"
    $headers = @{ Authorization = "Bearer $Token" }
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $Params -ContentType 'application/x-www-form-urlencoded'
    if (-not $resp.ok) {
        throw "Slack API $Method failed: $($resp.error)"
    }
    return $resp
}

function Get-UnixSeconds([datetime]$dt) {
    return [int][Math]::Floor(($dt.ToUniversalTime() - [datetime]'1970-01-01Z').TotalSeconds)
}

Write-Log "Starting Phase 1: Parse" "INFO"
$config = Get-Config
$solutionRoot = (Resolve-Path "$PSScriptRoot\..").Path
$reportsDir = Join-Path $solutionRoot "Output\Reports"
$downloadsDir = Join-Path $solutionRoot "Output\Downloads"
Ensure-Dir $reportsDir
Ensure-Dir $downloadsDir

$discoveryFile = Join-Path $reportsDir "discovery.json"
if (-not (Test-Path $discoveryFile)) { throw "Discovery file not found. Run Phase 0 first." }
$discovery = Get-Content $discoveryFile | ConvertFrom-Json

$executionMode = $discovery.mode
$start = $null; $end = $null
if ($config.App.DateRange) {
    if ($config.App.DateRange.Start) { $start = [datetime]::Parse($config.App.DateRange.Start) }
    if ($config.App.DateRange.End)   { $end   = [datetime]::Parse($config.App.DateRange.End) }
}
$oldest = if ($start) { [string](Get-UnixSeconds $start) } else { $null }
$latest = if ($end)   { [string](Get-UnixSeconds ($end.Date.AddDays(1).AddSeconds(-1))) } else { $null }

$result = [ordered]@{
    ts       = (Get-Date).ToString("o")
    channels = @()
}

if ($executionMode -eq 'Live') {
    $slackToken = $config.Env.SLACK_BOT_TOKEN
    if ([string]::IsNullOrWhiteSpace($slackToken)) { throw "SLACK_BOT_TOKEN not found in .env" }

    foreach ($ch in $discovery.channels) {
        $messages = New-Object System.Collections.Generic.List[object]
        $cursor = $null
        do {
            $params = @{ channel = $ch.id; limit = 200 }
            if ($oldest) { $params.oldest = $oldest }
            if ($latest) { $params.latest = $latest }
            if ($cursor) { $params.cursor = $cursor }
            $resp = Invoke-SlackApi -Method "conversations.history" -Params $params -Token $slackToken
            foreach ($m in $resp.messages) {
                if ($m.subtype -and $m.subtype -ne "") { continue } # skip system subtypes
                $files = @()
                if ($m.files) {
                    foreach ($f in $m.files) {
                        $files += [pscustomobject]@{
                            id          = $f.id
                            name        = $f.name
                            mimetype    = $f.mimetype
                            size        = $f.size
                            url_private = $f.url_private
                        }
                    }
                }
                $messages.Add([pscustomobject]@{
                    ts     = $m.ts
                    user   = $m.user
                    text   = $m.text
                    html   = (SlackToHtml $m.text)
                    files  = $files
                    thread = $m.thread_ts
                })
            }
            $cursor = $resp.response_metadata.next_cursor
        } while ($cursor)
        $result.channels += [pscustomobject]@{
            id       = $ch.id
            name     = $ch.name
            messages = $messages
        }
        Write-Log "Parsed live channel '$($ch.name)' with $($messages.Count) messages" "INFO"
    }
}
else {
    $datasetPath = $config.App.Paths.Dataset
    $channelsRoot = Join-Path $datasetPath "channels"
    foreach ($dir in Get-ChildItem -Path $channelsRoot -Directory) {
        $allMsgs = New-Object System.Collections.Generic.List[object]
        foreach ($file in Get-ChildItem -Path $dir.FullName -Filter "*.json") {
            $dayMsgs = Get-Content $file.FullName | ConvertFrom-Json
            foreach ($m in $dayMsgs) {
                if ($m.subtype -and $m.subtype -ne "") { continue }
                $tsDate = (Get-Date "1970-01-01Z").AddSeconds([double]$m.ts)
                if ($start -and $tsDate -lt $start) { continue }
                if ($end -and $tsDate -gt $end) { continue }
                $files = @()
                if ($m.files) {
                    foreach ($f in $m.files) {
                        $files += [pscustomobject]@{
                            id          = $f.id
                            name        = $f.name
                            mimetype    = $f.mimetype
                            size        = $f.size
                            url_private = $f.url_private
                            local_path  = if ($f.local_path) { $f.local_path } else { $null }
                        }
                    }
                }
                $allMsgs.Add([pscustomobject]@{
                    ts     = $m.ts
                    user   = $m.user
                    text   = $m.text
                    html   = (SlackToHtml $m.text)
                    files  = $files
                    thread = $m.thread_ts
                })
            }
        }
        $result.channels += [pscustomobject]@{
            id       = $dir.Name
            name     = $dir.Name
            messages = $allMsgs
        }
        Write-Log "Parsed offline channel '$($dir.Name)' with $($allMsgs.Count) messages" "INFO"
    }
}

$parsedFile = Join-Path $reportsDir "parsed.json"
$result | ConvertTo-Json -Depth 10 | Set-Content -Path $parsedFile -Encoding UTF8
Write-Log "Parsed messages written to $parsedFile" "INFO"
Write-Log "Phase 1 complete" "INFO"
'@

# --------------------------
# Phase 2: Map Users
# --------------------------
$phase2 = @'
param()
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"

function Ensure-Dir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }

function Get-GraphToken {
    param([string]$TenantId,[string]$ClientId,[string]$ClientSecret)
    $uri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "application/x-www-form-urlencoded"
    return $resp.access_token
}

function Get-GraphUserByEmail {
    param([string]$Token,[string]$Email)
    $f = [Uri]::EscapeDataString($Email)
    $uri = "https://graph.microsoft.com/v1.0/users`?$filter=mail eq '$f' or userPrincipalName eq '$f'"
    $headers = @{ Authorization = "Bearer $Token" }
    $resp = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    if ($resp.value.Count -gt 0) { return $resp.value[0] }
    return $null
}

Write-Log "Starting Phase 2: Map Users" "INFO"
$config = Get-Config
$solutionRoot = (Resolve-Path "$PSScriptRoot\..").Path
$reportsDir = Join-Path $solutionRoot "Output\Reports"
Ensure-Dir $reportsDir

$discoveryFile = Join-Path $reportsDir "discovery.json"
if (-not (Test-Path $discoveryFile)) { throw "Discovery file not found. Run Phase 0 first." }
$discovery = Get-Content $discoveryFile | ConvertFrom-Json

$tenant = $config.Env.GRAPH_TENANT_ID
$clientId = $config.Env.GRAPH_CLIENT_ID
$clientSecret = $config.Env.GRAPH_CLIENT_SECRET
if ([string]::IsNullOrWhiteSpace($tenant) -or [string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
    throw "Graph credentials missing in .env (GRAPH_TENANT_ID, GRAPH_CLIENT_ID, GRAPH_CLIENT_SECRET)"
}
$token = Get-GraphToken -TenantId $tenant -ClientId $clientId -ClientSecret $clientSecret

$mapping = New-Object System.Collections.Generic.List[object]
foreach ($u in $discovery.users) {
    $email = $u.email
    $graphUser = $null
    if ($email) {
        try { $graphUser = Get-GraphUserByEmail -Token $token -Email $email } catch { Write-Log "Graph lookup failed for $email: $($_.Exception.Message)" "WARN" }
    }
    $mapping.Add([pscustomobject]@{
        slackUserId   = $u.id
        slackName     = $u.name
        slackEmail    = $email
        graphUserId   = if ($graphUser) { $graphUser.id } else { $null }
        graphUPN      = if ($graphUser) { $graphUser.userPrincipalName } else { $null }
        graphName     = if ($graphUser) { $graphUser.displayName } else { $null }
        matched       = [bool]($null -ne $graphUser)
    })
}

$mapFile = Join-Path $reportsDir "userMapping.json"
$mapping | ConvertTo-Json -Depth 5 | Set-Content -Path $mapFile -Encoding UTF8
Write-Log "User mapping written to $mapFile. Matched: $(@($mapping | Where-Object {$_.matched}).Count) / $(@($mapping).Count)" "INFO"
Write-Log "Phase 2 complete" "INFO"
'@

# --------------------------
# Phase 3: Create Teams & Channels
# --------------------------
$phase3 = @'
param()
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"

function Ensure-Dir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }

function Get-GraphToken {
    param([string]$TenantId,[string]$ClientId,[string]$ClientSecret)
    $uri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "application/x-www-form-urlencoded"
    return $resp.access_token
}

function New-Team {
    param([string]$Token,[string]$DisplayName,[string]$Description)
    $uri = "https://graph.microsoft.com/v1.0/teams"
    $headers = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }
    $body = @{
        "template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('standard')"
        displayName = $DisplayName
        description = $Description
    } | ConvertTo-Json
    $resp = Invoke-WebRequest -Method Post -Uri $uri -Headers $headers -Body $body -UseBasicParsing -ErrorAction Stop
    if ($resp.StatusCode -ne 202) { throw "Team creation did not return 202. Status: $($resp.StatusCode)" }
    $monitor = $resp.Headers.Location
    for ($i=0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 5
        $statusResp = Invoke-WebRequest -Method Get -Uri $monitor -Headers @{ Authorization = "Bearer $Token" } -UseBasicParsing
        if ($statusResp.StatusCode -eq 200 -or $statusResp.StatusCode -eq 201) {
            $json = ($statusResp.Content | ConvertFrom-Json)
            return $json.id
        }
        if ($statusResp.StatusCode -eq 202) { continue }
    }
    throw "Timed out waiting for team provisioning."
}

function New-Channel {
    param([string]$Token,[string]$TeamId,[string]$DisplayName,[string]$Description="")
    if ($DisplayName -match '^(?i)General$') { return $null } # General exists
    $uri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels"
    $headers = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }
    $body = @{ displayName = $DisplayName; description = $Description } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body
        return $resp.id
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 409) {
            # Already exists; find it
            $list = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $Token" }
            $match = $list.value | Where-Object { $_.displayName -eq $DisplayName }
            if ($match) { return $match.id }
        }
        throw
    }
}

Write-Log "Starting Phase 3: Create Teams & Channels" "INFO"
$config = Get-Config
$solutionRoot = (Resolve-Path "$PSScriptRoot\..").Path
$reportsDir = Join-Path $solutionRoot "Output\Reports"
Ensure-Dir $reportsDir

$discoveryFile = Join-Path $reportsDir "discovery.json"
$parsedFile    = Join-Path $reportsDir "parsed.json"
if (-not (Test-Path $discoveryFile) -or -not (Test-Path $parsedFile)) { throw "Required inputs missing. Run Phases 0 and 1 first." }
$discovery = Get-Content $discoveryFile | ConvertFrom-Json
$parsed    = Get-Content $parsedFile    | ConvertFrom-Json

$tenant = $config.Env.GRAPH_TENANT_ID
$clientId = $config.Env.GRAPH_CLIENT_ID
$clientSecret = $config.Env.GRAPH_CLIENT_SECRET
if ([string]::IsNullOrWhiteSpace($tenant) -or [string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
    throw "Graph credentials missing in .env"
}
$token = Get-GraphToken -TenantId $tenant -ClientId $clientId -ClientSecret $clientSecret

$targetTeamName = if ($config.App.TargetTeamName) { [string]$config.App.TargetTeamName } else { "Slack Import " + (Get-Date).ToString("yyyy-MM-dd HH:mm") }
$targetTeamId = $null

if ($config.App.TargetTeamId) {
    $targetTeamId = [string]$config.App.TargetTeamId
    Write-Log "Using existing Team Id: $targetTeamId" "INFO"
} else {
    Write-Log "Creating new Team: $targetTeamName" "INFO"
    $targetTeamId = New-Team -Token $token -DisplayName $targetTeamName -Description "Imported from Slack"
    Write-Log "Created Team '$targetTeamName' with Id $targetTeamId" "INFO"
}

# Ensure channels
$channelMap = New-Object System.Collections.Generic.List[object]
foreach ($ch in $parsed.channels) {
    $display = $ch.name
    $chanId = New-Channel -Token $token -TeamId $targetTeamId -DisplayName $display -Description ("Imported from Slack channel " + $display)
    if ($null -eq $chanId -and $display -match '^(?i)General$') {
        # fetch General id
        $list = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/v1.0/teams/$targetTeamId/channels") -Headers @{ Authorization = "Bearer $token" }
        $general = $list.value | Where-Object { $_.displayName -match '^(?i)General$' }
        if ($general) { $chanId = $general.id }
    }
    if ($null -eq $chanId) { Write-Log "Could not ensure channel '$display' (skipped or missing)." "WARN" }
    else {
        $channelMap.Add([pscustomobject]@{
            slackChannelName = $display
            teamsChannelId   = $chanId
            teamsChannelName = $display
        })
        Write-Log "Ensured channel '$display' => $chanId" "INFO"
    }
}

$output = [pscustomobject]@{
    teamId   = $targetTeamId
    channels = $channelMap
    ts       = (Get-Date).ToString("o")
}
$outFile = Join-Path $reportsDir "teamAndChannels.json"
$output | ConvertTo-Json -Depth 8 | Set-Content -Path $outFile -Encoding UTF8
Write-Log "Team and channel mapping written to $outFile" "INFO"
Write-Log "Phase 3 complete" "INFO"
'@

# --------------------------
# Phase 4: Post Messages
# --------------------------
$phase4 = @'
param()
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\Shared\Shared-Logging.ps1"
. "$PSScriptRoot\..\Shared\Shared-Config.ps1"

function Ensure-Dir([string]$p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null } }

function HtmlEscape([string]$s) {
    if ($null -eq $s) { return "" }
    $s = $s -replace '&','&amp;'
    $s = $s -replace '<','&lt;'
    $s = $s -replace '>','&gt;'
    $s = $s -replace '"','&quot;'
    $s = $s -replace "'","&#39;"
    return $s
}

function Get-GraphToken {
    param([string]$TenantId,[string]$ClientId,[string]$ClientSecret)
    $uri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }
    $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType "application/x-www-form-urlencoded"
    return $resp.access_token
}

function Post-Message {
    param([string]$Token,[string]$TeamId,[string]$ChannelId,[string]$HtmlContent)
    $uri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/messages"
    $headers = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }
    $body = @{
        body = @{
            contentType = "html"
            content     = $HtmlContent
        }
    } | ConvertTo-Json -Depth 6
    $try = 0
    while ($true) {
        try {
            $resp = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body
            return $resp.id
        } catch {
            $try++
            $code = try { $_.Exception.Response.StatusCode.value__ } catch { 0 }
            if ($try -le 5 -and ($code -eq 429 -or $code -ge 500)) {
                Start-Sleep -Seconds ([Math]::Min(30, [Math]::Pow(2,$try)))
                continue
            }
            throw
        }
    }
}

Write-Log "Starting Phase 4: Post Messages" "INFO"
$config = Get-Config
$solutionRoot = (Resolve-Path "$PSScriptRoot\..").Path
$reportsDir = Join-Path $solutionRoot "Output\Reports"
Ensure-Dir $reportsDir

$parsedFile    = Join-Path $reportsDir "parsed.json"
$mapFile       = Join-Path $reportsDir "userMapping.json"
$teamChFile    = Join-Path $reportsDir "teamAndChannels.json"
if (-not (Test-Path $parsedFile) -or -not (Test-Path $teamChFile)) { throw "Required inputs missing. Run Phases 1 and 3 first." }
$parsed    = Get-Content $parsedFile    | ConvertFrom-Json
$userMap   = if (Test-Path $mapFile) { Get-Content $mapFile | ConvertFrom-Json } else { @() }
$teamAndCh = Get-Content $teamChFile | ConvertFrom-Json

$tenant = $config.Env.GRAPH_TENANT_ID
$clientId = $config.Env.GRAPH_CLIENT_ID
$clientSecret = $config.Env.GRAPH_CLIENT_SECRET
$token = Get-GraphToken -TenantId $tenant -ClientId $clientId -ClientSecret $clientSecret

$skipChannels = @()
if ($config.App.SkipRules -and $config.App.SkipRules.Channels) { $skipChannels = @($config.App.SkipRules.Channels) }

$posted = 0; $failed = 0
$perChannel = @()

foreach ($ch in $parsed.channels) {
    if ($skipChannels -contains $ch.name) {
        Write-Log "Skipping channel by rule: $($ch.name)" "WARN"
        continue
    }
    $mapping = $teamAndCh.channels | Where-Object { $_.slackChannelName -eq $ch.name } | Select-Object -First 1
    if (-not $mapping) {
        Write-Log "No Teams channel mapping for '$($ch.name)'; skipping" "WARN"
        continue
    }
    $countPosted = 0; $countFailed = 0
    foreach ($m in $ch.messages) {
        $author = $m.user
        $userRec = $userMap | Where-Object { $_.slackUserId -eq $author } | Select-Object -First 1
        $authorName = if ($userRec -and $userRec.graphName) { $userRec.graphName } elseif ($userRec -and $userRec.slackEmail) { $userRec.slackEmail } else { $author }
        $tsDate = (Get-Date "1970-01-01Z").AddSeconds([double]$m.ts)
        $prefix = "<p><strong>$(HtmlEscape $authorName)</strong> <span style='color:#666'>(Slack, $($tsDate.ToString("u")))</span></p>"
        $content = $prefix + $m.html
        try {
            [void](Post-Message -Token $token -TeamId $teamAndCh.teamId -ChannelId $mapping.teamsChannelId -HtmlContent $content)
            $posted++; $countPosted++
        } catch {
            $failed++; $countFailed++
            Write-Log "Failed to post message in '$($ch.name)': $($_.Exception.Message)" "ERROR"
        }
    }
    $perChannel += [pscustomobject]@{
        channel = $ch.name
        posted  = $countPosted
        failed  = $countFailed
    }
    Write-Log "Posted $countPosted messages to '$($ch.name)' ($countFailed failed)" "INFO"
}

$out = [pscustomobject]@{
    ts         = (Get-Date).ToString("o")
    totals     = @{ posted = $posted; failed = $failed }
    perChannel = $perChannel
}
$outFile = Join-Path $reportsDir "posting.json"
$out | ConvertTo-Json -Depth 6 | Set-Content -Path $outFile -Encoding UTF8
Write-Log "Posting summary written to $outFile" "INFO"
Write-Log "Phase 4 complete" "INFO"
'@

# Write all phases 0–4
Write-PhaseFile -Name 'Phase0-Discovery.ps1'              -Body $phase0
Write-PhaseFile -Name 'Phase1-Parse.ps1'                   -Body $phase1
Write-PhaseFile -Name 'Phase2-MapUsers.ps1'                -Body $phase2
Write-PhaseFile -Name 'Phase3-CreateTeamsAndChannels.ps1'  -Body $phase3
Write-PhaseFile -Name 'Phase4-PostMessages.ps1'            -Body $phase4

Write-Host "`nPhases 0–4 created successfully." -ForegroundColor Green