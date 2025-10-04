#Requires -Version 5.1
Set-StrictMode -Version Latest
. "$PSScriptRoot\Shared-Logging.ps1"
. "$PSScriptRoot\Shared-Config.ps1"
. "$PSScriptRoot\Shared-Retry.ps1"

$Global:GraphToken = $null
$Global:GraphTokenExpiry = Get-Date

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

function Invoke-GraphRequest {
  param(
    [Parameter(Mandatory=$true)][string]$Method,
    [Parameter(Mandatory=$true)][string]$Uri,
    [hashtable]$Headers,
    $Body
  )
  $headers = Get-GraphAuthHeader
  if ($Headers) { $Headers.Keys | ForEach-Object { $headers[$_] = $Headers[$_] } }
  $sb = {
    param($Method, $Uri, $Headers, $Body)
    if ($Body -and ($Method -in 'POST','PATCH','PUT')) {
      Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body ($Body | ConvertTo-Json -Depth 50) -ContentType 'application/json'
    } else {
      Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
    }
  }
  Invoke-WithRetry -ScriptBlock { & $sb $Method $Uri $headers $Body } -MaxAttempts 5 -InitialDelayMs (Get-Config 'Graph.RateLimitPauseMs' 2000) -Context "Graph:$Method $Uri"
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

Export-ModuleMember -Function Connect-Graph, Invoke-GraphRequest, Find-AadUserByEmail, New-Team, New-TeamChannel, Add-TeamMember, Post-ChannelMessage, Get-TeamDrive, Upload-FileToChannel
