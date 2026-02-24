#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# devboost 主脚本（支持远程一键运行）
# 功能：一键检测、修复、优化开发网络与基础环境
# 支持 Linux / macOS / WSL
# ==================================================

# 定义 GitHub 仓库 raw 文件的基础 URL
GITHUB_RAW_BASE="https://raw.githubusercontent.com/ISHAOHAO/devboost/main"

# 需要下载的核心文件和模块列表（用于远程模式）
REQUIRED_LIBS=(
    "lib/common.sh"
    "lib/detect.sh"
    "lib/rollback.sh"
)
REQUIRED_MODULES=(
    "modules/dns.sh"
    "modules/system_mirror.sh"
    "modules/devtools_mirror.sh"
    "modules/github.sh"
)

# 判断是否在管道执行（远程模式）
is_pipe_execution() {
    # 如果 $0 包含 /dev/fd/ 或标准输入不是终端，则认为是在管道执行
    [[ "$0" == *"/dev/fd/"* ]] || [[ ! -t 0 ]]
}

# 下载文件函数
download_file() {
    local url="$1"
    local output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output"
    else
        echo "错误：需要 curl 或 wget 来下载依赖文件。" >&2
        exit 1
    fi
}

# 远程模式：创建临时目录并下载所有必要文件
setup_remote_environment() {
    echo "检测到远程执行模式，正在准备环境..."
    # 创建临时目录
    TEMP_DIR=$(mktemp -d -t devboost.XXXXXX)
    export DEVBOOST_ROOT="$TEMP_DIR"
    export DEVBOOST_BACKUP_DIR="$TEMP_DIR/backups"
    export DEVBOOST_LOG_DIR="$TEMP_DIR/logs"
    export DEVBOOST_LOG_FILE="$DEVBOOST_LOG_DIR/devboost.log"
    export DEVBOOST_MANIFEST="$DEVBOOST_BACKUP_DIR/manifest.txt"

    # 创建必要的子目录
    mkdir -p "$DEVBOOST_ROOT/lib" "$DEVBOOST_ROOT/modules" \
             "$DEVBOOST_BACKUP_DIR" "$DEVBOOST_LOG_DIR"

    # 下载 lib 文件
    for lib in "${REQUIRED_LIBS[@]}"; do
        local filename=$(basename "$lib")
        echo "下载 $lib ..."
        download_file "$GITHUB_RAW_BASE/$lib" "$DEVBOOST_ROOT/lib/$filename"
    done

    # 下载 modules 文件
    for mod in "${REQUIRED_MODULES[@]}"; do
        local filename=$(basename "$mod")
        echo "下载 $mod ..."
        download_file "$GITHUB_RAW_BASE/$mod" "$DEVBOOST_ROOT/modules/$filename"
    done

    echo "环境准备完成，临时目录: $TEMP_DIR"
    # 注册退出时清理临时目录
    trap 'rm -rf "$TEMP_DIR"' EXIT
}

# 初始化环境（创建目录、检测系统）
init_environment() {
    mkdir -p "$DEVBOOST_BACKUP_DIR" "$DEVBOOST_LOG_DIR"
    touch "$DEVBOOST_LOG_FILE"
    touch "$DEVBOOST_MANIFEST"

    log_info "========== devboost 启动 =========="
    log_info "日志文件: $DEVBOOST_LOG_FILE"
    log_info "备份目录: $DEVBOOST_BACKUP_DIR"

    # 设置语言环境变量（供模块使用）
    export DEVBOOST_LANG="$OPT_LANG"

    # 加载系统检测结果
    source "$DEVBOOST_ROOT/lib/detect.sh"
    detect_system
    log_info "系统信息: OS=$OS_NAME, ENV=$ENV_TYPE, PKG_MGR=$PKG_MANAGER, NETWORK=$NETWORK_STATUS"
}

# 主流程
main() {
    # 确定项目根目录
    if is_pipe_execution; then
        # 远程执行模式：自动下载依赖到临时目录
        setup_remote_environment
    else
        # 本地执行模式：使用脚本所在目录
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        export DEVBOOST_ROOT="$SCRIPT_DIR"
        export DEVBOOST_BACKUP_DIR="$DEVBOOST_ROOT/backups"
        export DEVBOOST_LOG_DIR="$DEVBOOST_ROOT/logs"
        export DEVBOOST_LOG_FILE="$DEVBOOST_LOG_DIR/devboost.log"
        export DEVBOOST_MANIFEST="$DEVBOOST_BACKUP_DIR/manifest.txt"
    fi

    # 加载公共库（现在 DEVBOOST_ROOT 已正确设置）
    source "$DEVBOOST_ROOT/lib/common.sh"

    # 全局变量
    AUTO_CONFIRM=false
    SPECIFIC_MODULE=""
    OPT_MIRROR=""
    OPT_PROTOCOL="https"
    OPT_BRANCH=""
    OPT_COMPONENTS=""
    OPT_LANG="en"
    OPT_DRY_RUN=false

    # 解析命令行参数（此部分与之前相同，请保留原有解析代码）
    # ...（从你提供的代码中复制整个 while 循环和 case 语句到这里）
    # 注意：需要确保解析部分在 source common.sh 之后，因为要用到 log_error 等函数

    # 初始化环境
    init_environment

    if [[ "$SPECIFIC_MODULE" == "rollback" ]]; then
        source "$DEVBOOST_ROOT/lib/rollback.sh"
        perform_rollback
        exit 0
    fi

    if [[ -n "$SPECIFIC_MODULE" ]]; then
        run_module "$SPECIFIC_MODULE"
    else
        show_menu
    fi

    log_info "========== devboost 结束 =========="
}

# 启动主流程
main "$@"