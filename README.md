# 🚀 devboost

一键检测、修复、优化常见开发网络与基础环境问题。支持 Linux / macOS / WSL / Windows。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![ShellCheck](https://github.com/ISHAOHAO/devboost/actions/workflows/ci.yml/badge.svg)](https://github.com/ISHAOHAO/devboost/actions/workflows/ci.yml)
[![Bats Tests](https://github.com/ISHAOHAO/devboost/actions/workflows/ci.yml/badge.svg)](https://github.com/ISHAOHAO/devboost/actions/workflows/ci.yml)

---

## ✨ 特性

- **智能检测**：自动识别操作系统、包管理器、systemd、网络状态，适配 Linux/macOS/WSL/Windows 各种环境。
- **DNS 优化**：支持 Linux 的 systemd-resolved/resolv.conf 以及 Windows 的网络适配器 DNS 设置，一键切换至阿里、腾讯、Cloudflare 等公共 DNS，安全可回滚。
- **系统镜像优化**：为 apt / yum / dnf / pacman / brew 等包管理器切换国内镜像源，支持全球数百个镜像站（按大洲/国家分类）。
- **开发工具镜像**：自动配置 npm / pnpm / yarn / pip / docker 的国内镜像，提升下载速度（Windows 下同样支持）。
- **GitHub 访问优化**：通过更新 hosts 或设置代理环境变量，改善 GitHub 访问体验（需用户确认）。
- **安全可靠**：所有修改自动备份，支持一键回滚，详细日志记录，`--dry-run` 模拟运行无风险。
- **跨平台支持**：覆盖主流 Linux 发行版、macOS、WSL1/2 以及 Windows 7/10/11。
- **模块化设计**：功能模块独立，易于扩展和维护。
- **多语言支持**：内置中文/英文双语界面，交互模式下自动询问语言选择，也可通过 `--lang zh` 强制指定。

---

## 📦 快速开始

### Linux / macOS / WSL

#### 一键远程运行

```bash
bash <(curl -sSL https://raw.githubusercontent.com/ISHAOHAO/devboost/main/install.sh)
```

#### 本地运行

```bash
git clone https://github.com/ISHAOHAO/devboost.git
cd devboost
chmod +x install.sh lib/*.sh modules/*.sh
sudo ./install.sh
```

### Windows

> ⚠️ 需要以管理员身份运行 PowerShell

#### 一键远程运行（PowerShell）

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/ISHAOHAO/devboost/main/install.ps1'))
```

#### 本地运行

```powershell
# 以管理员身份打开 PowerShell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd D:\path\to\devboost
.\install.ps1
```

### 使用命令行直接优化系统镜像（阿里云，自动确认）

```bash
sudo ./install.sh --system-mirror --mirror aliyun --lang zh -y
```

---

## 🖥️ 支持的操作系统

| 分类         | 发行版 / 系统                                                                 |
|--------------|--------------------------------------------------------------------------------|
| Linux        | Debian 8~13, Ubuntu 14~25, Kali Linux, Linux Mint, Deepin, Zorin OS, Raspberry Pi OS, Armbian, Proxmox VE, openKylin |
| Linux        | RHEL 7~10, Fedora 30~43, CentOS 7~8/Stream, Rocky Linux 8~10, AlmaLinux 8~10, Oracle Linux 8~10 |
| Linux        | openEuler 20~25, OpenCloudOS 8.6~9, Arch Linux                               |
| macOS        | macOS 10.15+ (Intel/Apple Silicon)                                           |
| WSL          | WSL1 / WSL2（运行 Linux 脚本）                                               |
| Windows      | Windows 7 / 8 / 10 / 11（通过 PowerShell 脚本 `install.ps1`）               |

---

### 🌐 全球镜像源支持

devboost 现已集成全球数百个开源镜像站，按地区分类：

- **中国大陆**：阿里云、腾讯云、华为云、清华大学、中科大、上海交大、北京大学等 20+ 镜像源
- **亚太地区**：日本（京都大学、JAIST）、韩国（KAIST、Kakao）、新加坡（NUS、Singtel）、澳大利亚（AARNet）、新西兰（Waikato University）等
- **欧洲**：德国（FU Berlin、MPI）、法国（IRISA、CERN）、英国（UK FAST、Imperial College）、荷兰（NLUUG、Surfnet）、瑞典（Lund University）、芬兰（FUNET）等 30+ 镜像源
- **美洲**：美国（MIT、Stanford、Princeton、Oregon State）、加拿大（UBC）、巴西（UFSCar）、阿根廷（UNLP）等
- **非洲及中东**：南非（Stellenbosch University）、肯尼亚（KENET）、土耳其（ULAKBIM）等

系统会自动根据您的发行版过滤不兼容的镜像源，确保配置正确有效。

---

## 📚 使用说明

### 交互式菜单

直接运行脚本（Linux: `sudo ./install.sh`，Windows: `.\install.ps1`），根据提示选择功能：
```
========== devboost 优化工具 ==========
1. DNS 优化
2. 系统镜像优化 (包管理器)
3. 开发工具镜像优化 (npm/pip/docker等)
4. GitHub 访问优化
5. 全部执行
0. 退出
========================================
请选择 [0-5]：
```

### 命令行选项（Linux/macOS/WSL）

```bash
./install.sh [选项]

选项:
  -y, --yes               自动确认所有提示
  --dns                   仅运行 DNS 优化模块
  --system-mirror         仅运行系统镜像优化模块
  --devtools-mirror       仅运行开发工具镜像优化模块
  --github                仅运行 GitHub 访问优化模块
  --rollback              执行回滚操作
  --mirror <名称/URL>     指定镜像站（如 aliyun, tuna 或完整 URL）
  --protocol <http|https> 指定协议（默认 https）
  --branch <分支>         指定仓库分支（如 updates, security）
  --components <组件>     指定组件列表（如 main contrib non-free）
  --lang <zh|en>          设置语言（默认 en）
  --dry-run               模拟运行，不实际修改任何文件
  -h, --help              显示帮助
```

### 命令行选项（Windows PowerShell）

```powershell
.\install.ps1 [-yes] [-dns] [-devtools] [-github] [-rollback] [-lang zh|en] [-dryrun] [-help]
```

### 示例

```bash
# 使用清华大学镜像源更新 apt（自动确认）
sudo ./install.sh --system-mirror --mirror tuna --lang zh -y

# Windows 下仅优化 DNS
.\install.ps1 -dns

# 回滚到上次备份
sudo ./install.sh --rollback

# 模拟运行 DNS 优化，查看将执行的操作
sudo ./install.sh --dns --dry-run
```

---

## 🧩 模块介绍

- **DNS 优化** (`dns.sh` / `Optimize-DNS`)：检测当前 DNS，提供多组公共 DNS 选择，支持 Linux systemd-resolved/resolv.conf 及 Windows 网络适配器设置，自动备份。
- **系统镜像优化** (`system_mirror.sh`)：根据发行版自动生成正确格式的源列表，提供全球镜像源选择，支持 apt/yum/dnf/pacman/brew。
- **开发工具镜像** (`devtools_mirror.sh` / `Optimize-DevTools`)：为 npm/pnpm/yarn/pip/docker 配置国内镜像，支持自定义 registry。
- **GitHub 访问优化** (`github.sh` / `Optimize-GitHub`)：通过更新 hosts 或设置代理环境变量改善访问，需用户确认。
- **回滚** (`rollback.sh` / `Invoke-Rollback`)：基于备份清单，支持按序号或全部回滚。

---

## 🔧 开发与贡献

欢迎贡献代码、报告问题或提出建议！

### 开发环境

```bash
git clone https://github.com/ISHAOHAO/devboost.git
cd devboost
# 安装依赖（用于测试）
# Ubuntu/Debian: sudo apt install bats shellcheck
# CentOS/RHEL: sudo yum install bats shellcheck
# Windows: 需安装 Pester 和 PowerShell 5.1+
```

### 运行测试

```bash
bats test/          # Linux/macOS
Invoke-Pester       # Windows (Pester)
```

### 贡献指南

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

---

## 📄 许可证

[MIT](LICENSE) © 2026 devboost contributors
