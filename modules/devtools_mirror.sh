#!/usr/bin/env bash
# 开发工具镜像优化模块（npm/pip/docker等）
# Module: devtools_mirror
# Description: Development Tools Mirror Optimization (npm/pip/docker)
# Description(zh): 开发工具镜像优化 (npm/pip/docker)

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
        # 备份当前配置？npm 配置在用户目录，无需系统级备份，但可记录
    fi
}

optimize_pnpm() {
    log_info "配置 pnpm 镜像"
    local current_registry=$(pnpm config get registry 2>/dev/null)
    echo "当前 pnpm registry: $current_registry"
    # 类似 npm
    echo "选择 pnpm 镜像："
    echo "1. 淘宝镜像 (https://registry.npmmirror.com)"
    echo "2. 华为云 (https://mirrors.huaweicloud.com/repository/npm/)"
    echo "3. 自定义"
    read -rp "请选择 [1-3]: " choice
    # ... 省略类似代码
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

    # 备份原 daemon.json
    if [[ -f "$daemon_json" ]]; then
        backup_file "$daemon_json" "docker"
    fi

    # 读取现有配置或新建
    local tmp_config
    if [[ -f "$daemon_json" ]]; then
        tmp_config=$(cat "$daemon_json")
    else
        tmp_config="{}"
    fi

    # 使用 jq 添加 registry-mirrors 数组（如果 jq 不存在则手动处理）
    if check_command jq; then
        echo "$tmp_config" | jq --arg url "$registry_mirror" '.["registry-mirrors"] = [$url]' > "$daemon_json"
    else
        # 简单处理：假设没有其他配置
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