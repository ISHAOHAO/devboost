#!/usr/bin/env bash
# ChangeMirrorsLite.sh - 系统镜像优化精简版
# 仅包含系统镜像切换功能，无交互菜单

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEVBOOST_ROOT="$SCRIPT_DIR"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/modules/system_mirror.sh"

# 默认参数
OPT_MIRROR=""
OPT_PROTOCOL="https"
OPT_BRANCH=""
OPT_COMPONENTS=""
OPT_LANG="en"
OPT_DRY_RUN=false
AUTO_CONFIRM=false

# 解析参数（精简）
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mirror) OPT_MIRROR="$2"; shift 2 ;;
        --protocol) OPT_PROTOCOL="$2"; shift 2 ;;
        --branch) OPT_BRANCH="$2"; shift 2 ;;
        --components) OPT_COMPONENTS="$2"; shift 2 ;;
        --lang) OPT_LANG="$2"; shift 2 ;;
        --dry-run) OPT_DRY_RUN=true; shift ;;
        -y|--yes) AUTO_CONFIRM=true; shift ;;
        -h|--help)
            echo "用法: ./ChangeMirrorsLite.sh [选项]"
            echo "选项:"
            echo "  --mirror <名称/URL>  指定镜像站（如 aliyun, tuna 或完整URL）"
            echo "  --protocol <http|https> 协议（默认 https）"
            echo "  --branch <分支>      指定仓库分支（如 updates, security）"
            echo "  --components <组件>  指定组件列表（如 main contrib non-free）"
            echo "  --lang <zh|en>       设置语言（默认 en）"
            echo "  --dry-run            模拟运行，不实际修改"
            echo "  -y, --yes            自动确认"
            exit 0
            ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 初始化
detect_system
export DEVBOOST_LANG="$OPT_LANG"
export OPT_MIRROR OPT_PROTOCOL OPT_BRANCH OPT_COMPONENTS OPT_DRY_RUN AUTO_CONFIRM

# 运行系统镜像优化
run_system_mirror