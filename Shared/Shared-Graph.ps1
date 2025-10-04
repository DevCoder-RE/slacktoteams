#Requires -Version 5.1
Set-StrictMode -Version Latest
. "$PSScriptRoot\Shared-Logging.ps1"
. "$PSScriptRoot\Shared-Config.ps1"
. "$PSScriptRoot\Shared-Retry.ps1"

$Global:GraphToken = $null
$Global:GraphTokenExpiry = Get-Date
$Global:RateLimitState = @{
  LastRequestTime = $null
  RequestCount = 0
  WindowStart = Get-Date
  AdaptiveDelayMs = 1000
  ConsecutiveErrors = 0
}

function Connect-Graph {
  param(
    [Parameter(Mandatory=$true)][string]$TenantId,
    [Parameter(Mandatory=$true)][string]$ClientId,
    [Parameter(Mandatory=$true)][string]$ClientSecret
  )
  $authority = "$(Get-Config 'Graph.Authority')/$TenantId/oauth2/v2.0/token"
  $scope = 'https://graph.microsoft.com/.default'
  $body = @{
    client_id     = $ClientId
    scope         = $scope
    client_secret = $ClientSecret
    grant_type    = 'client_credentials'
  }
  $resp = Invoke-RestMethod -Method Post -Uri $authority -Body $body -ContentType 'application/x-www-form-urlencoded'
  $Global:GraphToken = $resp.access_token
  $Global:GraphTokenExpiry = (Get-Date).AddSeconds([int]$resp.expires_in - 60)
  Write-Log -Level Info -Message "Connected to Microsoft Graph (app-only)." -Context "Graph"
}

function Get-GraphAuthHeader {
  if (-not $Global:GraphToken -or (Get-Date) -ge $Global:GraphTokenExpiry) {
    Connect-Graph -TenantId (Get-Config 'Graph.TenantId') -ClientId (Get-Config 'Graph.ClientId') -ClientSecret (Get-Config 'Graph.ClientSecret')
  }
  return @{ Authorization = "Bearer $Global:GraphToken" }
}

function Update-RateLimitState {
  param([int]$StatusCode, [hashtable]$Headers)
  $now = Get-Date
  $Global:RateLimitState.LastRequestTime = $now

  # Reset window if needed
  if (($now - $Global:RateLimitState.WindowStart).TotalMinutes -ge 1) {
    $Global:RateLimitState.WindowStart = $now
    $Global:RateLimitState.RequestCount = 0
  }

  $Global:RateLimitState.RequestCount++

  if ($StatusCode -eq 429) {
    $Global:RateLimitState.ConsecutiveErrors++
    $retryAfter = $Headers.'Retry-After' ?? '30'
    $Global:RateLimitState.AdaptiveDelayMs = [math]::Max($Global:RateLimitState.AdaptiveDelayMs * 1.5, [int]$retryAfter * 1000)
    Write-Log -Level Warn -Message "Rate limit hit. Adaptive delay increased to $($Global:RateLimitState.AdaptiveDelayMs)ms" -Context "RateLimit"
  } elseif ($StatusCode -ge 200 -and $StatusCode -lt 300) {
    $Global:RateLimitState.ConsecutiveErrors = 0
    # Gradually reduce delay on success
    $Global:RateLimitState.AdaptiveDelayMs = [math]::Max(1000, $Global:RateLimitState.AdaptiveDelayMs * 0.9)
  }
}

function Get-RateLimitDelay {
  $baseDelay = [int](Get-Config 'Graph.RateLimitPauseMs' 1000)
  $adaptiveDelay = $Global:RateLimitState.AdaptiveDelayMs

  # Calculate requests per minute
  $requestsPerMinute = $Global:RateLimitState.RequestCount / [math]::Max(1, (Get-Date - $Global:RateLimitState.WindowStart).TotalMinutes)

  # Increase delay if approaching limits
  if ($requestsPerMinute -gt 100) { # Assuming 100 req/min limit
    $adaptiveDelay = [math]::Min($adaptiveDelay * 2, 30000) # Max 30 seconds
  }

  return [math]::Max($baseDelay, $adaptiveDelay)
}

function Invoke-GraphRequest {
  param(
    [Parameter(Mandatory=$true)][string]$Method,
    [Parameter(Mandatory=$true)][string]$Uri,
    [hashtable]$Headers,
    $Body
  )

  # Rate limiting delay
  $delay = Get-RateLimitDelay
  if ($delay -gt 0) {
    Start-Sleep -Milliseconds $delay
  }

  $headers = Get-GraphAuthHeader
  if ($Headers) { $Headers.Keys | ForEach-Object { $headers[$_] = $Headers[$_] } }

  $sb = {
    param($Method, $Uri, $Headers, $Body)
    try {
      $response = if ($Body -and ($Method -in 'POST','PATCH','PUT')) {
        Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -Body ($Body | ConvertTo-Json -Depth 50) -ContentType 'application/json'
      } else {
        Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers
      }
      Update-RateLimitState -StatusCode $response.StatusCode -Headers $response.Headers
      return $response.Content | ConvertFrom-Json
    } catch [System.Net.WebException] {
      $webResponse = $_.Exception.Response
      if ($webResponse) {
        Update-RateLimitState -StatusCode [int]$webResponse.StatusCode -Headers $webResponse.Headers
      }
      throw
    }
  }

  Invoke-WithRetryPolicy -ScriptBlock { & $sb $Method $Uri $headers $Body } -OperationType 'api' -Context "Graph:$Method $Uri"
}

function Invoke-GraphBatchRequest {
  param(
    [Parameter(Mandatory=$true)][array]$Requests
  )
  $batchUri = "$(Get-Config 'Graph.BaseUrl')/\$batch"
  $batchBody = @{
    requests = $Requests
  }
  $headers = Get-GraphAuthHeader
  $sb = {
    param($BatchUri, $Headers, $BatchBody)
    Invoke-RestMethod -Method POST -Uri $BatchUri -Headers $Headers -Body ($BatchBody | ConvertTo-Json -Depth 10) -ContentType 'application/json'
  }
  Invoke-WithRetry -ScriptBlock { & $sb $batchUri $headers $batchBody } -MaxAttempts 3 -InitialDelayMs (Get-Config 'Graph.RateLimitPauseMs' 2000) -Context "Graph:Batch"
}

function New-BatchedTeamChannels {
  param(
    [Parameter(Mandatory=$true)][string]$TeamId,
    [Parameter(Mandatory=$true)][array]$ChannelNames,
    [string]$MembershipType='standard'
  )
  $requests = @()
  $id = 1
  foreach ($channelName in $ChannelNames) {
    $requests += @{
      id = $id.ToString()
      method = 'POST'
      url = "/teams/$TeamId/channels"
      headers = @{ 'Content-Type' = 'application/json' }
      body = @{
        displayName = $channelName
        membershipType = $MembershipType
      }
    }
    $id++
  }
  $batchResponse = Invoke-GraphBatchRequest -Requests $requests
  return $batchResponse.responses
}

function Add-BatchedTeamMembers {
  param(
    [Parameter(Mandatory=$true)][string]$TeamId,
    [Parameter(Mandatory=$true)][array]$UserIds,
    [string]$Role='member'
  )
  $requests = @()
  $id = 1
  foreach ($userId in $UserIds) {
    $requests += @{
      id = $id.ToString()
      method = 'POST'
      url = "/teams/$TeamId/members"
      headers = @{ 'Content-Type' = 'application/json' }
      body = @{
        '@odata.type' = '#microsoft.graph.aadUserConversationMember'
        roles = @($Role)
        'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$userId')"
      }
    }
    $id++
  }
  $batchResponse = Invoke-GraphBatchRequest -Requests $requests
  return $batchResponse.responses
}

function Send-BatchedChannelMessages {
  param(
    [Parameter(Mandatory=$true)][string]$TeamId,
    [Parameter(Mandatory=$true)][string]$ChannelId,
    [Parameter(Mandatory=$true)][array]$Messages
  )
  $requests = @()
  $id = 1
  foreach ($message in $Messages) {
    $requests += @{
      id = $id.ToString()
      method = 'POST'
      url = "/teams/$TeamId/channels/$ChannelId/messages"
      headers = @{ 'Content-Type' = 'application/json' }
      body = @{
        body = @{
          contentType = 'html'
          content = $message.Content
        }
      }
    }
    $id++
  }
  $batchResponse = Invoke-GraphBatchRequest -Requests $requests
  return $batchResponse.responses
}

function Find-AadUserByEmail {
  param([string]$Email)
  if (-not $Email) { return $null }
  $base = (Get-Config 'Graph.BaseUrl')
  $uri = "$base/users?\$filter=mail eq '$Email' or userPrincipalName eq '$Email'"
  try {
    $resp = Invoke-GraphRequest -Method GET -Uri $uri
    return $resp.value | Select-Object -First 1
  } catch {
    Write-Log -Level Warn -Message "User lookup failed for $Email: $($_.Exception.Message)" -Context "Graph"
    return $null
  }
}

function New-Team {
  param([Parameter(Mandatory=$true)][string]$DisplayName, [string]$Description = "")
  $uri = "$(Get-Config 'Graph.BaseUrl')/teams"
  $body = @{
    template@odata.bind = "https://graph.microsoft.com/v1.0/teamsTemplates('standard')"
    displayName = $DisplayName
    description = $Description
  }
  Invoke-GraphRequest -Method POST -Uri $uri -Body $body
}

function New-TeamChannel {
  param([Parameter(Mandatory=$true)][string]$TeamId,[Parameter(Mandatory=$true)][string]$DisplayName,[string]$MembershipType='standard')
  $uri = "$(Get-Config 'Graph.BaseUrl')/teams/$TeamId/channels"
  $body = @{
    displayName = $DisplayName
    membershipType = $MembershipType
  }
  Invoke-GraphRequest -Method POST -Uri $uri -Body $body
}

function Add-TeamMember {
  param([string]$TeamId,[string]$UserId,[string]$Role='member')
  $uri = "$(Get-Config 'Graph.BaseUrl')/teams/$TeamId/members"
  $body = @{
    '@odata.type' = '#microsoft.graph.aadUserConversationMember'
    roles = @($Role)
    'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$UserId')"
  }
  Invoke-GraphRequest -Method POST -Uri $uri -Body $body
}

function Post-ChannelMessage {
  param([string]$TeamId,[string]$ChannelId,[string]$Content)
  $uri = "$(Get-Config 'Graph.BaseUrl')/teams/$TeamId/channels/$ChannelId/messages"
  $body = @{
    body = @{
      contentType = 'html'
      content = $Content
    }
  }
  Invoke-GraphRequest -Method POST -Uri $uri -Body $body
}

function Reply-ChannelMessage {
  param([string]$TeamId,[string]$ChannelId,[string]$MessageId,[string]$Content)
  $uri = "$(Get-Config 'Graph.BaseUrl')/teams/$TeamId/channels/$ChannelId/messages/$MessageId/replies"
  $body = @{
    body = @{
      contentType = 'html'
      content = $Content
    }
  }
  Invoke-GraphRequest -Method POST -Uri $uri -Body $body
}

function Add-MessageReaction {
  param([string]$TeamId,[string]$ChannelId,[string]$MessageId,[string]$ReactionType)
  $uri = "$(Get-Config 'Graph.BaseUrl')/teams/$TeamId/channels/$ChannelId/messages/$MessageId/setReaction"
  $body = @{
    reactionType = $ReactionType
  }
  Invoke-GraphRequest -Method POST -Uri $uri -Body $body
}

function Get-TeamDrive {
  param([string]$TeamId)
  $uri = "$(Get-Config 'Graph.BaseUrl')/groups/$TeamId/drive"
  Invoke-GraphRequest -Method GET -Uri $uri
}

function Upload-FileToChannel {
  param([string]$TeamId,[string]$ChannelId,[string]$LocalPath,[string]$TargetFolder='Documents')
  # Resolve channel folder path
  $drive = Get-TeamDrive -TeamId $TeamId
  $fileName = [IO.Path]::GetFileName($LocalPath)
  $bytes = [System.IO.File]::ReadAllBytes($LocalPath)
  $uploadUri = "$(Get-Config 'Graph.BaseUrl')/groups/$TeamId/drive/root:/$TargetFolder/$fileName:/content"
  $headers = Get-GraphAuthHeader
  Invoke-WebRequest -Method Put -Uri $uploadUri -Headers $headers -InFile $LocalPath -ContentType "application/octet-stream" | Out-Null
  return "$TargetFolder/$fileName"
}

Export-ModuleMember -Function Connect-Graph, Invoke-GraphRequest, Invoke-GraphBatchRequest, Find-AadUserByEmail, New-Team, New-TeamChannel, New-BatchedTeamChannels, Add-TeamMember, Add-BatchedTeamMembers, Post-ChannelMessage, Reply-ChannelMessage, Add-MessageReaction, Send-BatchedChannelMessages, Get-TeamDrive, Upload-FileToChannel
