#Requires -Version 5.1
Set-StrictMode -Version Latest
. "$PSScriptRoot\Shared-Logging.ps1"
. "$PSScriptRoot\Shared-Config.ps1"

# Circuit breaker state
$Global:CircuitBreakerState = @{
  Failures = 0
  LastFailureTime = $null
  State = 'Closed'  # Closed, Open, HalfOpen
}

function Invoke-WithRetry {
  param(
    [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
    [int]$MaxAttempts = 5,
    [int]$InitialDelayMs = 500,
    [double]$BackoffFactor = 2.0,
    [string]$Context = "Retry",
    [switch]$UseCircuitBreaker,
    [int]$CircuitBreakerThreshold = 5,
    [int]$CircuitBreakerTimeoutMs = 60000
  )

  # Check circuit breaker
  if ($UseCircuitBreaker) {
    if ($Global:CircuitBreakerState.State -eq 'Open') {
      if ((Get-Date) - $Global:CircuitBreakerState.LastFailureTime -lt [TimeSpan]::FromMilliseconds($CircuitBreakerTimeoutMs)) {
        Write-Log -Level Warn -Message "Circuit breaker is OPEN. Failing fast." -Context $Context
        throw "Circuit breaker is open"
      } else {
        Write-Log -Level Info -Message "Circuit breaker timeout elapsed. Attempting to close." -Context $Context
        $Global:CircuitBreakerState.State = 'HalfOpen'
      }
    }
  }

  $attempt = 0
  $delay = $InitialDelayMs
  while ($attempt -lt $MaxAttempts) {
    try {
      $result = & $ScriptBlock

      # Success - reset circuit breaker
      if ($UseCircuitBreaker -and $Global:CircuitBreakerState.State -eq 'HalfOpen') {
        Write-Log -Level Info -Message "Circuit breaker reset to CLOSED." -Context $Context
        $Global:CircuitBreakerState.State = 'Closed'
        $Global:CircuitBreakerState.Failures = 0
      }

      return $result
    } catch {
      $attempt++
      $isRateLimit = $_.Exception.Message -match '429|Too Many Requests|rate limit'

      if ($attempt -ge $MaxAttempts) {
        # Update circuit breaker on final failure
        if ($UseCircuitBreaker) {
          $Global:CircuitBreakerState.Failures++
          if ($Global:CircuitBreakerState.Failures -ge $CircuitBreakerThreshold) {
            $Global:CircuitBreakerState.State = 'Open'
            $Global:CircuitBreakerState.LastFailureTime = Get-Date
            Write-Log -Level Error -Message "Circuit breaker OPENED after $CircuitBreakerThreshold failures." -Context $Context
          }
        }
        Write-Log -Level Error -Message "Failed after $attempt attempts: $($_.Exception.Message)" -Context $Context
        throw
      }

      # Adaptive delay for rate limits
      if ($isRateLimit) {
        $delay = [math]::Max($delay * 2, 5000)  # Minimum 5 seconds for rate limits
        Write-Log -Level Warn -Message "Rate limit detected. Increasing delay to $delay ms." -Context $Context
      } else {
        $delay = [int]($delay * $BackoffFactor)
      }

      Write-Log -Level Warn -Message "Attempt $attempt failed: $($_.Exception.Message). Retrying in $delay ms..." -Context $Context
      Start-Sleep -Milliseconds $delay
    }
  }
}

function Get-RetryPolicy {
  param([string]$OperationType = 'default')
  $policies = Get-Config 'Retry.Policies' @{
    default = @{
      MaxAttempts = 5
      InitialDelayMs = 500
      BackoffFactor = 2.0
      UseCircuitBreaker = $false
    }
    api = @{
      MaxAttempts = 3
      InitialDelayMs = 1000
      BackoffFactor = 1.5
      UseCircuitBreaker = $true
      CircuitBreakerThreshold = 5
      CircuitBreakerTimeoutMs = 60000
    }
    file = @{
      MaxAttempts = 3
      InitialDelayMs = 2000
      BackoffFactor = 2.0
      UseCircuitBreaker = $false
    }
  }
  return $policies[$OperationType] ?? $policies['default']
}

function Invoke-WithRetryPolicy {
  param(
    [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
    [string]$OperationType = 'default',
    [string]$Context = "Retry"
  )
  $policy = Get-RetryPolicy -OperationType $OperationType
  Invoke-WithRetry -ScriptBlock $ScriptBlock -MaxAttempts $policy.MaxAttempts -InitialDelayMs $policy.InitialDelayMs -BackoffFactor $policy.BackoffFactor -Context $Context -UseCircuitBreaker:$policy.UseCircuitBreaker -CircuitBreakerThreshold $policy.CircuitBreakerThreshold -CircuitBreakerTimeoutMs $policy.CircuitBreakerTimeoutMs
}

Export-ModuleMember -Function Invoke-WithRetry, Invoke-WithRetryPolicy, Get-RetryPolicy
