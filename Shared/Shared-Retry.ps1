#Requires -Version 5.1
Set-StrictMode -Version Latest
. "$PSScriptRoot\Shared-Logging.ps1"

function Invoke-WithRetry {
  param(
    [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
    [int]$MaxAttempts = 5,
    [int]$InitialDelayMs = 500,
    [double]$BackoffFactor = 2.0,
    [string]$Context = "Retry"
  )
  $attempt = 0
  $delay = $InitialDelayMs
  while ($attempt -lt $MaxAttempts) {
    try {
      return & $ScriptBlock
    } catch {
      $attempt++
      if ($attempt -ge $MaxAttempts) {
        Write-Log -Level Error -Message "Failed after $attempt attempts: $($_.Exception.Message)" -Context $Context
        throw
      }
      Write-Log -Level Warn -Message "Attempt $attempt failed: $($_.Exception.Message). Retrying in $delay ms..." -Context $Context
      Start-Sleep -Milliseconds $delay
      $delay = [int]($delay * $BackoffFactor)
    }
  }
}

Export-ModuleMember -Function Invoke-WithRetry
