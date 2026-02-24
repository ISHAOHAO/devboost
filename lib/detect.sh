#!/usr/bin/env bash
# 系统检测模块
# 输出全局变量：
#   OS_NAME, OS_VERSION, ENV_TYPE, PKG_MANAGER, HAS_SYSTEMD, NETWORK_STATUS

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