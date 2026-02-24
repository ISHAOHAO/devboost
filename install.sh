#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# devboost 主脚本
# 功能：一键检测、修复、优化开发网络与基础环境
# 支持 Linux / macOS / WSL
# ==================================================

# 获取脚本真实路径（兼容管道执行和本地执行）
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
else
    SCRIPT_PATH="$0"
fi

if [[ -f "$SCRIPT_PATH" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
    # 管道执行，尝试使用当前目录作为项目根目录
    SCRIPT_DIR="$(pwd)"
    # 检查当前目录是否包含必要的子目录
    if [[ ! -d "$SCRIPT_DIR/lib" || ! -d "$SCRIPT_DIR/modules" ]]; then
        echo "错误：无法自动确定项目根目录。"
        echo "请先使用 git clone 克隆项目，然后在项目目录内执行："
        echo "  git clone https://github.com/ISHAOHAO/devboost.git"
        echo "  cd devboost"
        echo "  ./install.sh"
        exit 1
    fi
fi

export DEVBOOST_ROOT="$SCRIPT_DIR"
export DEVBOOST_BACKUP_DIR="$DEVBOOST_ROOT/backups"
export DEVBOOST_LOG_DIR="$DEVBOOST_ROOT/logs"
export DEVBOOST_LOG_FILE="$DEVBOOST_LOG_DIR/devboost.log"
export DEVBOOST_MANIFEST="$DEVBOOST_BACKUP_DIR/manifest.txt"

# 加载公共库
source "$DEVBOOST_ROOT/lib/common.sh"

# 全局变量
AUTO_CONFIRM=false          # 是否自动确认（-y 参数）
SPECIFIC_MODULE=""          # 指定运行的模块（如 --dns）

# 新增选项变量
OPT_MIRROR=""               # 指定镜像站名称或URL
OPT_PROTOCOL="https"         # 协议（http/https）
OPT_BRANCH=""                # 仓库分支（如 updates, security）
OPT_COMPONENTS=""            # 组件列表（如 main contrib non-free）
OPT_LANG="en"                # 语言（en/zh）
OPT_DRY_RUN=false           # 是否仅模拟执行

# 解析命令行参数
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

# 显示主菜单（交互模式）
show_menu() {
    echo ""
    if [[ "$OPT_LANG" == "zh" ]]; then
        echo "========== devboost 优化工具 =========="
    else
        echo "========== devboost Optimizer =========="
    fi

    local i=1
    local -a module_names=()   # 初始化为空数组
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
    # 添加“全部执行”选项
    echo "$((module_count+1))) $(_echo "Run All" "全部执行")"
    # 添加“退出”选项
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
    
    # 导出 OPT_* 变量，供模块使用
    export OPT_MIRROR OPT_PROTOCOL OPT_BRANCH OPT_COMPONENTS

    source "$module_script"
    # 每个模块必须实现 run_${module} 函数
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

# 主流程
main() {
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