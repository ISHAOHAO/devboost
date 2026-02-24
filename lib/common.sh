#!/usr/bin/env bash
# 公共函数库：日志、备份、回滚、确认、网络检测等

# 日志函数
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$DEVBOOST_LOG_FILE" >&2
}

# 确认函数（受 AUTO_CONFIRM 影响）
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
# 用法: backup_file <文件路径> [操作标识]
# 返回: 备份文件路径
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
    # 记录到清单: 原始路径|备份路径|操作标识|时间戳
    echo "$file|$backup_path|$tag|$timestamp" >> "$DEVBOOST_MANIFEST"
    log_info "已备份: $file -> $backup_path"
    echo "$backup_path"
}

# 恢复单个文件
# 用法: restore_file <原始文件路径>
restore_file() {
    local original="$1"
    # 从清单中找出所有匹配原始路径的行，按时间戳排序取最后一个
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

# 写入文件并备份（如果文件已存在）
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
if [[ -t 1 ]]; then  # 判断是否为终端
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

# 发现可用模块
discover_modules() {
    local modules=()
    for modfile in "$DEVBOOST_ROOT"/modules/*.sh; do
        if [[ -f "$modfile" ]]; then
            local modname desc desc_zh
            modname=$(basename "$modfile" .sh)
            # 跳过 all_in_one.sh 等特殊模块
            [[ "$modname" == "all_in_one" ]] && continue

            # 提取描述（允许注释前有空格）
            desc=$(grep -E '^# *Description:' "$modfile" | head -1 | sed 's/^#[[:space:]]*Description:[[:space:]]*//')
            desc_zh=$(grep -E '^# *Description\(zh\):' "$modfile" | head -1 | sed 's/^#[[:space:]]*Description(zh):[[:space:]]*//')

            # 如果描述为空，使用模块名作为后备
            if [[ -z "$desc" ]]; then
                desc="$modname"
            fi
            if [[ -z "$desc_zh" ]]; then
                desc_zh="$modname"
            fi

            modules+=("$modname|$desc|$desc_zh")
        fi
    done
    printf '%s\n' "${modules[@]}"
}

# 多语言输出函数（依赖 DEVBOOST_LANG 环境变量）
_echo() {
    local en="$1"
    local zh="$2"
    if [[ "${DEVBOOST_LANG}" == "zh" ]]; then
        echo "$zh"
    else
        echo "$en"
    fi
}

# 发现可用模块
discover_modules() {
    local modules=()
    for modfile in "$DEVBOOST_ROOT"/modules/*.sh; do
        if [[ -f "$modfile" ]]; then
            local modname desc desc_zh
            modname=$(basename "$modfile" .sh)
            # 跳过 all_in_one.sh 等特殊模块
            [[ "$modname" == "all_in_one" ]] && continue
            desc=$(grep -E '^# Description:' "$modfile" | head -1 | sed 's/^# Description: //')
            desc_zh=$(grep -E '^# Description\(zh\):' "$modfile" | head -1 | sed 's/^# Description(zh): //')
            modules+=("$modname|$desc|$desc_zh")
        fi
    done
    printf '%s\n' "${modules[@]}"
}
# 发现可用模块
discover_modules() {
    local modules=()
    for modfile in "$DEVBOOST_ROOT"/modules/*.sh; do
        if [[ -f "$modfile" ]]; then
            local modname desc desc_zh
            modname=$(basename "$modfile" .sh)
            # 跳过 all_in_one.sh 等特殊模块
            [[ "$modname" == "all_in_one" ]] && continue

            # 提取描述（允许注释前有空格）
            desc=$(grep -E '^# *Description:' "$modfile" | head -1 | sed 's/^#[[:space:]]*Description:[[:space:]]*//')
            desc_zh=$(grep -E '^# *Description\(zh\):' "$modfile" | head -1 | sed 's/^#[[:space:]]*Description(zh):[[:space:]]*//')

            # 如果描述为空，使用模块名作为后备
            if [[ -z "$desc" ]]; then
                desc="$modname"
            fi
            if [[ -z "$desc_zh" ]]; then
                desc_zh="$modname"
            fi

            modules+=("$modname|$desc|$desc_zh")
        fi
    done
    printf '%s\n' "${modules[@]}"
}
