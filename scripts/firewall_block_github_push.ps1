#Requires -RunAsAdministrator
<#
.SYNOPSIS
  通过 Windows 防火墙阻止 git.exe 访问 GitHub 的 Git 服务 IP 段。
  
.DESCRIPTION
  从 GitHub 官方 API 获取 Git 服务的 IP 范围，创建出站阻止规则。
  这只会阻止 git push/pull/clone 到 GitHub，不影响：
  - 浏览器访问 github.com
  - GitHub Copilot
  - VS Code GitHub 登录
  
.PARAMETER Uninstall
  移除已安装的防火墙规则
#>

param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$RuleNamePrefix = "Block-Git-GitHub"

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err([string]$Message)  { Write-Host "[ERROR] $Message" -ForegroundColor Red }

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "请以管理员身份运行此脚本 (Run as Administrator)"
}

# 卸载模式
if ($Uninstall) {
    Write-Info "正在移除防火墙规则..."
    $rules = Get-NetFirewallRule -DisplayName "$RuleNamePrefix*" -ErrorAction SilentlyContinue
    if ($rules) {
        $rules | Remove-NetFirewallRule
        Write-Info "已移除 $($rules.Count) 条规则"
    } else {
        Write-Warn "未找到相关规则"
    }
    Write-Info "Done."
    exit 0
}

# 获取 GitHub 的 Git 服务 IP 范围
Write-Info "正在从 GitHub API 获取 Git 服务 IP 范围..."
try {
    $meta = Invoke-RestMethod -Uri "https://api.github.com/meta" -UseBasicParsing
    $gitIPs = $meta.git
    Write-Info "获取到 $($gitIPs.Count) 个 IP 段"
} catch {
    Write-Err "无法获取 GitHub IP 范围: $_"
    Write-Warn "使用备用 IP 列表（可能不完整）"
    # 备用列表 - GitHub 的常见 IP 段
    $gitIPs = @(
        "192.30.252.0/22",
        "185.199.108.0/22",
        "140.82.112.0/20",
        "143.55.64.0/20",
        "20.201.28.151/32",
        "20.205.243.166/32",
        "20.87.225.212/32",
        "20.248.137.48/32",
        "20.207.73.82/32",
        "20.27.177.113/32",
        "20.200.245.247/32",
        "20.175.192.146/32",
        "20.233.83.145/32",
        "20.29.134.23/32"
    )
}

# 查找 git.exe 路径
$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $gitPath) {
    throw "未找到 git.exe，请确保 Git 已安装"
}
# 获取实际的 git.exe（不是 shim）
$gitDir = Split-Path (Split-Path $gitPath -Parent) -Parent
$gitExePaths = @(
    (Join-Path $gitDir "cmd\git.exe"),
    (Join-Path $gitDir "bin\git.exe"),
    (Join-Path $gitDir "mingw64\bin\git.exe"),
    (Join-Path $gitDir "mingw64\libexec\git-core\git-remote-https.exe")
)
$gitExePaths = $gitExePaths | Where-Object { Test-Path $_ }

if ($gitExePaths.Count -eq 0) {
    Write-Warn "未找到 git.exe 的精确路径，将阻止所有程序访问 GitHub Git IP"
    $gitExePaths = @()
}

Write-Info "Git 可执行文件: $($gitExePaths -join ', ')"

# 清理旧规则
$existingRules = Get-NetFirewallRule -DisplayName "$RuleNamePrefix*" -ErrorAction SilentlyContinue
if ($existingRules) {
    Write-Info "移除旧规则..."
    $existingRules | Remove-NetFirewallRule
}

# 创建防火墙规则
Write-Info "正在创建防火墙规则..."

$ruleCount = 0
foreach ($ip in $gitIPs) {
    $ruleName = "$RuleNamePrefix-$($ip -replace '[/:]', '-')"
    
    $params = @{
        DisplayName = $ruleName
        Description = "阻止 git 访问 GitHub ($ip)"
        Direction   = "Outbound"
        Action      = "Block"
        Protocol    = "TCP"
        RemoteAddress = $ip
        RemotePort  = @(22, 443, 9418)  # SSH, HTTPS, Git protocol
        Enabled     = "True"
        Profile     = "Any"
    }
    
    # 如果找到了 git.exe，只阻止它；否则阻止所有程序
    if ($gitExePaths.Count -gt 0) {
        $params.Program = $gitExePaths[0]  # 主要的 git.exe
    }
    
    New-NetFirewallRule @params | Out-Null
    $ruleCount++
}

# 额外阻止 git-remote-https.exe
foreach ($exePath in $gitExePaths) {
    if ($exePath -match "git-remote-https") {
        foreach ($ip in $gitIPs) {
            $ruleName = "$RuleNamePrefix-HTTPS-$($ip -replace '[/:]', '-')"
            New-NetFirewallRule -DisplayName $ruleName `
                -Description "阻止 git-remote-https 访问 GitHub ($ip)" `
                -Direction Outbound -Action Block -Protocol TCP `
                -RemoteAddress $ip -RemotePort @(443) `
                -Program $exePath -Enabled True -Profile Any | Out-Null
            $ruleCount++
        }
    }
}

Write-Info "已创建 $ruleCount 条防火墙规则"
Write-Info ""
Write-Warn "注意事项："
Write-Host "  - 此规则只阻止 git push/pull/clone 到 GitHub"
Write-Host "  - 不影响浏览器访问 github.com"
Write-Host "  - 不影响 GitHub Copilot / VS Code 登录"
Write-Host "  - GitHub IP 可能变化，建议定期更新规则"
Write-Host ""
Write-Info "卸载命令: .\firewall_block_github_push.ps1 -Uninstall"
Write-Info "Done."
