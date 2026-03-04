#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# devboost 主脚本（一体化版本）
# 包含所有库和模块，无需外部文件
# 功能：一键检测、修复、优化开发网络与基础环境
# 支持 Linux / macOS / WSL
# ==================================================

# ---------- 全局变量 ----------
AUTO_CONFIRM=false
SPECIFIC_MODULE=""
OPT_MIRROR=""
OPT_PROTOCOL="https"
OPT_BRANCH=""
OPT_COMPONENTS=""
OPT_LANG="en"
OPT_DRY_RUN=false
LANG_ZH=false          # 根据 OPT_LANG 设置

# ---------- 日志和备份目录 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEVBOOST_ROOT="$SCRIPT_DIR"
export DEVBOOST_BACKUP_DIR="$DEVBOOST_ROOT/backups"
export DEVBOOST_LOG_DIR="$DEVBOOST_ROOT/logs"
export DEVBOOST_LOG_FILE="$DEVBOOST_LOG_DIR/devboost.log"
export DEVBOOST_MANIFEST="$DEVBOOST_BACKUP_DIR/manifest.txt"

# ==================================================
# 公共函数库 (common.sh)
# ==================================================

# 日志函数（初始版本，后面会用彩色覆盖）
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE"
}
log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE" >&2
}
log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE" >&2
}

# 确认函数
confirm() {
    local prompt="$1"
    if [[ "$AUTO_CONFIRM" == true ]]; then
        return 0
    fi
    read -rp "$prompt [y/N]: " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此操作需要 root 权限，请使用 sudo 运行。"
        exit 1
    fi
}

# 备份文件
backup_file() {
    local file="$1"
    local tag="${2:-backup}"
    if [[ ! -f "$file" ]]; then
        log_warn "文件不存在，跳过备份: $file"
        return 1
    fi

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$DEVBOOST_BACKUP_DIR/$(basename "$file")_${tag}_${timestamp}"
    cp -a "$file" "$backup_path"
    echo "$file|$backup_path|$tag|$timestamp" >> "$DEVBOOST_MANIFEST"
    log_info "已备份: $file -> $backup_path"
    echo "$backup_path"
}

# 恢复单个文件
restore_file() {
    local original="$1"
    local latest_backup=$(grep "^$original|" "$DEVBOOST_MANIFEST" | sort -t'|' -k4r | head -n1 | cut -d'|' -f2)
    if [[ -z "$latest_backup" ]]; then
        log_error "未找到 $original 的备份记录"
        return 1
    fi
    if [[ ! -f "$latest_backup" ]]; then
        log_error "备份文件丢失: $latest_backup"
        return 1
    fi
    cp -a "$latest_backup" "$original"
    log_info "已恢复: $latest_backup -> $original"
}

# 网络连通性检测
check_network() {
    local target="${1:-8.8.8.8}"
    if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
        echo "reachable"
        return 0
    else
        echo "unreachable"
        return 1
    fi
}

# 检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 安全写入文件
safe_write() {
    local file="$1"
    local content="$2"
    local backup_id="${3:-write}"

    if [[ -f "$file" ]]; then
        backup_file "$file" "$backup_id"
    fi
    echo "$content" > "$file"
    log_info "已写入文件: $file"
}

# 颜色定义
if [[ -t 1 ]]; then
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[0;33m'
    readonly COLOR_BLUE='\033[0;34m'
else
    readonly COLOR_RESET=''
    readonly COLOR_RED=''
    readonly COLOR_GREEN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_BLUE=''
fi

# 彩色日志函数
log_info() {
    echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE"
}
log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE" >&2
}
log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE" >&2
}

# 多语言输出函数
_echo() {
    local en="$1"
    local zh="$2"
    if [[ "$OPT_LANG" == "zh" ]]; then
        echo "$zh"
    else
        echo "$en"
    fi
}

# 发现可用模块（基于当前文件中的函数，这里硬编码返回模块列表，因为模块已内联）
discover_modules() {
    # 返回模块名称、英文描述、中文描述
    cat <<EOF
dns|DNS Optimization|DNS优化
system_mirror|System Package Manager Mirror Optimization|系统包管理器镜像优化
devtools_mirror|Development Tools Mirror Optimization|开发工具镜像优化
github|GitHub Access Optimization|GitHub访问优化
EOF
}

# ==================================================
# 系统检测模块 (detect.sh)
# ==================================================

detect_system() {
    # 检测 WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
        if grep -q WSL2 /proc/version 2>/dev/null; then
            ENV_TYPE="WSL2"
        else
            ENV_TYPE="WSL1"
        fi
    else
        ENV_TYPE="native"
    fi

    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="$ID"
        OS_VERSION="$VERSION_ID"
    elif [[ "$(uname)" == "Darwin" ]]; then
        OS_NAME="macos"
        OS_VERSION="$(sw_vers -productVersion)"
    else
        OS_NAME="unknown"
        OS_VERSION="unknown"
    fi

    # 检测包管理器
    if check_command apt; then
        PKG_MANAGER="apt"
    elif check_command dnf; then
        PKG_MANAGER="dnf"
    elif check_command yum; then
        PKG_MANAGER="yum"
    elif check_command pacman; then
        PKG_MANAGER="pacman"
    elif check_command brew; then
        PKG_MANAGER="brew"
    else
        PKG_MANAGER="unknown"
    fi

    # 检测 systemd
    if command -v systemctl >/dev/null 2>&1; then
        HAS_SYSTEMD=true
    else
        HAS_SYSTEMD=false
    fi

    # 网络连通性
    if check_network; then
        NETWORK_STATUS="reachable"
    else
        NETWORK_STATUS="unreachable"
    fi

    export OS_NAME OS_VERSION ENV_TYPE PKG_MANAGER HAS_SYSTEMD NETWORK_STATUS
}

# ==================================================
# 回滚模块 (rollback.sh)
# ==================================================

perform_rollback() {
    log_info "开始执行回滚操作"

    if [[ ! -s "$DEVBOOST_MANIFEST" ]]; then
        log_warn "备份清单为空，无任何回滚操作"
        return
    fi

    echo "备份记录："
    echo "序号 | 原始文件 | 备份文件 | 操作标识 | 时间戳"
    echo "------------------------------------------------"
    local i=1
    while IFS='|' read -r original backup tag timestamp; do
        printf "%3d | %s | %s | %s | %s\n" "$i" "$original" "$backup" "$tag" "$timestamp"
        ((i++))
    done < "$DEVBOOST_MANIFEST"

    echo ""
    read -rp "请输入要回滚的序号（多个用空格分隔，输入 all 回滚所有）: " selection

    if [[ "$selection" == "all" ]]; then
        while IFS='|' read -r original backup tag timestamp; do
            if [[ -f "$backup" ]]; then
                cp -a "$backup" "$original"
                log_info "已恢复: $original"
            else
                log_error "备份文件丢失: $backup"
            fi
        done < "$DEVBOOST_MANIFEST"
        log_info "全部回滚完成"
    else
        for idx in $selection; do
            line=$(sed -n "${idx}p" "$DEVBOOST_MANIFEST")
            IFS='|' read -r original backup tag timestamp <<< "$line"
            if [[ -f "$backup" ]]; then
                cp -a "$backup" "$original"
                log_info "已恢复: $original (序号 $idx)"
            else
                log_error "备份文件丢失: $backup"
            fi
        done
    fi
}

# ==================================================
# DNS 优化模块 (dns.sh)
# ==================================================

declare -A DNS_SERVERS=(
    ["114"]="114.114.114.114 114.114.115.115"
    ["阿里"]="223.5.5.5 223.6.6.6"
    ["腾讯"]="119.29.29.29 182.254.116.116"
    ["Cloudflare"]="1.1.1.1 1.0.0.1"
)

run_dns() {
    log_info "===== DNS优化模块 ====="

    detect_current_dns

    echo "可用的DNS服务商："
    local i=1
    local names=()
    for name in "${!DNS_SERVERS[@]}"; do
        echo "  $i. $name (${DNS_SERVERS[$name]})"
        names+=("$name")
        ((i++))
    done
    echo "  $i. 自定义"
    echo "  0. 返回上级菜单"

    read -rp "请选择DNS服务商 [0-$i]: " choice
    if [[ "$choice" == "0" ]]; then
        return
    fi

    local selected_name
    local selected_servers
    if [[ "$choice" -le ${#names[@]} ]]; then
        selected_name="${names[$((choice-1))]}"
        selected_servers="${DNS_SERVERS[$selected_name]}"
    elif [[ "$choice" -eq $i ]]; then
        read -rp "请输入自定义DNS服务器（多个用空格分隔）: " selected_servers
        selected_name="custom"
    else
        log_error "无效选择"
        return
    fi

    if [[ -z "$selected_servers" ]]; then
        log_error "未指定DNS服务器"
        return
    fi

    if ! confirm "将DNS修改为 $selected_name ($selected_servers)，是否继续？"; then
        log_info "用户取消DNS修改"
        return
    fi

    apply_dns "$selected_servers"
}

detect_current_dns() {
    log_info "检测当前DNS配置..."
    if [[ "$OS_NAME" == "macos" ]]; then
        scutil --dns | grep 'nameserver' | head -3
    elif [[ "$HAS_SYSTEMD" == "true" ]] && systemctl is-active systemd-resolved >/dev/null 2>&1; then
        systemd-resolve --status | grep "DNS Servers" -A2
    else
        cat /etc/resolv.conf | grep nameserver
    fi
}

apply_dns() {
    local servers="$1"
    if [[ "$ENV_TYPE" == WSL* ]]; then
        apply_dns_wsl "$servers"
    elif [[ "$OS_NAME" == "macos" ]]; then
        apply_dns_macos "$servers"
    elif [[ "$HAS_SYSTEMD" == "true" ]] && systemctl is-active systemd-resolved >/dev/null 2>&1; then
        apply_dns_systemd_resolved "$servers"
    else
        apply_dns_resolv_conf "$servers"
    fi
}

apply_dns_resolv_conf() {
    local servers="$1"
    local resolv_conf="/etc/resolv.conf"

    check_root

    local content="# Generated by devboost on $(date)\n"
    for s in $servers; do
        content+="nameserver $s\n"
    done

    safe_write "$resolv_conf" "$(echo -e "$content")" "dns"
    log_info "DNS已更新为：$servers"
}

apply_dns_systemd_resolved() {
    local servers="$1"
    local conf_file="/etc/systemd/resolved.conf"
    check_root

    backup_file "$conf_file" "dns"

    if grep -q "^DNS=" "$conf_file"; then
        sed -i "s/^DNS=.*/DNS=$servers/" "$conf_file"
    else
        echo "DNS=$servers" >> "$conf_file"
    fi

    systemctl restart systemd-resolved
    log_info "已通过 systemd-resolved 应用 DNS：$servers"
}

apply_dns_macos() {
    local servers="$1"
    log_info "macOS DNS 配置需要手动设置或通过 networksetup 命令"
    echo "请在系统偏好设置中修改DNS，或使用命令："
    echo "sudo networksetup -setdnsservers Wi-Fi $servers"
}

apply_dns_wsl() {
    local servers="$1"
    log_warn "WSL 中 /etc/resolv.conf 可能被 Windows 自动覆盖"
    log_warn "建议在 Windows 中修改 DNS 或设置 WSL 生成 resolv.conf 的选项"
    local resolv_conf="/etc/resolv.conf"
    check_root

    chattr -i "$resolv_conf" 2>/dev/null || true
    apply_dns_resolv_conf "$servers"
    chattr +i "$resolv_conf" 2>/dev/null && log_info "已设置 $resolv_conf 为不可变，防止被覆盖"
}

# ==================================================
# GitHub 访问优化模块 (github.sh)
# ==================================================

run_github() {
    log_info "===== GitHub访问优化模块 ====="

    echo "GitHub 访问优化选项："
    echo "1. 更新 hosts（推荐，需要 root）"
    echo "2. 设置代理环境变量（需要已有代理）"
    echo "0. 返回"
    read -rp "请选择 [0-2]: " choice

    case "$choice" in
        1) optimize_github_hosts ;;
        2) optimize_github_proxy ;;
        0) return ;;
        *) log_error "无效选择" ;;
    esac
}

optimize_github_hosts() {
    log_info "尝试通过 hosts 优化 GitHub 访问"
    check_root

    if ! confirm "修改 hosts 文件可能带来安全风险，是否继续？"; then
        log_info "用户取消"
        return
    fi

    local hosts_entries=$(cat <<EOF
# GitHub Hosts Start
140.82.113.3      github.com
140.82.112.3      gist.github.com
185.199.108.153   assets-cdn.github.com
199.232.68.133    raw.githubusercontent.com
199.232.68.133    gist.githubusercontent.com
199.232.68.133    cloud.githubusercontent.com
199.232.68.133    camo.githubusercontent.com
199.232.68.133    avatars.githubusercontent.com
199.232.68.133    avatars0.githubusercontent.com
199.232.68.133    avatars1.githubusercontent.com
199.232.68.133    avatars2.githubusercontent.com
199.232.68.133    avatars3.githubusercontent.com
199.232.68.133    avatars4.githubusercontent.com
199.232.68.133    avatars5.githubusercontent.com
199.232.68.133    avatars6.githubusercontent.com
199.232.68.133    avatars7.githubusercontent.com
199.232.68.133    avatars8.githubusercontent.com
# GitHub Hosts End
EOF
)

    local hosts_file="/etc/hosts"
    backup_file "$hosts_file" "github_hosts"

    if grep -q "# GitHub Hosts Start" "$hosts_file"; then
        sed -i '/# GitHub Hosts Start/,/# GitHub Hosts End/d' "$hosts_file"
    fi

    echo "$hosts_entries" >> "$hosts_file"
    log_info "GitHub hosts 已更新"
}

optimize_github_proxy() {
    log_info "配置代理环境变量"
    echo "请输入您的代理地址（例如 http://127.0.0.1:7890）:"
    read -rp "> " proxy_url

    if [[ -z "$proxy_url" ]]; then
        log_error "代理地址不能为空"
        return
    fi

    local profile_file="/etc/profile.d/github_proxy.sh"
    check_root

    cat > "$profile_file" <<EOF
export http_proxy="$proxy_url"
export https_proxy="$proxy_url"
export all_proxy="$proxy_url"
export HTTP_PROXY="$proxy_url"
export HTTPS_PROXY="$proxy_url"
export ALL_PROXY="$proxy_url"
EOF

    log_info "代理环境变量已写入 $profile_file，请重新登录或 source 该文件生效"
    echo "您也可以手动执行: source $profile_file"
}

# ==================================================
# 开发工具镜像优化模块 (devtools_mirror.sh)
# ==================================================

run_devtools_mirror() {
    log_info "===== 开发工具镜像优化模块 ====="

    # NPM
    if check_command npm; then
        optimize_npm
    else
        log_info "npm 未安装，跳过"
    fi

    # PNPM
    if check_command pnpm; then
        optimize_pnpm
    else
        log_info "pnpm 未安装，跳过"
    fi

    # Yarn
    if check_command yarn; then
        optimize_yarn
    else
        log_info "yarn 未安装，跳过"
    fi

    # PIP
    if check_command pip3 || check_command pip; then
        optimize_pip
    else
        log_info "pip 未安装，跳过"
    fi

    # Docker
    if check_command docker; then
        optimize_docker
    else
        log_info "docker 未安装，跳过"
    fi
}

optimize_npm() {
    log_info "配置 npm 镜像"
    local current_registry=$(npm config get registry 2>/dev/null)
    echo "当前 npm registry: $current_registry"
    echo "选择 npm 镜像："
    echo "1. 淘宝镜像 (https://registry.npmmirror.com)"
    echo "2. 华为云 (https://mirrors.huaweicloud.com/repository/npm/)"
    echo "3. 自定义"
    echo "0. 跳过"
    read -rp "请选择 [0-3]: " choice

    local registry
    case "$choice" in
        1) registry="https://registry.npmmirror.com" ;;
        2) registry="https://mirrors.huaweicloud.com/repository/npm/" ;;
        3) read -rp "请输入 registry 地址: " registry ;;
        0) return ;;
        *) log_error "无效选择"; return ;;
    esac

    if confirm "设置 npm registry 为 $registry？"; then
        npm config set registry "$registry"
        log_info "npm registry 已设置为 $registry"
    fi
}

optimize_pnpm() {
    log_info "配置 pnpm 镜像"
    local current_registry=$(pnpm config get registry 2>/dev/null)
    echo "当前 pnpm registry: $current_registry"
    echo "选择 pnpm 镜像："
    echo "1. 淘宝镜像 (https://registry.npmmirror.com)"
    echo "2. 华为云 (https://mirrors.huaweicloud.com/repository/npm/)"
    echo "3. 自定义"
    read -rp "请选择 [1-3]: " choice
    # 实际实现可参考 npm
}

optimize_yarn() {
    log_info "配置 yarn 镜像"
    local current_registry=$(yarn config get registry 2>/dev/null)
    echo "当前 yarn registry: $current_registry"
    # 类似 npm
}

optimize_pip() {
    log_info "配置 pip 镜像"
    local pip_cmd="pip3"
    if ! check_command pip3; then
        pip_cmd="pip"
    fi

    local current_index=$($pip_cmd config list | grep index-url || echo "未设置")
    echo "当前 pip index-url: $current_index"
    echo "选择 pip 镜像："
    echo "1. 清华大学 (https://pypi.tuna.tsinghua.edu.cn/simple)"
    echo "2. 阿里云 (https://mirrors.aliyun.com/pypi/simple/)"
    echo "3. 自定义"
    read -rp "请选择 [1-3]: " choice

    local index_url
    case "$choice" in
        1) index_url="https://pypi.tuna.tsinghua.edu.cn/simple" ;;
        2) index_url="https://mirrors.aliyun.com/pypi/simple/" ;;
        3) read -rp "请输入 index-url: " index_url ;;
        *) log_error "无效选择"; return ;;
    esac

    if confirm "设置 pip index-url 为 $index_url？"; then
        $pip_cmd config set global.index-url "$index_url"
        log_info "pip index-url 已设置为 $index_url"
    fi
}

optimize_docker() {
    log_info "配置 Docker 镜像加速器"
    local daemon_json="/etc/docker/daemon.json"
    check_root

    echo "选择 Docker 镜像加速器："
    echo "1. 阿里云 (https://xxxx.mirror.aliyuncs.com) 需要注册获取"
    echo "2. 中科大 (https://docker.mirrors.ustc.edu.cn)"
    echo "3. 网易 (http://hub-mirror.c.163.com)"
    echo "4. 自定义"
    read -rp "请选择 [1-4]: " choice

    local registry_mirror
    case "$choice" in
        1) registry_mirror="https://your-id.mirror.aliyuncs.com" ;;
        2) registry_mirror="https://docker.mirrors.ustc.edu.cn" ;;
        3) registry_mirror="http://hub-mirror.c.163.com" ;;
        4) read -rp "请输入镜像加速器地址: " registry_mirror ;;
        *) log_error "无效选择"; return ;;
    esac

    if [[ -f "$daemon_json" ]]; then
        backup_file "$daemon_json" "docker"
    fi

    local tmp_config
    if [[ -f "$daemon_json" ]]; then
        tmp_config=$(cat "$daemon_json")
    else
        tmp_config="{}"
    fi

    if check_command jq; then
        echo "$tmp_config" | jq --arg url "$registry_mirror" '.["registry-mirrors"] = [$url]' > "$daemon_json"
    else
        cat > "$daemon_json" <<EOF
{
  "registry-mirrors": ["$registry_mirror"]
}
EOF
    fi

    log_info "Docker 镜像加速器已设置为 $registry_mirror"
    systemctl restart docker
    log_info "Docker 服务已重启"
}

# ==================================================
# 系统镜像优化模块 (system_mirror.sh)
# ==================================================

# 全球镜像源数据库（按大洲/国家分类）
# 格式：国家|镜像站名称|域名|支持的协议|备注

MIRRORS_ASIA_CHINA=(
    "中国|阿里云|mirrors.aliyun.com|https/http|官方云镜像"
    "中国|清华大学|mirrors.tuna.tsinghua.edu.cn|https/http|教育网"
    "中国|中科大|mirrors.ustc.edu.cn|https/http|教育网"
    "中国|华为云|mirrors.huaweicloud.com|https/http|官方云镜像"
    "中国|腾讯云|mirrors.tencent.com|https/http|官方云镜像"
    "中国|网易|mirrors.163.com|https/http|商业镜像"
    "中国|搜狐|mirrors.sohu.com|https/http|商业镜像"
    "中国|阿里云（杭州）|mirrors.aliyuncs.com|https/http|内网加速"
    "中国|腾讯云（北京）|mirrors.tencentyun.com|https/http|内网加速"
    "中国|华为云（北京）|mirrors.huaweicloud.com|https/http|内网加速"
    "中国|上海交大|mirrors.sjtug.sjtu.edu.cn|https/http|教育网"
    "中国|北京大学|mirrors.pku.edu.cn|https/http|教育网"
    "中国|北京外国语大学|mirrors.bfsu.edu.cn|https/http|教育网"
    "中国|北京交通大学|mirror.bjtu.edu.cn|https/http|教育网"
    "中国|兰州大学|mirror.lzu.edu.cn|https/http|教育网"
    "中国|重庆大学|mirrors.cqu.edu.cn|https/http|教育网"
    "中国|南方科技大学|mirrors.sustech.edu.cn|https/http|教育网"
    "中国|大连理工大学|mirror.dlut.edu.cn|https/http|教育网"
    "中国|东北大学|mirror.neu.edu.cn|https/http|教育网"
    "中国|浙江大学|mirrors.zju.edu.cn|https/http|教育网"
    "中国|中国移动|mirrors.163.com|https/http|运营商"
    "中国|中国电信|mirrors.aliyun.com|https/http|运营商"
)

MIRRORS_ASIA_OTHER=(
    "日本|京都大学|ftp.iij.ad.jp|https/http|教育网"
    "日本|筑波大学|ftp.tsukuba.wide.ad.jp|https/http|教育网"
    "日本|RIKEN|ftp.riken.jp|https/http|研究机构"
    "日本|JAIST|ftp.jaist.ac.jp|https/http|教育网"
    "韩国|KAIST|ftp.kaist.ac.kr|https/http|教育网"
    "韩国|Harukasan|mirror.kakao.com|https/http|商业镜像"
    "新加坡|NUS|downloads.nus.edu.sg|https/http|教育网"
    "新加坡|Singtel|mirror.singtel.com|https/http|运营商"
    "新加坡|DigitalOcean|mirror.digitalocean.com|https/http|云服务"
    "台湾|中央大学|ftp.yzu.edu.tw|https/http|教育网"
    "台湾|中华电信|mirror.hinet.net|https/http|运营商"
    "台湾|OSS Planet|mirror.ossplanet.net|https/http|社区镜像"
    "香港|HKIX|mirror.hkix.net|https/http|交换中心"
    "香港|CUHK|ftp.cuhk.edu.hk|https/http|教育网"
    "香港|HKU|ftp.hku.hk|https/http|教育网"
    "印度|IIT Madras|mirrors.iitm.ac.in|https/http|教育网"
    "印度|IIT Bombay|mirrors.iitb.ac.in|https/http|教育网"
    "越南|FPT|mirrors.fpt.vn|https/http|商业镜像"
    "泰国|Nectec|mirror.nectec.or.th|https/http|研究机构"
    "马来西亚|UM|mirror.um.edu.my|https/http|教育网"
    "印度尼西亚|UI|mirror.ui.ac.id|https/http|教育网"
)

MIRRORS_EUROPE=(
    "德国|柏林自由大学|ftp.fu-berlin.de|https/http|教育网"
    "德国|马克思普朗克研究所|ftp.mpi-inf.mpg.de|https/http|研究机构"
    "德国|Hetzner|mirror.hetzner.de|https/http|商业镜像"
    "英国|UK FAST|www.mirrorservice.org|https/http|社区镜像"
    "英国|Imperial College|ftp.doc.ic.ac.uk|https/http|教育网"
    "英国|Lancaster University|mirror.lancs.ac.uk|https/http|教育网"
    "法国|IRISA|ftp.irisa.fr|https/http|研究机构"
    "法国|CERN|mirror.cern.ch|https/http|研究机构"
    "法国|Obelink|ftp.obelink.fr|https/http|商业镜像"
    "荷兰|NLUUG|ftp.nluug.nl|https/http|社区镜像"
    "荷兰|Surfnet|ftp.surfnet.nl|https/http|教育网"
    "荷兰|Leiden University|mirror.leidenuniv.nl|https/http|教育网"
    "瑞典|Lund University|ftp.lu.se|https/http|教育网"
    "瑞典|Uppsala University|ftp.uu.se|https/http|教育网"
    "瑞典|Sunet|ftp.sunet.se|https/http|教育网"
    "瑞士|SWITCH|mirror.switch.ch|https/http|教育网"
    "瑞士|ETH Zurich|mirror.ethz.ch|https/http|教育网"
    "意大利|GARR|mirror.garr.it|https/http|教育网"
    "意大利|INAF|mirrors.inaf.it|https/http|研究机构"
    "西班牙|RedIRIS|ftp.rediris.es|https/http|教育网"
    "西班牙|Universitat de Valencia|mirror.uv.es|https/http|教育网"
    "俄罗斯|Yandex|mirror.yandex.ru|https/http|商业镜像"
    "俄罗斯|MSU|mirror.msu.ru|https/http|教育网"
    "波兰|PSNC|ftp.man.poznan.pl|https/http|教育网"
    "波兰|Warsaw University|ftp.icm.edu.pl|https/http|教育网"
    "捷克|CZ.NIC|mirror.nic.cz|https/http|社区镜像"
    "捷克|Charles University|ftp.cuni.cz|https/http|教育网"
    "奥地利|Vienna University|mirror.univie.ac.at|https/http|教育网"
    "比利时|Belnet|ftp.belnet.be|https/http|教育网"
    "芬兰|FUNET|ftp.funet.fi|https/http|教育网"
    "芬兰|OSS Planet EU|mirror.eu.ossplanet.net|https/http|社区镜像"
    "挪威|UiO|ftp.uio.no|https/http|教育网"
    "丹麦|Dotsrc|mirror.dotsrc.org|https/http|社区镜像"
    "爱尔兰|HEAnet|ftp.heanet.ie|https/http|教育网"
    "葡萄牙|FCCN|mirrors.fccn.pt|https/http|教育网"
    "希腊|University of Crete|ftp.cc.uoc.gr|https/http|教育网"
    "土耳其|ULAKBIM|mirror.ulakbim.gov.tr|https/http|研究机构"
)

MIRRORS_NA=(
    "美国|MIT|mirrors.mit.edu|https/http|教育网"
    "美国|Stanford|mirrors.stanford.edu|https/http|教育网"
    "美国|Berkeley|mirrors.berkeley.edu|https/http|教育网"
    "美国|Princeton|mirror.math.princeton.edu|https/http|教育网"
    "美国|Columbia|mirror.cc.columbia.edu|https/http|教育网"
    "美国|UCLA|mirror.claus.ucla.edu|https/http|教育网"
    "美国|UMass|mirror.cs.umass.edu|https/http|教育网"
    "美国|Oregon State|ftp.osuosl.org|https/http|开源实验室"
    "美国|Internet2|mirror.internet2.edu|https/http|科研网络"
    "美国|Rackspace|mirror.rackspace.com|https/http|商业镜像"
    "美国|DigitalOcean|mirrors.digitalocean.com|https/http|云服务"
    "美国|Linux Kernel|mirrors.kernel.org|https/http|官方镜像"
    "美国|Fremont Cabal|mirror.fcix.net|https/http|社区镜像"
    "加拿大|UBC|mirror.it.ubc.ca|https/http|教育网"
    "加拿大|MUUG|muug.ca|https/http|社区镜像"
    "加拿大|Digital Shape|mirror.dst.ca|https/http|商业镜像"
)

MIRRORS_OCEANIA=(
    "澳大利亚|AARNet|mirror.aarnet.edu.au|https/http|教育网"
    "澳大利亚|Internode|mirror.internode.on.net|https/http|运营商"
    "澳大利亚|WA Internet|mirror.wai.net.au|https/http|商业镜像"
    "新西兰|Waikato University|mirror.waikato.ac.nz|https/http|教育网"
    "新西兰|Auckland University|mirror.auckland.ac.nz|https/http|教育网"
)

MIRRORS_SA=(
    "巴西|UFSCar|mirror.ufscar.br|https/http|教育网"
    "巴西|UFPR|mirror.ufpr.br|https/http|教育网"
    "阿根廷|UNLP|mirrors.unlp.edu.ar|https/http|教育网"
    "阿根廷|UBA|mirror.uba.ar|https/http|教育网"
    "智利|Hostednode|mirror.hnd.cl|https/http|商业镜像"
    "哥伦比亚|FCIX|edgeuno-bog2.mm.fcix.net|https/http|交换中心"
)

MIRRORS_AFRICA=(
    "南非|University of Stellenbosch|mirror.sun.ac.za|https/http|教育网"
    "南非|Dimension Data|mirror.dimensiondata.com|https/http|商业镜像"
    "肯尼亚|KENET|kenet.ke|https/http|教育网"
    "埃及|EUN|mirror.eun.eg|https/http|教育网"
    "摩洛哥|CNRST|mirror.cnrst.ma|https/http|研究机构"
)

# 辅助函数
get_distro_codename() {
    local codename=""
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-${DEBIAN_CODENAME:-}}}"
    fi
    if [[ -z "$codename" ]] && command -v lsb_release >/dev/null 2>&1; then
        codename=$(lsb_release -cs 2>/dev/null)
    fi
    if [[ -z "$codename" ]]; then
        _echo "Unable to get distribution codename, please input manually:" "无法获取发行版代号，请手动输入："
        read -rp "> " codename
    fi
    echo "$codename"
}

get_default_components() {
    case "$OS_NAME" in
        debian|ubuntu|linuxmint|raspbian|zorin|deepin|kalilinux)
            if [[ "$OS_NAME" == "debian" ]]; then
                echo "main contrib non-free"
            elif [[ "$OS_NAME" == "ubuntu" ]]; then
                echo "main restricted universe multiverse"
            else
                echo "main"
            fi
            ;;
        rhel|centos|rocky|almalinux|oraclelinux|fedora)
            echo "baseos appstream"
            ;;
        openeuler|opencloudos)
            echo "OS"
            ;;
        arch)
            echo "main"
            ;;
        *)
            echo "main"
            ;;
    esac
}

# 从选定地区中选择镜像站
select_mirror_from_region() {
    local region_array_name="$1"
    eval "region_mirrors=(\"\${$region_array_name[@]}\")"
    
    local i=1
    _echo "Available mirrors in this region:" "该地区可用的镜像源："
    
    local current_country=""
    for mirror_entry in "${region_mirrors[@]}"; do
        IFS='|' read -r country name url protocols desc <<< "$mirror_entry"
        
        if [[ "$country" != "$current_country" ]]; then
            current_country="$country"
            echo ""
            printf "  ${COLOR_GREEN}== %s ==${COLOR_RESET}\n" "$current_country"
        fi
        
        printf "%3d) %-20s [%s] %s\n" "$i" "$name" "$protocols" "${desc:+"($desc)"}"
        ((i++))
    done
    
    echo ""
    echo "  0) $(_echo "Back to region selection" "返回地区选择")"
    read -rp "$(_echo "Please select mirror [0-$((i-1))]: " "请选择镜像 [0-$((i-1))]：") " choice

    if [[ "$choice" == "0" ]]; then
        run_system_mirror
        return
    fi
    
    if [[ "$choice" -le ${#region_mirrors[@]} ]]; then
        local selected_entry="${region_mirrors[$((choice-1))]}"
        IFS='|' read -r country name mirror_url protocols desc <<< "$selected_entry"
        
        local protocol="$OPT_PROTOCOL"
        if [[ "$protocols" == *"https"* && "$protocols" == *"http"* ]]; then
            echo "$(_echo "Protocol available: https/http" "可用协议：https/http")"
            read -rp "$(_echo "Use https? (y/n, default y): " "使用 https？(y/n，默认 y)：") " use_https
            if [[ "$use_https" == "n" || "$use_https" == "N" ]]; then
                protocol="http"
            fi
        fi
        
        apply_mirror "$mirror_url" "$name" "$protocol" "$OPT_BRANCH" "$OPT_COMPONENTS"
    else
        _echo "Invalid choice." "无效选择。"
        select_mirror_from_region "$region_array_name"
    fi
}

# 应用镜像源
apply_mirror() {
    local mirror_domain="$1"
    local mirror_name="$2"
    local protocol="${3:-https}"
    local branch="${4:-}"
    local components="${5:-}"
    
    _echo "Applying mirror: $mirror_name ($mirror_domain)" "正在应用镜像源：$mirror_name ($mirror_domain)"
    
    local codename
    codename=$(get_distro_codename)
    local releasever="$OS_VERSION"
    
    case "$OS_NAME" in
        debian|ubuntu|linuxmint|raspbian|zorin|deepin|kalilinux)
            local comp="${components:-$(get_default_components)}"
            local sources_list=""
            
            if [[ "$OS_NAME" == "ubuntu" ]]; then
                sources_list="deb ${protocol}://${mirror_domain}/ubuntu $codename $comp\n"
                sources_list+="deb ${protocol}://${mirror_domain}/ubuntu ${codename}-updates $comp\n"
                sources_list+="deb ${protocol}://${mirror_domain}/ubuntu ${codename}-security $comp\n"
                sources_list+="deb ${protocol}://${mirror_domain}/ubuntu ${codename}-backports $comp\n"
            else
                sources_list="deb ${protocol}://${mirror_domain}/debian $codename $comp\n"
                sources_list+="deb ${protocol}://${mirror_domain}/debian ${codename}-updates $comp\n"
                sources_list+="deb ${protocol}://${mirror_domain}/debian-security ${codename}-security $comp\n"
                sources_list+="deb ${protocol}://${mirror_domain}/debian ${codename}-backports $comp\n"
            fi
            
            if [[ "$OPT_DRY_RUN" == "true" ]]; then
                _echo "[DRY-RUN] Would write to /etc/apt/sources.list:" "[模拟运行] 将写入 /etc/apt/sources.list："
                echo -e "$sources_list"
            else
                backup_file "/etc/apt/sources.list" "system_mirror"
                safe_write "/etc/apt/sources.list" "$sources_list" "system_mirror"
                _echo "APT sources updated. Running apt update..." "APT 源已更新，正在更新软件包列表..."
                apt update
            fi
            ;;
            
        centos|rocky|almalinux|oraclelinux|fedora|rhel)
            local repo_dir="/etc/yum.repos.d"
            local releasever_major="${releasever%%.*}"
            local repo_content=""
            
            repo_content="[baseos]\n"
            repo_content+="name=${OS_NAME} \$releasever - BaseOS\n"
            repo_content+="baseurl=${protocol}://${mirror_domain}/${OS_NAME}/\$releasever/BaseOS/\$basearch/os/\n"
            repo_content+="gpgcheck=1\n"
            repo_content+="enabled=1\n\n"
            repo_content+="[appstream]\n"
            repo_content+="name=${OS_NAME} \$releasever - AppStream\n"
            repo_content+="baseurl=${protocol}://${mirror_domain}/${OS_NAME}/\$releasever/AppStream/\$basearch/os/\n"
            repo_content+="gpgcheck=1\n"
            repo_content+="enabled=1\n"
            
            if [[ "$OPT_DRY_RUN" == "true" ]]; then
                _echo "[DRY-RUN] Would write to $repo_dir/${OS_NAME}.repo:" "[模拟运行] 将写入 $repo_dir/${OS_NAME}.repo："
                echo -e "$repo_content"
            else
                backup_file "$repo_dir/${OS_NAME}.repo" "system_mirror"
                safe_write "$repo_dir/${OS_NAME}.repo" "$repo_content" "system_mirror"
                _echo "YUM/DNF sources updated. Running makecache..." "YUM/DNF 源已更新，正在更新缓存..."
                if command -v dnf &>/dev/null; then
                    dnf makecache
                else
                    yum makecache
                fi
            fi
            ;;
            
        arch)
            local mirrorlist="/etc/pacman.d/mirrorlist"
            local server_line="Server = ${protocol}://${mirror_domain}/\$repo/os/\$arch"
            
            if [[ "$OPT_DRY_RUN" == "true" ]]; then
                _echo "[DRY-RUN] Would add to $mirrorlist:" "[模拟运行] 将添加到 $mirrorlist："
                echo "$server_line"
            else
                backup_file "$mirrorlist" "system_mirror"
                echo "$server_line" | cat - "$mirrorlist" > "${mirrorlist}.tmp"
                mv "${mirrorlist}.tmp" "$mirrorlist"
                _echo "Pacman mirror updated. Running pacman -Sy..." "Pacman 源已更新，正在刷新..."
                pacman -Sy
            fi
            ;;
            
        *)
            _echo "Unsupported distribution: $OS_NAME" "不支持的发行版：$OS_NAME"
            return 1
            ;;
    esac
    
    log_info "$(_echo "Mirror applied: $mirror_name ($mirror_domain)" "已应用镜像源：$mirror_name ($mirror_domain)")"
}

# 官方源恢复
apply_official_mirror() {
    _echo "Restoring official sources..." "正在恢复官方源..."
    
    case "$PKG_MANAGER" in
        apt)
            if restore_file "/etc/apt/sources.list"; then
                apt update
            fi
            ;;
        dnf|yum)
            if restore_file "/etc/yum.repos.d/"*; then
                if command -v dnf &>/dev/null; then
                    dnf makecache
                else
                    yum makecache
                fi
            fi
            ;;
        pacman)
            if restore_file "/etc/pacman.d/mirrorlist"; then
                pacman -Sy
            fi
            ;;
        *)
            _echo "No backup found for official sources." "未找到官方源备份。"
            ;;
    esac
}

# 主函数
run_system_mirror() {
    log_info "$(_echo "===== System Mirror Optimization =====" "===== 系统镜像优化 =====")"

    if [[ -n "$OPT_MIRROR" ]]; then
        apply_mirror "$OPT_MIRROR" "$OPT_MIRROR" "$OPT_PROTOCOL" "$OPT_BRANCH" "$OPT_COMPONENTS"
        return $?
    fi

    _echo "Select region:" "请选择地区："
    echo "1) $(_echo "Asia (China)" "亚洲（中国）")"
    echo "2) $(_echo "Asia (Other)" "亚洲（其他国家和地区）")"
    echo "3) $(_echo "Europe" "欧洲")"
    echo "4) $(_echo "North America" "北美洲")"
    echo "5) $(_echo "South America" "南美洲")"
    echo "6) $(_echo "Oceania" "大洋洲")"
    echo "7) $(_echo "Africa" "非洲")"
    echo "8) $(_echo "Back to main menu" "返回主菜单")"
    read -rp "$(_echo "Choice [1-8]: " "请选择 [1-8]：") " region_choice

    case $region_choice in
        1) select_mirror_from_region "MIRRORS_ASIA_CHINA" ;;
        2) select_mirror_from_region "MIRRORS_ASIA_OTHER" ;;
        3) select_mirror_from_region "MIRRORS_EUROPE" ;;
        4) select_mirror_from_region "MIRRORS_NA" ;;
        5) select_mirror_from_region "MIRRORS_SA" ;;
        6) select_mirror_from_region "MIRRORS_OCEANIA" ;;
        7) select_mirror_from_region "MIRRORS_AFRICA" ;;
        8) return ;;
        *) _echo "Invalid choice." "无效选择。" ; run_system_mirror ;;
    esac
}

# ==================================================
# 主脚本函数 (install.sh 的核心部分)
# ==================================================

ask_language() {
    echo "Please select language / 请选择语言:"
    echo "1) English"
    echo "2) 中文"
    read -rp "Choice [1-2]: " lang_choice
    case "$lang_choice" in
        2) OPT_LANG="zh" ;;
        *) OPT_LANG="en" ;;
    esac
}

init_environment() {
    mkdir -p "$DEVBOOST_BACKUP_DIR" "$DEVBOOST_LOG_DIR"
    touch "$DEVBOOST_LOG_FILE"
    touch "$DEVBOOST_MANIFEST"

    log_info "========== devboost 启动 =========="
    log_info "日志文件: $DEVBOOST_LOG_FILE"
    log_info "备份目录: $DEVBOOST_BACKUP_DIR"

    export DEVBOOST_LANG="$OPT_LANG"
    # 设置 LANG_ZH 用于模块中旧的语言判断
    LANG_ZH=false
    [[ "$OPT_LANG" == "zh" ]] && LANG_ZH=true

    detect_system
    log_info "系统信息: OS=$OS_NAME, ENV=$ENV_TYPE, PKG_MGR=$PKG_MANAGER, NETWORK=$NETWORK_STATUS"
}

show_menu() {
    echo ""
    if [[ "$OPT_LANG" == "zh" ]]; then
        echo "========== devboost 优化工具 =========="
    else
        echo "========== devboost Optimizer =========="
    fi

    local i=1
    local -a module_names=()
    local -a module_descs=()
    local -a module_descs_zh=()

    while IFS='|' read -r name desc zh; do
        module_names[$i]="$name"
        module_descs[$i]="$desc"
        module_descs_zh[$i]="$zh"
        if [[ "$OPT_LANG" == "zh" ]]; then
            printf "%d. %s\n" "$i" "${zh:-$name}"
        else
            printf "%d. %s\n" "$i" "${desc:-$name}"
        fi
        ((i++))
    done < <(discover_modules)

    local module_count=${#module_names[@]}
    echo "$((module_count+1))) $(_echo "Run All" "全部执行")"
    echo "0) $(_echo "Exit" "退出")"
    echo "========================================"
    read -rp "$(_echo "Please select [0-$((module_count+1))]: " "请选择 [0-$((module_count+1))]：") " choice

    if [[ "$choice" == "0" ]]; then
        exit 0
    elif [[ "$choice" -le $module_count ]]; then
        run_module "${module_names[$choice]}"
    elif [[ "$choice" -eq $((module_count+1)) ]]; then
        run_all
    else
        _echo "Invalid choice." "无效选择。"
        show_menu
    fi
}

run_module() {
    local module="$1"
    # 模块函数名约定为 run_模块名
    local func_name="run_${module}"

    if declare -f "$func_name" >/dev/null; then
        log_info "开始运行模块: $module"
        export OPT_MIRROR OPT_PROTOCOL OPT_BRANCH OPT_COMPONENTS
        "$func_name"
    else
        log_error "模块 $module 缺少入口函数 $func_name"
        exit 1
    fi
}

run_all() {
    local modules=()
    while IFS='|' read -r name desc zh; do
        modules+=("$name")
    done < <(discover_modules)

    if [[ ${#modules[@]} -eq 0 ]]; then
        _echo "No modules found to run." "没有找到可运行的模块。"
        return
    fi

    for mod in "${modules[@]}"; do
        echo ""
        if ! confirm "$(_echo "Run $mod optimization?" "是否执行 $mod 优化？")" ; then
            log_info "用户跳过模块: $mod"
            continue
        fi
        run_module "$mod"
    done
    log_info "全部模块执行完毕。"
}

rollback() {
    perform_rollback
}

# ---------- 参数解析 ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        --dns)
            SPECIFIC_MODULE="dns"
            shift
            ;;
        --system-mirror)
            SPECIFIC_MODULE="system_mirror"
            shift
            ;;
        --devtools-mirror)
            SPECIFIC_MODULE="devtools_mirror"
            shift
            ;;
        --github)
            SPECIFIC_MODULE="github"
            shift
            ;;
        --rollback)
            SPECIFIC_MODULE="rollback"
            shift
            ;;
        --mirror)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "错误: --mirror 需要参数"
                exit 1
            fi
            OPT_MIRROR="$2"
            shift 2
            ;;
        --protocol)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "错误: --protocol 需要参数"
                exit 1
            fi
            OPT_PROTOCOL="$2"
            shift 2
            ;;
        --branch)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "错误: --branch 需要参数"
                exit 1
            fi
            OPT_BRANCH="$2"
            shift 2
            ;;
        --components)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "错误: --components 需要参数"
                exit 1
            fi
            OPT_COMPONENTS="$2"
            shift 2
            ;;
        --lang)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "错误: --lang 需要参数"
                exit 1
            fi
            OPT_LANG="$2"
            shift 2
            ;;
        --dry-run)
            OPT_DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "用法: ./install.sh [选项]"
            echo "选项:"
            echo "  -y, --yes           自动确认所有提示"
            echo "  --dns                仅运行DNS优化模块"
            echo "  --system-mirror      仅运行系统镜像优化模块"
            echo "  --devtools-mirror    仅运行开发工具镜像优化模块"
            echo "  --github             仅运行GitHub访问优化模块"
            echo "  --rollback           执行回滚操作"
            echo "  --mirror <名称/URL>  指定镜像站（如 aliyun, tuna 或直接输入URL）"
            echo "  --protocol <http|https> 指定协议（默认 https）"
            echo "  --branch <分支>      指定仓库分支（如 updates, security）"
            echo "  --components <组件>  指定组件列表（如 main contrib non-free）"
            echo "  --lang <zh|en>       设置语言（默认 en）"
            echo "  --dry-run            模拟运行，不实际修改任何文件"
            echo "  -h, --help           显示此帮助"
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# ---------- 主流程 ----------
main() {
    # 交互模式下，如果没有指定语言且非自动确认，则询问语言
    if [[ -z "$SPECIFIC_MODULE" && "$OPT_LANG" == "en" && "$AUTO_CONFIRM" == false ]]; then
        ask_language
    fi

    init_environment

    if [[ "$SPECIFIC_MODULE" == "rollback" ]]; then
        rollback
        exit 0
    fi

    if [[ -n "$SPECIFIC_MODULE" ]]; then
        run_module "$SPECIFIC_MODULE"
    else
        show_menu
    fi

    log_info "========== devboost 结束 =========="
}

main