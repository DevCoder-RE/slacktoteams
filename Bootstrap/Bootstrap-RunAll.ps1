[CmdletBinding()]
param(
    [string]$ProjectRoot = "."
)

$phases = Get-ChildItem -Path (Join-Path $ProjectRoot "Phases") -Filter "Phase*.ps1" | Sort-Object Name

foreach ($phase in $phases) {
    Write-Host "Running $($phase.Name)..."
    & $phase.FullName
}
