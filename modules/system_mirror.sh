#!/usr/bin/env bash
# 系统包管理器镜像优化模块
# 支持 Debian 系、RHEL 系、国产发行版等
# 多语言支持（中文/英文）
# Module: system_mirror
# Description: System Package Manager Mirror Optimization
# Description(zh): 系统包管理器镜像优化

# 初始化语言（从环境变量或参数获取，稍后在主脚本设置）
LANG_ZH=false
if [[ "${DEVBOOST_LANG}" == "zh_CN" || "${DEVBOOST_LANG}" == "zh" ]]; then
    LANG_ZH=true
fi

# 输出函数（支持中英文）
_echo() {
    local en="$1"
    local zh="$2"
    if $LANG_ZH; then
        echo "$zh"
    else
        echo "$en"
    fi
}

# 获取发行版信息（复用 detect.sh 中的 OS_NAME, OS_VERSION）
# 获取完整版本号、代号
get_distro_info() {
    # 已经由 detect.sh 设置了 OS_NAME, OS_VERSION
    # 尝试获取代号
    local codename=""
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-${DEBIAN_CODENAME:-}}}"
    fi
    if [[ -z "$codename" ]] && command -v lsb_release >/dev/null 2>&1; then
        codename=$(lsb_release -cs 2>/dev/null)
    fi
    echo "$codename"
}

# 镜像源列表定义（按发行版分类）
# 格式：镜像名称|URL模板（使用占位符 {protocol} {mirror} {distro_path} {branch} {codename} {components}）
# 注意：URL模板根据发行版不同而不同，此处仅为示例，实际生成时根据发行版填充
declare -A MIRROR_SOURCES

# 通用占位符说明：
# {protocol} - http 或 https
# {mirror} - 镜像站域名
# {distro_path} - 发行版在镜像站上的路径，如 ubuntu, debian, fedora, centos 等
# {branch} - 仓库分支，如 stable, updates, security, backports 等
# {codename} - 发行版代号
# {components} - 组件列表，如 main, contrib, non-free

# 定义镜像站列表（按地区分组，便于后续选择）
declare -A MIRROR_STATIONS=(
    # 中国大陆
    ["aliyun"]="mirrors.aliyun.com"
    ["tuna"]="mirrors.tuna.tsinghua.edu.cn"
    ["ustc"]="mirrors.ustc.edu.cn"
    ["huawei"]="mirrors.huaweicloud.com"
    ["tencent"]="mirrors.tencent.com"
    ["netease"]="mirrors.163.com"
    ["sjtu"]="mirrors.sjtug.sjtu.edu.cn"
    ["lzu"]="mirror.lzu.edu.cn"
    ["bfsu"]="mirrors.bfsu.edu.cn"
    ["bjtu"]="mirror.bjtu.edu.cn"
    ["cqu"]="mirrors.cqu.edu.cn"
    # 海外
    ["mit"]="mirrors.mit.edu"
    ["princeton"]="mirror.math.princeton.edu/pub"
    ["columbia"]="mirror.cc.columbia.edu"
    ["bu"]="mirrors.bu.edu"
    ["ubc"]="mirror.it.ubc.ca"
    ["ufscar"]="mirror.ufscar.br"
    ["unlp"]="mirrors.unlp.edu.ar"
    ["au"]="mirror.aarnet.edu.au"
    ["nz"]="mirror.waikato.ac.nz"
    ["kenet"]="kenet.ke"
    ["sun"]="mirror.sun.ac.za"
    ["heanet"]="ftp.heanet.ie"
    ["switch"]="mirror.switch.ch"
    ["sanger"]="mirror.sanger.ac.uk"
    # 官方源
    ["official"]=""
)

# 根据发行版获取默认组件
get_default_components() {
    case "$OS_NAME" in
        debian|ubuntu|linuxmint|raspbian|zorin|deepin|kalilinux|proxmox|armbian|openkylin)
            if [[ "$OS_NAME" == "debian" ]]; then
                echo "main contrib non-free"
            elif [[ "$OS_NAME" == "ubuntu" ]]; then
                echo "main restricted universe multiverse"
            else
                # 默认为 main
                echo "main"
            fi
            ;;
        rhel|centos|rocky|almalinux|oraclelinux|fedora)
            # RHEL 系使用 baseos, appstream 等，需要单独处理
            echo "baseos appstream"
            ;;
        openeuler|opencloudos)
            echo "OS"
            ;;
        *)
            echo "main"
            ;;
    esac
}

# 生成 Debian/Ubuntu 系 sources.list
generate_debian_like_sources() {
    local mirror="$1"
    local protocol="$2"
    local codename="$3"
    local components="$4"
    local extra_branches=("${@:5}")   # 额外分支如 updates, security, backports

    local distro_path
    case "$OS_NAME" in
        debian) distro_path="debian" ;;
        ubuntu) distro_path="ubuntu" ;;
        linuxmint) distro_path="ubuntu" ;;  # Mint 基于 Ubuntu，但可能需要特殊处理
        raspbian) distro_path="raspbian" ;;
        *) distro_path="$OS_NAME" ;;
    esac

    local base_url="${protocol}://${mirror}/${distro_path}"
    local sources=""

    # 主分支
    sources+="deb ${base_url} ${codename} ${components}\n"

    # 额外分支
    for branch in "${extra_branches[@]}"; do
        sources+="deb ${base_url} ${codename}-${branch} ${components}\n"
    done

    # 对于 Debian 8/9 可能还需要处理 -updates, -backports 等，默认 extra_branches 包含 updates, security, backports
    echo -e "$sources"
}

# 生成 RHEL 系仓库文件（.repo）
generate_rhel_like_repo() {
    local mirror="$1"
    local protocol="$2"
    local releasever="$3"   # 版本号，如 8, 9
    local components="$4"   # 如 baseos appstream

    local distro_path
    case "$OS_NAME" in
        centos|rocky|almalinux|oraclelinux|fedora)
            distro_path="$OS_NAME"
            ;;
        rhel)
            distro_path="rhel"
            ;;
        *)
            distro_path="$OS_NAME"
            ;;
    esac

    local base_url="${protocol}://${mirror}/${distro_path}/${releasever}"
    local repo_content=""

    # 对于 RHEL 8/9，典型仓库有 BaseOS, AppStream, EPEL 等
    # 这里简单生成一个示例，实际应根据发行版和版本调整
    repo_content="[baseos]
name=${OS_NAME} \$releasever - BaseOS
baseurl=${base_url}/BaseOS/\$basearch/os/
gpgcheck=1
enabled=1

[appstream]
name=${OS_NAME} \$releasever - AppStream
baseurl=${base_url}/AppStream/\$basearch/os/
gpgcheck=1
enabled=1
"
    # 如果有 EPEL 需求，可额外生成
    echo "$repo_content"
}

# 生成 openEuler 等国产发行版
generate_openeuler_sources() {
    local mirror="$1"
    local protocol="$2"
    local releasever="$3"
    local components="$4"

    local base_url="${protocol}://${mirror}/openeuler/openEuler-${releasever}"
    cat <<EOF
[OS]
name=OS
baseurl=${base_url}/OS/\$basearch/
enabled=1
gpgcheck=1
gpgkey=${base_url}/OS/\$basearch/RPM-GPG-KEY-openEuler

[everything]
name=everything
baseurl=${base_url}/everything/\$basearch/
enabled=1
gpgcheck=1
gpgkey=${base_url}/everything/\$basearch/RPM-GPG-KEY-openEuler

[EPOL]
name=EPOL
baseurl=${base_url}/EPOL/main/\$basearch/
enabled=1
gpgcheck=1
gpgkey=${base_url}/EPOL/main/\$basearch/RPM-GPG-KEY-openEuler
EOF
}

# 主函数：运行系统镜像优化（可由菜单调用，也可由命令行参数直接调用）
run_system_mirror() {
    log_info "$(_echo "===== System Mirror Optimization =====" "===== 系统镜像优化 =====")"
    
    # 如果已经通过命令行参数指定了镜像，则直接使用
    if [[ -n "$OPT_MIRROR" ]]; then
        apply_mirror "$OPT_MIRROR" "$OPT_PROTOCOL" "$OPT_BRANCH" "$OPT_COMPONENTS"
        return $?
    fi

    # 备份操作
    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        _echo "[DRY-RUN] Would backup file: $file" "[模拟运行] 将备份文件：$file"
    else
        backup_file "$file" "system_mirror"
    fi

    # 写入文件
    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        _echo "[DRY-RUN] Would write to $file: $content" "[模拟运行] 将写入 $file：$content"
    else
        safe_write "$file" "$content" "system_mirror"
    fi

    # 执行命令（如 apt update）
    if [[ "$OPT_DRY_RUN" == "true" ]]; then
        _echo "[DRY-RUN] Would run: apt update" "[模拟运行] 将执行：apt update"
    else
        apt update
    fi

    # 交互式选择
    _echo "Select mirror source category:" "请选择镜像源类别："
    echo "1) $(_echo "China Mainland" "中国大陆")"
    echo "2) $(_echo "Overseas" "海外")"
    echo "3) $(_echo "Official (restore to default)" "官方源（恢复默认）")"
    echo "0) $(_echo "Back" "返回")"
    read -rp "$(_echo "Choice [0-3]: " "请选择 [0-3]：") " cat_choice

    case $cat_choice in
        1) select_mirror_from_group "china" ;;
        2) select_mirror_from_group "overseas" ;;
        3) apply_official_mirror ;;
        0) return ;;
        *) _echo "Invalid choice." "无效选择。" ; return ;;
    esac
}

# 从指定组中选择镜像站
select_mirror_from_group() {
    local group="$1"
    local -a mirrors
    local -a names
    local i=1

    _echo "Available mirrors:" "可用镜像源："
    for name in "${!MIRROR_STATIONS[@]}"; do
        local station="${MIRROR_STATIONS[$name]}"
        # 简单分组：判断是否包含 edu.cn 或特定域名，实际可预先定义分组
        if [[ "$group" == "china" ]] && [[ "$station" == *".cn" ]]; then
            mirrors+=("$name")
            names+=("$name")
            echo "  $i) $name ($station)"
            ((i++))
        elif [[ "$group" == "overseas" ]] && [[ "$station" != *".cn" ]] && [[ -n "$station" ]]; then
            mirrors+=("$name")
            names+=("$name")
            echo "  $i) $name ($station)"
            ((i++))
        fi
    done
    echo "  0) $(_echo "Back" "返回")"
    read -rp "$(_echo "Choice [0-$((i-1))]: " "请选择 [0-$((i-1))]：") " choice

    if [[ "$choice" == "0" ]]; then
        return
    fi
    if [[ "$choice" -le ${#mirrors[@]} ]]; then
        local selected_name="${mirrors[$((choice-1))]}"
        local selected_mirror="${MIRROR_STATIONS[$selected_name]}"
        apply_mirror "$selected_mirror" "${OPT_PROTOCOL:-https}" "${OPT_BRANCH:-}" "${OPT_COMPONENTS:-}"
    else
        _echo "Invalid choice." "无效选择。"
    fi
}

# 应用官方源
apply_official_mirror() {
    _echo "Restoring official sources..." "正在恢复官方源..."
    # 根据不同发行版，官方源不需要替换为镜像，可以删除镜像配置或恢复默认备份
    # 简单起见，我们尝试从备份中恢复
    if restore_file "/etc/apt/sources.list" || restore_file "/etc/yum.repos.d/"*; then
        _echo "Official sources restored." "官方源已恢复。"
    else
        _echo "No backup found, cannot restore automatically." "未找到备份，无法自动恢复。"
    fi
}

# 实际应用镜像源（核心函数）
apply_mirror() {
    local mirror="$1"
    local protocol="$2"
    local branch="$3"
    local components="$4"
    local codename
    local releasever

    codename=$(get_distro_info)
    releasever="$OS_VERSION"  # 例如 22.04, 8, 9 等

    if [[ -z "$codename" ]] && [[ "$OS_NAME" =~ ^(debian|ubuntu|linuxmint|raspbian|zorin|deepin|kalilinux|proxmox|armbian|openkylin)$ ]]; then
        _echo "Unable to get distribution codename, please input manually (e.g., bullseye, focal)." "无法获取发行版代号，请手动输入（例如 bullseye, focal）："
        read -rp "> " codename
        if [[ -z "$codename" ]]; then
            _echo "Operation cancelled." "操作取消。"
            return 1
        fi
    fi

    # 根据发行版类型执行不同的源生成逻辑
    case "$OS_NAME" in
        debian|ubuntu|linuxmint|raspbian|zorin|deepin|kalilinux|proxmox|armbian|openkylin)
            local comp="${components:-$(get_default_components)}"
            local branches
            if [[ -n "$branch" ]]; then
                branches=("$branch")
            else
                # 默认分支：updates, security, backports (取决于发行版)
                if [[ "$OS_NAME" == "ubuntu" ]]; then
                    branches=(updates security backports)
                else
                    branches=(updates security backports)
                fi
            fi
            local sources_list
            sources_list=$(generate_debian_like_sources "$mirror" "$protocol" "$codename" "$comp" "${branches[@]}")
            # 备份并写入
            if [[ -f /etc/apt/sources.list ]]; then
                backup_file /etc/apt/sources.list "system_mirror"
            fi
            safe_write /etc/apt/sources.list "$sources_list" "system_mirror"
            _echo "APT sources updated. Running apt update..." "APT 源已更新，正在更新软件包列表..."
            apt update
            ;;
        centos|rocky|almalinux|oraclelinux|fedora|rhel)
            local repo_dir="/etc/yum.repos.d"
            local releasever_major="${releasever%%.*}"  # 取主版本号
            local repo_content
            repo_content=$(generate_rhel_like_repo "$mirror" "$protocol" "$releasever_major" "${components:-$(get_default_components)}")
            # 备份原有 repo 文件（可选）
            backup_file "$repo_dir" "system_mirror"  # 备份整个目录？通常逐个文件备份
            # 写入新的 repo 文件，注意不要覆盖原有的 epel 等
            safe_write "$repo_dir/${OS_NAME}.repo" "$repo_content" "system_mirror"
            _echo "YUM/DNF sources updated. Running update..." "YUM/DNF 源已更新，正在更新..."
            if command -v dnf &>/dev/null; then
                dnf makecache
            else
                yum makecache
            fi
            ;;
        openeuler|opencloudos)
            local repo_content
            repo_content=$(generate_openeuler_sources "$mirror" "$protocol" "$releasever" "${components:-$(get_default_components)}")
            backup_file "/etc/yum.repos.d/${OS_NAME}.repo" "system_mirror"
            safe_write "/etc/yum.repos.d/${OS_NAME}.repo" "$repo_content" "system_mirror"
            dnf makecache
            ;;
        *)
            _echo "Unsupported distribution: $OS_NAME" "不支持的发行版：$OS_NAME"
            return 1
            ;;
    esac

    log_info "$(_echo "Mirror applied: $mirror" "已应用镜像：$mirror")"
}

# 导出函数供主脚本调用