#Requires -Version 5.1
Set-StrictMode -Version Latest

$Global:LogConfig = @{
  LogDirectory = (Join-Path (Get-Location) 'Logs')
  LogFile      = $null
}

function Initialize-Logging {
  param(
    [string]$LogDirectory
  )
  if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory | Out-Null
  }
  $date = Get-Date -Format 'yyyyMMdd_HHmmss'
  $Global:LogConfig.LogDirectory = $LogDirectory
  $Global:LogConfig.LogFile = Join-Path $LogDirectory "run_$date.log"
  "[$(Get-Date -Format o)] [INFO] Logging initialized -> $($Global:LogConfig.LogFile)" | Out-File -FilePath $Global:LogConfig.LogFile -Encoding utf8
}

function Write-Log {
  param(
    [ValidateSet('Trace','Debug','Info','Warn','Error')]
    [string]$Level = 'Info',
    [Parameter(Mandatory=$true)][string]$Message,
    [string]$Context
  )
  $ts = Get-Date -Format o
  $prefix = "[$ts] [$Level]"
  if ($Context) { $prefix = "$prefix [$Context]" }
  $line = "$prefix $Message"
  if ($Level -in @('Error','Warn')) {
    Write-Host $line -ForegroundColor Red
  } elseif ($Level -eq 'Info') {
    Write-Host $line -ForegroundColor Green
  } else {
    Write-Host $line -ForegroundColor Gray
  }
  if ($Global:LogConfig.LogFile) {
    $line | Out-File -FilePath $Global:LogConfig.LogFile -Append -Encoding utf8
  }
}

Export-ModuleMember -Function Initialize-Logging, Write-Log
