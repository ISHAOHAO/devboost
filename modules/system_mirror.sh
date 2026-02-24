#!/usr/bin/env bash
# Module: system_mirror
# Description: System Package Manager Mirror Optimization (Global Mirrors)
# Description(zh): 系统包管理器镜像优化（全球镜像源）

# 初始化语言
if [[ "${DEVBOOST_LANG}" == "zh" ]]; then
    LANG_ZH=true
else
    LANG_ZH=false
fi

# 输出函数
_echo() {
    local en="$1"
    local zh="$2"
    if $LANG_ZH; then
        echo "$zh"
    else
        echo "$en"
    fi
}

# 获取发行版代号
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

# 获取默认组件
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

# ==================================================
# 全球镜像源数据库（按大洲/国家分类）
# 格式：地区|国家|镜像站名称|域名|支持的协议|备注
# ==================================================

# 亚洲（中国）
declare -a MIRRORS_ASIA_CHINA=(
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

# 亚洲（其他国家和地区）
declare -a MIRRORS_ASIA_OTHER=(
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

# 欧洲
declare -a MIRRORS_EUROPE=(
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

# 北美洲
declare -a MIRRORS_NA=(
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

# 大洋洲
declare -a MIRRORS_OCEANIA=(
    "澳大利亚|AARNet|mirror.aarnet.edu.au|https/http|教育网"
    "澳大利亚|Internode|mirror.internode.on.net|https/http|运营商"
    "澳大利亚|WA Internet|mirror.wai.net.au|https/http|商业镜像"
    "新西兰|Waikato University|mirror.waikato.ac.nz|https/http|教育网"
    "新西兰|Auckland University|mirror.auckland.ac.nz|https/http|教育网"
)

# 南美洲
declare -a MIRRORS_SA=(
    "巴西|UFSCar|mirror.ufscar.br|https/http|教育网"
    "巴西|UFPR|mirror.ufpr.br|https/http|教育网"
    "阿根廷|UNLP|mirrors.unlp.edu.ar|https/http|教育网"
    "阿根廷|UBA|mirror.uba.ar|https/http|教育网"
    "智利|Hostednode|mirror.hnd.cl|https/http|商业镜像"
    "哥伦比亚|FCIX|edgeuno-bog2.mm.fcix.net|https/http|交换中心"
)

# 非洲
declare -a MIRRORS_AFRICA=(
    "南非|University of Stellenbosch|mirror.sun.ac.za|https/http|教育网"
    "南非|Dimension Data|mirror.dimensiondata.com|https/http|商业镜像"
    "肯尼亚|KENET|kenet.ke|https/http|教育网"
    "埃及|EUN|mirror.eun.eg|https/http|教育网"
    "摩洛哥|CNRST|mirror.cnrst.ma|https/http|研究机构"
)

# ==================== 辅助函数 ====================

# 获取地区的中英文名称
get_region_display() {
    local region="$1"
    for r in "${REGIONS[@]}"; do
        IFS='|' read -r code zh_name en_name <<< "$r"
        if [[ "$code" == "$region" ]]; then
            if $LANG_ZH; then
                echo "$zh_name"
            else
                echo "$en_name"
            fi
            return
        fi
    done
    echo "$region"
}

# 检查镜像是否支持当前发行版
mirror_supports_distro() {
    local support_list="$1"
    local distro="$2"
    [[ "$support_list" == *"$distro"* ]]
}

# 获取指定地区的镜像列表（按支持过滤）
get_mirrors_by_region() {
    local region="$1"
    local distro="${OS_NAME}"
    local -a results=()
    
    for mirror in "${GLOBAL_MIRRORS[@]}"; do
        IFS='|' read -r r country name domain supports <<< "$mirror"
        if [[ "$r" == "$region" ]] && mirror_supports_distro "$supports" "$distro"; then
            results+=("$name|$domain|$country")
        fi
    done
    
    printf '%s\n' "${results[@]}"
}

# ==================== 核心功能 ====================

# 选择地区（使用硬编码列表）
select_region() {
    echo ""
    _echo "Select region:" "请选择地区："
    
    local i=1
    local -a region_codes=()
    
    # 显示所有硬编码地区
    for region_entry in "${REGIONS[@]}"; do
        IFS='|' read -r code zh_name en_name <<< "$region_entry"
        region_codes[$i]="$code"
        if $LANG_ZH; then
            echo "  $i) $zh_name"
        else
            echo "  $i) $en_name"
        fi
        ((i++))
    done
    
    echo "  0) $(_echo "Back" "返回")"
    read -rp "$(_echo "Choice [0-$((i-1))]: " "请选择 [0-$((i-1))]：") " region_choice
    
    if [[ "$region_choice" == "0" ]]; then
        return 1
    fi
    
    if [[ "$region_choice" -ge 1 && "$region_choice" -le ${#region_codes[@]} ]]; then
        echo "${region_codes[$region_choice]}"
    else
        _echo "Invalid choice." "无效选择。"
        select_region
    fi
}

# 从选定地区中选择镜像站
select_mirror_from_region() {
    local region_array_name="$1"
    # 使用 eval 获取整个数组
    local -a region_mirrors
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
        
        # 正确调用 apply_mirror：传入域名、名称、协议、分支、组件
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

# 颜色定义（如果 common.sh 未提供）
if [[ -z "$COLOR_GREEN" ]]; then
    COLOR_GREEN='\033[0;32m'
    COLOR_RESET='\033[0m'
fi

# ==================== 主函数 ====================

run_system_mirror() {
    log_info "$(_echo "===== System Mirror Optimization =====" "===== 系统镜像优化 =====")"

    # 如果已经通过命令行参数指定了镜像，则直接使用
    if [[ -n "$OPT_MIRROR" ]]; then
        apply_mirror "$OPT_MIRROR" "$OPT_MIRROR" "$OPT_PROTOCOL" "$OPT_BRANCH" "$OPT_COMPONENTS"
        return $?
    fi

    # 先选择地区大类
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