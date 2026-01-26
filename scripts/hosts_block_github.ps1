#Requires -RunAsAdministrator
<#
.SYNOPSIS
  通过 hosts 文件阻止访问 GitHub（影响所有程序）
  
.DESCRIPTION
  将 github.com 相关域名指向 127.0.0.1，阻止所有程序访问。
  ⚠️ 警告：这会影响浏览器、Copilot、VS Code 等所有 GitHub 相关功能！
  
.PARAMETER Uninstall
  移除 hosts 文件中的阻止条目
#>

param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$marker = "# === BLOCK-GITHUB-PUSH ==="

$blockedDomains = @(
    "github.com",
    "www.github.com", 
    "api.github.com",
    "gist.github.com",
    "ssh.github.com",
    "git.github.com"
    # 注意：不阻止以下域名以保留 Copilot/登录功能
    # "copilot.github.com"
    # "github.githubassets.com"
)

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "请以管理员身份运行此脚本 (Run as Administrator)"
}

$hostsContent = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
if (-not $hostsContent) { $hostsContent = "" }

if ($Uninstall) {
    Write-Info "正在从 hosts 文件移除阻止条目..."
    
    # 移除标记之间的内容
    $pattern = "(?s)$([regex]::Escape($marker)).*?$([regex]::Escape($marker))"
    $newContent = $hostsContent -replace $pattern, ""
    $newContent = $newContent.Trim()
    
    Set-Content -Path $hostsPath -Value $newContent -Encoding ASCII
    
    # 刷新 DNS 缓存
    ipconfig /flushdns | Out-Null
    
    Write-Info "已移除阻止条目"
    Write-Info "Done."
    exit 0
}

# 检查是否已存在
if ($hostsContent -match [regex]::Escape($marker)) {
    Write-Warn "hosts 文件中已存在阻止条目，先移除旧条目..."
    $pattern = "(?s)$([regex]::Escape($marker)).*?$([regex]::Escape($marker))"
    $hostsContent = $hostsContent -replace $pattern, ""
    $hostsContent = $hostsContent.Trim()
}

# 构建阻止条目
$blockEntries = @($marker)
foreach ($domain in $blockedDomains) {
    $blockEntries += "127.0.0.1    $domain"
}
$blockEntries += $marker

$newContent = $hostsContent + "`n`n" + ($blockEntries -join "`n")

Write-Info "正在写入 hosts 文件..."
Set-Content -Path $hostsPath -Value $newContent -Encoding ASCII

# 刷新 DNS 缓存
ipconfig /flushdns | Out-Null

Write-Info "已添加以下阻止条目:"
$blockedDomains | ForEach-Object { Write-Host "  127.0.0.1 -> $_" }
Write-Host ""
Write-Warn "⚠️ 警告：这会阻止所有程序访问 GitHub，包括浏览器！"
Write-Host ""
Write-Info "卸载命令: .\hosts_block_github.ps1 -Uninstall"
Write-Info "Done."
