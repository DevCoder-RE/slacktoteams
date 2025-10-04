#Requires -Version 5.1
Set-StrictMode -Version Latest

function Read-JsonFile {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path $Path)) { throw "JSON file not found: $Path" }
  $raw = Get-Content -Path $Path -Raw -Encoding UTF8
  return $raw | ConvertFrom-Json -Depth 100
}

function Write-JsonFile {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)]$Object
  )
  $json = $Object | ConvertTo-Json -Depth 100
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Set-Content -Path $Path -Value $json -Encoding UTF8
}

Export-ModuleMember -Function Read-JsonFile, Write-JsonFile
