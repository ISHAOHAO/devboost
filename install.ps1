#!/usr/bin/env pwsh
<#
.SYNOPSIS
    devboost for Windows - 一键优化开发网络与环境
.DESCRIPTION
    支持 Windows 7/10/11，提供 DNS 优化、开发工具镜像、GitHub 访问优化等功能。
    必须以管理员身份运行。
.PARAMETER yes
    自动确认所有提示
.PARAMETER dns
    仅运行 DNS 优化
.PARAMETER devtools
    仅运行开发工具镜像优化
.PARAMETER github
    仅运行 GitHub 访问优化
.PARAMETER rollback
    执行回滚操作
.PARAMETER lang
    设置语言：zh 或 en（默认 en）
.PARAMETER dryrun
    模拟运行，不实际修改
.PARAMETER help
    显示帮助
#>

param(
    [switch]$yes,
    [switch]$dns,
    [switch]$devtools,
    [switch]$github,
    [switch]$rollback,
    [string]$lang = "en",
    [switch]$dryrun,
    [switch]$help
)

if ($help) {
    Get-Help $MyInvocation.MyCommand.Definition -Detailed
    exit
}

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "错误：请以管理员身份运行此脚本。" -ForegroundColor Red
    exit 1
}

# 全局变量
$AUTO_CONFIRM = $yes
$OPT_LANG = $lang
$OPT_DRY_RUN = $dryrun

# 确定工作目录（兼容远程执行）
function Get-WorkingDirectory {
    # 尝试获取脚本真实路径
    $scriptPath = $MyInvocation.MyCommand.Definition
    if (Test-Path -LiteralPath $scriptPath -PathType Leaf) {
        # 本地执行，使用脚本所在目录
        return Split-Path -Parent $scriptPath
    } else {
        # 远程执行，使用临时目录
        $tempDir = Join-Path $env:TEMP "devboost"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        return $tempDir
    }
}

$DEVBOOST_ROOT = Get-WorkingDirectory
$logDir = Join-Path $DEVBOOST_ROOT "logs"
$backupDir = Join-Path $DEVBOOST_ROOT "backups"
$logFile = Join-Path $logDir "devboost.log"
$manifestFile = Join-Path $backupDir "manifest.txt"

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }

# 日志函数
function Write-Log {
    param([string]$Level, [string]$Message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$Level] $time - $Message"
    Add-Content -Path $logFile -Value $line
    if ($Level -eq "ERROR") { Write-Host $line -ForegroundColor Red }
    elseif ($Level -eq "WARN") { Write-Host $line -ForegroundColor Yellow }
    else { Write-Host $line -ForegroundColor Green }
}

# 多语言输出
function Write-I18n {
    param([string]$en, [string]$zh)
    if ($OPT_LANG -eq "zh") { Write-Host $zh }
    else { Write-Host $en }
}

# 菜单选项输出（带编号，支持中英文描述）
function Write-Option {
    param([int]$Number, [string]$EnText, [string]$ZhText)
    if ($OPT_LANG -eq "zh") {
        Write-Host "$Number) $ZhText"
    } else {
        Write-Host "$Number) $EnText"
    }
}

# 询问语言（交互模式专用）
function Ask-Language {
    Write-Host "Please select language / 请选择语言:"
    Write-Host "1) English"
    Write-Host "2) 中文"
    $langChoice = Read-Host "Choice [1-2]"
    if ($langChoice -eq "2") {
        $script:OPT_LANG = "zh"
    } else {
        $script:OPT_LANG = "en"
    }
}

# 确认函数
function Confirm-Action {
    param([string]$enPrompt, [string]$zhPrompt)
    if ($AUTO_CONFIRM) { return $true }
    $prompt = if ($OPT_LANG -eq "zh") { $zhPrompt } else { $enPrompt }
    $answer = Read-Host "$prompt [y/N]"
    return ($answer -eq "y" -or $answer -eq "Y")
}

# 备份文件（支持注册表路径）
function Backup-File {
    param([string]$Path, [string]$Tag)
    if (-not (Test-Path $Path)) { return $null }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    if ($Path -match '^registry::') {
        # 注册表项：导出为 .reg 文件
        $regPath = $Path -replace '^registry::', ''
        $backupPath = Join-Path $backupDir "$(($regPath -replace '\\', '_') -replace ':', '')_${Tag}_$timestamp.reg"
        if ($OPT_DRY_RUN) {
            Write-Log "INFO" "[DRY-RUN] Would export registry $regPath to $backupPath"
        } else {
            reg export "$regPath" "$backupPath" /y > $null 2>&1
            Write-Log "INFO" "Registry exported: $regPath -> $backupPath"
        }
    } else {
        # 普通文件
        $backupPath = Join-Path $backupDir "$(Split-Path $Path -Leaf)_${Tag}_$timestamp"
        if ($OPT_DRY_RUN) {
            Write-Log "INFO" "[DRY-RUN] Would copy $Path to $backupPath"
        } else {
            Copy-Item -Path $Path -Destination $backupPath
            Write-Log "INFO" "Backup created: $Path -> $backupPath"
        }
    }

    $manifestLine = "$Path|$backupPath|$Tag|$timestamp"
    Add-Content -Path $manifestFile -Value $manifestLine
    return $backupPath
}

# 恢复文件（简化，此处仅用于演示，实际需根据类型处理）
function Restore-File {
    param([string]$OriginalPath)
    if (-not (Test-Path $manifestFile)) { return $false }

    $lines = Get-Content $manifestFile
    $matchingLines = @()
    $pattern = '^' + [regex]::Escape($OriginalPath) + '\|'
    foreach ($line in $lines) {
        if ($line -match $pattern) {
            $matchingLines += $line
        }
    }
    if ($matchingLines.Count -eq 0) { return $false }

    $sorted = $matchingLines | Sort-Object -Descending {
        $parts = $_ -split '\|'
        $parts[3]
    }
    $latest = $sorted[0]
    $parts = $latest -split '\|'
    $backupPath = $parts[1]

    if (Test-Path $backupPath) {
        if ($OriginalPath -match '^registry::') {
            # 注册表项：导入 .reg 文件
            reg import "$backupPath" > $null 2>&1
        } else {
            Copy-Item -Path $backupPath -Destination $OriginalPath -Force
        }
        Write-Log "INFO" "Restored: $OriginalPath"
        return $true
    }
    return $false
}

# 系统信息
function Get-SystemInfo {
    $os = Get-WmiObject Win32_OperatingSystem
    $osName = $os.Caption
    $osVersion = $os.Version
    $isWSL = (Get-ComputerInfo).WindowsVersion -like "*WSL*"
    return @{
        OSName = $osName
        OSVersion = $osVersion
        IsWSL = $isWSL
    }
}

# ---------- 模块函数 ----------
function Optimize-DNS {
    Write-Log "INFO" "===== DNS 优化 ====="
    Write-I18n "Detecting current DNS..." "检测当前 DNS 配置..."
    $adapters = Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses -ne $null}
    foreach ($adapter in $adapters) {
        Write-Host "$($adapter.InterfaceAlias): $($adapter.ServerAddresses -join ', ')"
    }

    Write-I18n "Select DNS provider:" "选择 DNS 服务商："
    Write-Option 1 "114 (114.114.114.114, 114.114.115.115)" "114 (114.114.114.114, 114.114.115.115)"
    Write-Option 2 "Aliyun (223.5.5.5, 223.6.6.6)" "阿里云 (223.5.5.5, 223.6.6.6)"
    Write-Option 3 "Tencent (119.29.29.29, 182.254.116.116)" "腾讯云 (119.29.29.29, 182.254.116.116)"
    Write-Option 4 "Cloudflare (1.1.1.1, 1.0.0.1)" "Cloudflare (1.1.1.1, 1.0.0.1)"
    Write-Option 5 "Google (8.8.8.8, 8.8.4.4)" "Google (8.8.8.8, 8.8.4.4)"
    Write-Option 6 "Custom" "自定义"
    Write-Option 0 "Back" "返回"

    $choice = Read-Host "Choice [0-6]"
    $servers = @()
    switch ($choice) {
        "1" { $servers = @("114.114.114.114", "114.114.115.115") }
        "2" { $servers = @("223.5.5.5", "223.6.6.6") }
        "3" { $servers = @("119.29.29.29", "182.254.116.116") }
        "4" { $servers = @("1.1.1.1", "1.0.0.1") }
        "5" { $servers = @("8.8.8.8", "8.8.4.4") }
        "6" {
            $custom = Read-Host "Enter DNS servers (space separated)"
            $servers = $custom -split '\s+'
        }
        "0" { return }
        default { Write-I18n "Invalid choice." "无效选择。"; return }
    }

    if (-not $servers) { return }

    if (-not (Confirm-Action "Set DNS to $($servers -join ', ')? Continue?" "将 DNS 设置为 $($servers -join ', ')，是否继续？")) {
        return
    }

    $netAdapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    foreach ($adapter in $netAdapters) {
        if ($OPT_DRY_RUN) {
            Write-Log "INFO" "[DRY-RUN] Would set DNS on $($adapter.Name) to $($servers -join ', ')"
        } else {
            # 备份注册表项
            $regPath = "registry::HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($adapter.InterfaceGuid)"
            Backup-File -Path $regPath -Tag "dns"
            # 设置 DNS
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $servers
            Write-Log "INFO" "DNS set on $($adapter.Name) to $($servers -join ', ')"
        }
    }
}

function Optimize-DevTools {
    Write-Log "INFO" "===== 开发工具镜像优化 ====="

    # npm
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "npm 已安装，当前 registry: $(npm config get registry)"
        if (Confirm-Action "Configure npm mirror?" "配置 npm 镜像？") {
            $registry = "https://registry.npmmirror.com"
            if ($OPT_DRY_RUN) {
                Write-Log "INFO" "[DRY-RUN] npm config set registry $registry"
            } else {
                npm config set registry $registry
                Write-Log "INFO" "npm registry 已设置为 $registry"
            }
        }
    }

    # pip
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        Write-Host "pip 已安装"
        if (Confirm-Action "Configure pip mirror?" "配置 pip 镜像？") {
            $indexUrl = "https://pypi.tuna.tsinghua.edu.cn/simple"
            if ($OPT_DRY_RUN) {
                Write-Log "INFO" "[DRY-RUN] pip config set global.index-url $indexUrl"
            } else {
                pip config set global.index-url $indexUrl
                Write-Log "INFO" "pip index-url 已设置为 $indexUrl"
            }
        }
    }

    # Docker
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "Docker 已安装"
        $daemonPath = "$env:ProgramData\Docker\config\daemon.json"
        if (Confirm-Action "Configure Docker mirror?" "配置 Docker 镜像加速器？") {
            $mirror = "https://docker.mirrors.ustc.edu.cn"
            if ($OPT_DRY_RUN) {
                Write-Log "INFO" "[DRY-RUN] Would add registry-mirror $mirror to $daemonPath"
            } else {
                if (Test-Path $daemonPath) {
                    $config = Get-Content $daemonPath -Raw | ConvertFrom-Json
                } else {
                    $config = New-Object PSObject
                }
                if (-not $config.'registry-mirrors') {
                    $config | Add-Member -MemberType NoteProperty -Name 'registry-mirrors' -Value @()
                }
                $config.'registry-mirrors' += $mirror
                Backup-File -Path $daemonPath -Tag "docker"
                $config | ConvertTo-Json -Depth 10 | Set-Content $daemonPath
                Write-Log "INFO" "Docker 镜像加速器已添加: $mirror"
                Restart-Service docker
            }
        }
    }
}

function Optimize-GitHub {
    Write-Log "INFO" "===== GitHub 访问优化 ====="
    Write-I18n "Select option:" "选择选项："
    Write-Option 1 "Update hosts (requires admin)" "更新 hosts（需管理员权限）"
    Write-Option 2 "Set proxy environment variables" "设置代理环境变量"
    Write-Option 0 "Back" "返回"
    $choice = Read-Host "Choice [0-2]"
    switch ($choice) {
        "1" { Optimize-GitHubHosts }
        "2" { Optimize-GitHubProxy }
        "0" { return }
    }
}

function Optimize-GitHubHosts {
    if (-not (Confirm-Action "Modify hosts file? This may cause security risks." "修改 hosts 文件可能带来安全风险，是否继续？")) {
        return
    }

    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $entries = @"
# GitHub Hosts Start
140.82.113.3      github.com
140.82.112.3      gist.github.com
185.199.108.153   assets-cdn.github.com
199.232.68.133    raw.githubusercontent.com
199.232.68.133    gist.githubusercontent.com
199.232.68.133    cloud.githubusercontent.com
199.232.68.133    camo.githubusercontent.com
199.232.68.133    avatars.githubusercontent.com
# GitHub Hosts End
"@

    if ($OPT_DRY_RUN) {
        Write-Log "INFO" "[DRY-RUN] Would append to $hostsPath"
    } else {
        Backup-File -Path $hostsPath -Tag "github"
        Add-Content -Path $hostsPath -Value "`r`n$entries"
        Write-Log "INFO" "GitHub hosts 已更新"
    }
}

function Optimize-GitHubProxy {
    $proxy = Read-Host "Enter proxy URL (e.g., http://127.0.0.1:7890)"
    if (-not $proxy) { return }
    [Environment]::SetEnvironmentVariable("http_proxy", $proxy, "User")
    [Environment]::SetEnvironmentVariable("https_proxy", $proxy, "User")
    Write-Log "INFO" "代理环境变量已设置，重新打开命令行生效。"
}

function Invoke-Rollback {
    Write-Log "INFO" "===== 回滚 ====="
    if (-not (Test-Path $manifestFile)) {
        Write-Log "WARN" "未找到备份记录。"
        return
    }
    $lines = Get-Content $manifestFile
    $i = 1
    foreach ($line in $lines) {
        $parts = $line -split '\|'
        Write-Host "$i. $($parts[0])  ->  $($parts[1])  ($($parts[2]))"
        $i++
    }
    Write-Host "0. 取消"
    $choice = Read-Host "选择要回滚的序号"
    if ($choice -eq "0") { return }
    if ($choice -match '^\d+$' -and $choice -le $lines.Count) {
        $selected = $lines[$choice-1]
        $parts = $selected -split '\|'
        $backupPath = $parts[1]
        $original = $parts[0]
        if (Test-Path $backupPath) {
            if ($original -match '^registry::') {
                reg import "$backupPath" > $null 2>&1
            } else {
                Copy-Item -Path $backupPath -Destination $original -Force
            }
            Write-Log "INFO" "已恢复: $original"
        } else {
            Write-Log "ERROR" "备份文件丢失: $backupPath"
        }
    } else {
        Write-I18n "Invalid choice." "无效选择。"
    }
}

function Show-Menu {
    Write-Host ""
    if ($OPT_LANG -eq "zh") {
        Write-Host "========== devboost 优化工具 (Windows) =========="
        Write-Host "1. DNS 优化"
        Write-Host "2. 开发工具镜像优化 (npm/pip/docker)"
        Write-Host "3. GitHub 访问优化"
        Write-Host "4. 全部执行"
        Write-Host "0. 退出"
    } else {
        Write-Host "========== devboost Optimizer (Windows) =========="
        Write-Host "1. DNS Optimization"
        Write-Host "2. Dev Tools Mirror Optimization (npm/pip/docker)"
        Write-Host "3. GitHub Access Optimization"
        Write-Host "4. Run All"
        Write-Host "0. Exit"
    }
    $choice = Read-Host "Choice [0-4]"
    switch ($choice) {
        "1" { Optimize-DNS; Show-Menu }
        "2" { Optimize-DevTools; Show-Menu }
        "3" { Optimize-GitHub; Show-Menu }
        "4" {
            Optimize-DNS
            Optimize-DevTools
            Optimize-GitHub
            Show-Menu
        }
        "0" { exit }
        default { Show-Menu }
    }
}

function Main {
    Write-Log "INFO" "========== devboost (Windows) 启动 =========="
    Write-Log "INFO" "日志文件: $logFile"
    Write-Log "INFO" "备份目录: $backupDir"

    # 交互模式下询问语言（如果没有通过参数指定且为默认英文）
    if (-not $dns -and -not $devtools -and -not $github -and -not $rollback -and $OPT_LANG -eq "en") {
        Ask-Language
    }

    $sysInfo = Get-SystemInfo
    Write-Log "INFO" "系统信息: $($sysInfo.OSName) $($sysInfo.OSVersion), WSL=$($sysInfo.IsWSL)"

    if ($rollback) {
        Invoke-Rollback
        exit
    }

    if ($dns) { Optimize-DNS; exit }
    if ($devtools) { Optimize-DevTools; exit }
    if ($github) { Optimize-GitHub; exit }

    Show-Menu
}

Main