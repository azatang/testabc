param(
  [string]$HooksDir = "$env:USERPROFILE\.githooks",
  [switch]$KeepFiles
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git command not found. Please install Git for Windows first."
}

# Remove global hooksPath override
& git config --global --unset core.hooksPath 2>$null
Write-Info "Unset git global core.hooksPath"

$hooksDirFull = [System.IO.Path]::GetFullPath($HooksDir)
if (-not $KeepFiles -and (Test-Path $hooksDirFull)) {
  Remove-Item -Recurse -Force $hooksDirFull
  Write-Info "Removed hooks directory: $hooksDirFull"
} elseif (Test-Path $hooksDirFull) {
  Write-Info "Kept hooks directory: $hooksDirFull"
}

Write-Info "Done."
