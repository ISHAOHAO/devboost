#!/usr/bin/env bash
# 回滚模块：根据备份清单恢复所有文件

perform_rollback() {
    log_info "开始执行回滚操作"

    if [[ ! -s "$DEVBOOST_MANIFEST" ]]; then
        log_warn "备份清单为空，无任何回滚操作"
        return
    fi

    echo "备份记录："
    echo "序号 | 原始文件 | 备份文件 | 操作标识 | 时间戳"
    echo "------------------------------------------------"
    local i=1
    while IFS='|' read -r original backup tag timestamp; do
        printf "%3d | %s | %s | %s | %s\n" "$i" "$original" "$backup" "$tag" "$timestamp"
        ((i++))
    done < "$DEVBOOST_MANIFEST"

    echo ""
    read -rp "请输入要回滚的序号（多个用空格分隔，输入 all 回滚所有）: " selection

    if [[ "$selection" == "all" ]]; then
        while IFS='|' read -r original backup tag timestamp; do
            if [[ -f "$backup" ]]; then
                cp -a "$backup" "$original"
                log_info "已恢复: $original"
            else
                log_error "备份文件丢失: $backup"
            fi
        done < "$DEVBOOST_MANIFEST"
        log_info "全部回滚完成"
    else
        for idx in $selection; do
            line=$(sed -n "${idx}p" "$DEVBOOST_MANIFEST")
            IFS='|' read -r original backup tag timestamp <<< "$line"
            if [[ -f "$backup" ]]; then
                cp -a "$backup" "$original"
                log_info "已恢复: $original (序号 $idx)"
            else
                log_error "备份文件丢失: $backup"
            fi
        done
    fi
}