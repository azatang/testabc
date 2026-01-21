param(
  [string]$HooksDir = "$env:USERPROFILE\.githooks",
  [string[]]$BlockedSubstrings = @('github.com', 'ssh.github.com', 'gist.github.com'),
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git command not found. Please install Git for Windows first."
}

$hooksDirFull = [System.IO.Path]::GetFullPath($HooksDir)
$prePushPath = Join-Path $hooksDirFull 'pre-push'

if (-not (Test-Path $hooksDirFull)) {
  New-Item -ItemType Directory -Path $hooksDirFull | Out-Null
}

# Build a POSIX-shell case pattern like: *github.com*|*ssh.github.com*|*gist.github.com*
$blockedCasePattern = ($BlockedSubstrings | ForEach-Object { "*$_*" }) -join '|'

$hook = @'
#!/bin/sh
# Blocks pushing code to GitHub remotes.
# Note: This does not block GitHub login or Copilot network usage.

remote_name="$1"
remote_url="$2"

if [ -z "$remote_url" ] && [ -n "$remote_name" ]; then
  remote_url=$(git remote get-url "$remote_name" 2>/dev/null)
fi

case "$remote_url" in
  __BLOCKED_CASE_PATTERN__)
    echo "ERROR: git push blocked by local policy: $remote_name ($remote_url)" 1>&2
    echo "       This machine is configured to prevent uploading code to GitHub." 1>&2
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
'@

$hook = $hook.Replace('__BLOCKED_CASE_PATTERN__', $blockedCasePattern)

if ((Test-Path $prePushPath) -and (-not $Force)) {
  throw "Hook already exists at '$prePushPath'. Re-run with -Force to overwrite."
}

# Write the hook with LF endings
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($prePushPath, ($hook -replace "`r`n","`n"), $utf8NoBom)

Write-Info "Wrote pre-push hook: $prePushPath"

# Configure git to use this hooks directory globally
& git config --global core.hooksPath $hooksDirFull
Write-Info "Configured git global core.hooksPath = $hooksDirFull"

Write-Warn "This blocks only 'git push' to GitHub remotes. It does not prevent other upload paths."
Write-Info "Done."
