#!/usr/bin/env bash
# Module: github
# Description: GitHub Access Optimization
# Description(zh): GitHub访问优化
# GitHub访问优化模块

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

    # 提示用户确认
    if ! confirm "修改 hosts 文件可能带来安全风险，是否继续？"; then
        log_info "用户取消"
        return
    fi

    # 获取最新 GitHub IP（可以调用接口或使用预定义列表）
    # 这里使用预定义的常用 IP（实际应动态获取）
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

    # 检查是否已存在 GitHub Hosts 区块，如果存在则替换，否则追加
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

    # 写入 profile 文件（如 /etc/profile.d/proxy.sh 或 ~/.bashrc）
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