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
    TEMP_DIR=$(mktemp -d -t devboost.XXXXXX)
    export DEVBOOST_ROOT="$TEMP_DIR"
    export DEVBOOST_BACKUP_DIR="$TEMP_DIR/backups"
    export DEVBOOST_LOG_DIR="$TEMP_DIR/logs"
    export DEVBOOST_LOG_FILE="$DEVBOOST_LOG_DIR/devboost.log"
    export DEVBOOST_MANIFEST="$DEVBOOST_BACKUP_DIR/manifest.txt"

    mkdir -p "$DEVBOOST_ROOT/lib" "$DEVBOOST_ROOT/modules" \
             "$DEVBOOST_BACKUP_DIR" "$DEVBOOST_LOG_DIR"

    for lib in "${REQUIRED_LIBS[@]}"; do
        local filename=$(basename "$lib")
        echo "下载 $lib ..."
        download_file "$GITHUB_RAW_BASE/$lib" "$DEVBOOST_ROOT/lib/$filename"
    done

    for mod in "${REQUIRED_MODULES[@]}"; do
        local filename=$(basename "$mod")
        echo "下载 $mod ..."
        download_file "$GITHUB_RAW_BASE/$mod" "$DEVBOOST_ROOT/modules/$filename"
    done

    echo "环境准备完成，临时目录: $TEMP_DIR"
    trap 'rm -rf "$TEMP_DIR"' EXIT
}

# 确定项目根目录
if is_pipe_execution; then
    setup_remote_environment
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export DEVBOOST_ROOT="$SCRIPT_DIR"
    export DEVBOOST_BACKUP_DIR="$DEVBOOST_ROOT/backups"
    export DEVBOOST_LOG_DIR="$DEVBOOST_ROOT/logs"
    export DEVBOOST_LOG_FILE="$DEVBOOST_LOG_DIR/devboost.log"
    export DEVBOOST_MANIFEST="$DEVBOOST_BACKUP_DIR/manifest.txt"
fi

# 加载公共库
source "$DEVBOOST_ROOT/lib/common.sh"

# ---------- 全局变量 ----------
AUTO_CONFIRM=false
SPECIFIC_MODULE=""
OPT_MIRROR=""
OPT_PROTOCOL="https"
OPT_BRANCH=""
OPT_COMPONENTS=""
OPT_LANG="en"
OPT_DRY_RUN=false

# ---------- 函数定义 ----------

# 询问用户选择语言
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

# 初始化环境
init_environment() {
    mkdir -p "$DEVBOOST_BACKUP_DIR" "$DEVBOOST_LOG_DIR"
    touch "$DEVBOOST_LOG_FILE"
    touch "$DEVBOOST_MANIFEST"

    log_info "========== devboost 启动 =========="
    log_info "日志文件: $DEVBOOST_LOG_FILE"
    log_info "备份目录: $DEVBOOST_BACKUP_DIR"

    export DEVBOOST_LANG="$OPT_LANG"

    source "$DEVBOOST_ROOT/lib/detect.sh"
    detect_system
    log_info "系统信息: OS=$OS_NAME, ENV=$ENV_TYPE, PKG_MGR=$PKG_MANAGER, NETWORK=$NETWORK_STATUS"
}

# 显示主菜单
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

# 运行指定模块
run_module() {
    local module="$1"
    local module_script="$DEVBOOST_ROOT/modules/${module}.sh"

    if [[ ! -f "$module_script" ]]; then
        log_error "模块脚本不存在: $module_script"
        exit 1
    fi

    log_info "开始运行模块: $module"
    
    export OPT_MIRROR OPT_PROTOCOL OPT_BRANCH OPT_COMPONENTS

    source "$module_script"
    if declare -f "run_${module}" >/dev/null; then
        "run_${module}"
    else
        log_error "模块 $module 缺少入口函数 run_${module}"
        exit 1
    fi
}

# 全部执行
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

# 回滚操作
rollback() {
    source "$DEVBOOST_ROOT/lib/rollback.sh"
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