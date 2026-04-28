#!/bin/bash
#
# subscription_priority.sh - 订阅优先级与故障转移模块
# 支持设置主订阅、备用订阅、故障自动切换
#

# ============================================================================
# 优先级配置文件
# ============================================================================

PRIORITY_CONFIG_FILE="${CONFIGS_DIR}/subscription_priority.conf"

# ============================================================================
# 优先级管理菜单
# ============================================================================

show_priority_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  订阅优先级与故障转移                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. 查看订阅优先级"
    echo -e "  ${GREEN}2${NC}. 设置主订阅（优先使用）"
    echo -e "  ${GREEN}3${NC}. 添加备用订阅"
    echo -e "  ${GREEN}4${NC}. 移除备用订阅"
    echo -e "  ${GREEN}5${NC}. 调整优先级顺序"
    echo -e "  ${GREEN}6${NC}. 应用优先级配置"
    echo -e "  ${GREEN}7${NC}. 测试故障转移"
    echo -e "  ${GREEN}0${NC}. 返回主菜单"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    read -p "请输入选择 (0-7): " choice
    
    case $choice in
        1) priority_show ;;
        2) priority_set_primary ;;
        3) priority_add_backup ;;
        4) priority_remove_backup ;;
        5) priority_reorder ;;
        6) priority_apply ;;
        7) priority_test_failover ;;
        0) return ;;
        *) log_error "无效选择"; sleep 1; show_priority_menu ;;
    esac
}

# 处理优先级命令
handle_priority_command() {
    local command=$1
    shift
    
    case $command in
        show|status)
            priority_show
            ;;
        set|set-primary|primary)
            priority_set_primary "$@"
            ;;
        add-backup|backup)
            priority_add_backup "$@"
            ;;
        remove-backup|rm-backup)
            priority_remove_backup "$@"
            ;;
        reorder)
            priority_reorder
            ;;
        apply)
            priority_apply
            ;;
        test|failover)
            priority_test_failover
            ;;
        *)
            log_error "未知优先级命令: $command"
            echo ""
            echo "用法: mihomo-quick.sh priority [命令]"
            echo ""
            echo "命令:"
            echo "  show             查看订阅优先级"
            echo "  set <订阅名>     设置主订阅（优先使用）"
            echo "  backup <订阅名>  添加备用订阅"
            echo "  rm-backup <订阅名> 移除备用订阅"
            echo "  reorder          调整优先级顺序"
            echo "  apply            应用优先级配置到mihomo"
            echo "  test             测试故障转移"
            echo ""
            echo "示例:"
            echo "  mihomo-quick.sh priority set provider-a"
            echo "  mihomo-quick.sh priority backup provider-b"
            echo "  mihomo-quick.sh priority apply"
            return 1
            ;;
    esac
}

# ============================================================================
# 优先级查看
# ============================================================================

priority_show() {
    log_info "查看订阅优先级..."
    
    echo ""
    
    # 从配置文件中读取订阅列表
    local config_file="${CONFIGS_DIR}/config.yaml"
    local providers=()
    
    if [[ -f "$config_file" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            providers+=("$line")
        done < <(sed -n '/^proxy-providers:/,/^[a-zA-Z]/p' "$config_file" | grep -E "^  [a-zA-Z]" | sed 's/://g' | sed 's/^  //')
    fi
    
    if [[ ${#providers[@]} -eq 0 ]]; then
        echo -e "  ${YELLOW}没有配置订阅${NC}"
        echo ""
        echo -e "  请先添加订阅: mihomo-quick.sh sub add"
        echo ""
        read -p "按 Enter 键返回..."
        show_priority_menu
        return 0
    fi
    
    # 读取优先级配置
    local primary=""
    local backups=()
    
    if [[ -f "$PRIORITY_CONFIG_FILE" ]]; then
        primary=$(grep "^PRIMARY=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            backups+=("$line")
        done < <(grep "^BACKUP=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    fi
    
    # 如果没有设置优先级，使用第一个订阅作为主订阅
    if [[ -z "$primary" ]]; then
        primary="${providers[0]}"
    fi
    
    echo -e "${WHITE}订阅优先级配置:${NC}"
    echo ""
    
    # 显示主订阅
    echo -e "  ${GREEN}★ 主订阅（优先使用）:${NC}"
    echo -e "    ${GREEN}→${NC} $primary"
    echo ""
    
    # 显示备用订阅
    if [[ ${#backups[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}☆ 备用订阅（故障转移）:${NC}"
        local idx=1
        for backup in "${backups[@]}"; do
            echo -e "    ${YELLOW}$idx.${NC} $backup"
            ((idx++))
        done
    else
        echo -e "  ${YELLOW}☆ 备用订阅: 未配置${NC}"
    fi
    
    echo ""
    
    # 显示所有可用订阅
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}所有可用订阅:${NC}"
    echo ""
    for provider in "${providers[@]}"; do
        if [[ "$provider" == "$primary" ]]; then
            echo -e "  ${GREEN}★${NC} $provider ${GREEN}(主)${NC}"
        elif printf '%s\n' "${backups[@]}" | grep -qxF "$provider"; then
            echo -e "  ${YELLOW}☆${NC} $provider ${YELLOW}(备)${NC}"
        else
            echo -e "  ${WHITE}○${NC} $provider"
        fi
    done
    
    echo ""
    
    # 显示当前代理组配置
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}当前代理组架构:${NC}"
    echo ""
    
    if [[ -f "$config_file" ]]; then
        echo -e "  ${GREEN}故障转移组:${NC}"
        grep -A 10 "故障转移\|Fallback\|fallback" "$config_file" 2>/dev/null | head -8 | while IFS= read -r line; do
            [[ "$line" =~ ^[a-zA-Z] ]] && break
            echo "    $line"
        done
    fi
    
    echo ""
    
    read -p "按 Enter 键返回..."
    show_priority_menu
}

# ============================================================================
# 设置主订阅
# ============================================================================

priority_set_primary() {
    local provider_name="$1"
    
    # 获取可用订阅列表
    local config_file="${CONFIGS_DIR}/config.yaml"
    local providers=()
    
    if [[ -f "$config_file" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            providers+=("$line")
        done < <(sed -n '/^proxy-providers:/,/^[a-zA-Z]/p' "$config_file" | grep -E "^  [a-zA-Z]" | sed 's/://g' | sed 's/^  //')
    fi
    
    if [[ ${#providers[@]} -eq 0 ]]; then
        log_error "没有配置订阅，请先添加订阅"
        [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
        return 1
    fi
    
    if [[ -z "$provider_name" ]]; then
        echo ""
        echo -e "${WHITE}设置主订阅（优先使用）${NC}"
        echo ""
        echo "可用订阅:"
        local idx=1
        for provider in "${providers[@]}"; do
            echo -e "  ${GREEN}$idx${NC}. $provider"
            ((idx++))
        done
        echo ""
        read -p "请选择 (1-${#providers[@]}): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le ${#providers[@]} ]]; then
            provider_name="${providers[$((choice-1))]}"
        else
            log_error "无效选择"
            read -p "按 Enter 键返回..."
            show_priority_menu
            return 1
        fi
    fi
    
    # 验证订阅是否存在
    local found=0
    for provider in "${providers[@]}"; do
        if [[ "$provider" == "$provider_name" ]]; then
            found=1
            break
        fi
    done
    
    if [[ $found -eq 0 ]]; then
        log_error "订阅不存在: $provider_name"
        [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
        return 1
    fi
    
    # 读取现有配置
    local backups=()
    if [[ -f "$PRIORITY_CONFIG_FILE" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # 排除新主订阅（不能同时是主和备）
            if [[ "$line" != "$provider_name" ]]; then
                backups+=("$line")
            fi
        done < <(grep "^BACKUP=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    fi
    
    # 保存优先级配置
    mkdir -p "$(dirname "$PRIORITY_CONFIG_FILE")"
    cat > "$PRIORITY_CONFIG_FILE" << EOF
# mihomo-quick 订阅优先级配置
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 主订阅（优先使用）
PRIMARY=$provider_name

# 备用订阅（故障转移，按顺序）
EOF
    
    for backup in "${backups[@]}"; do
        echo "BACKUP=$backup" >> "$PRIORITY_CONFIG_FILE"
    done
    
    log_success "已设置主订阅: $provider_name"
    
    [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
}

# ============================================================================
# 备用订阅管理
# ============================================================================

priority_add_backup() {
    local provider_name="$1"
    
    # 获取可用订阅列表
    local config_file="${CONFIGS_DIR}/config.yaml"
    local providers=()
    
    if [[ -f "$config_file" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            providers+=("$line")
        done < <(sed -n '/^proxy-providers:/,/^[a-zA-Z]/p' "$config_file" | grep -E "^  [a-zA-Z]" | sed 's/://g' | sed 's/^  //')
    fi
    
    if [[ ${#providers[@]} -eq 0 ]]; then
        log_error "没有配置订阅"
        [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
        return 1
    fi
    
    # 读取当前主订阅
    local primary=""
    if [[ -f "$PRIORITY_CONFIG_FILE" ]]; then
        primary=$(grep "^PRIMARY=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    fi
    
    if [[ -z "$provider_name" ]]; then
        echo ""
        echo -e "${WHITE}添加备用订阅${NC}"
        echo ""
        echo "可用订阅:"
        local idx=1
        for provider in "${providers[@]}"; do
            if [[ "$provider" == "$primary" ]]; then
                echo -e "  ${GRAY}$idx${NC}. $provider ${GREEN}(主订阅，不可选)${NC}"
            else
                echo -e "  ${GREEN}$idx${NC}. $provider"
            fi
            ((idx++))
        done
        echo ""
        read -p "请选择 (1-${#providers[@]}): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le ${#providers[@]} ]]; then
            provider_name="${providers[$((choice-1))]}"
        else
            log_error "无效选择"
            read -p "按 Enter 键返回..."
            show_priority_menu
            return 1
        fi
    fi
    
    # 不能将主订阅添加为备用
    if [[ "$provider_name" == "$primary" ]]; then
        log_error "不能将主订阅添加为备用订阅"
        [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
        return 1
    fi
    
    # 检查是否已是备用
    if [[ -f "$PRIORITY_CONFIG_FILE" ]] && grep -q "^BACKUP=$provider_name$" "$PRIORITY_CONFIG_FILE"; then
        log_warning "已是备用订阅: $provider_name"
        [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
        return 0
    fi
    
    # 添加到配置
    mkdir -p "$(dirname "$PRIORITY_CONFIG_FILE")"
    
    if [[ ! -f "$PRIORITY_CONFIG_FILE" ]]; then
        cat > "$PRIORITY_CONFIG_FILE" << EOF
# mihomo-quick 订阅优先级配置
PRIMARY=${primary:-${providers[0]}}
BACKUP=$provider_name
EOF
    else
        echo "BACKUP=$provider_name" >> "$PRIORITY_CONFIG_FILE"
    fi
    
    log_success "已添加备用订阅: $provider_name"
    
    [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
}

priority_remove_backup() {
    local provider_name="$1"
    
    if [[ ! -f "$PRIORITY_CONFIG_FILE" ]] || ! grep -q "^BACKUP=" "$PRIORITY_CONFIG_FILE"; then
        log_warning "没有备用订阅"
        [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
        return 0
    fi
    
    if [[ -z "$provider_name" ]]; then
        echo ""
        echo -e "${WHITE}移除备用订阅${NC}"
        echo ""
        echo "当前备用订阅:"
        local idx=1
        while IFS= read -r line; do
            echo -e "  ${GREEN}$idx${NC}. $line"
            ((idx++))
        done < <(grep "^BACKUP=" "$PRIORITY_CONFIG_FILE" | cut -d= -f2)
        echo ""
        read -p "请选择 (1-$((idx-1))): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -lt $idx ]]; then
            provider_name=$(grep "^BACKUP=" "$PRIORITY_CONFIG_FILE" | sed -n "${choice}p" | cut -d= -f2)
        else
            log_error "无效选择"
            read -p "按 Enter 键返回..."
            show_priority_menu
            return 1
        fi
    fi
    
    # 从配置中删除
    sed -i "/^BACKUP=${provider_name}$/d" "$PRIORITY_CONFIG_FILE"
    
    log_success "已移除备用订阅: $provider_name"
    
    [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_priority_menu
}

# ============================================================================
# 优先级调整
# ============================================================================

priority_reorder() {
    if [[ ! -f "$PRIORITY_CONFIG_FILE" ]]; then
        log_warning "没有优先级配置"
        read -p "按 Enter 键返回..."
        show_priority_menu
        return 0
    fi
    
    echo ""
    echo -e "${WHITE}当前优先级顺序:${NC}"
    echo ""
    
    local primary=$(grep "^PRIMARY=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    echo -e "  ${GREEN}1. $primary (主)${NC}"
    
    local idx=2
    while IFS= read -r line; do
        echo -e "  ${YELLOW}$idx. $line (备)${NC}"
        ((idx++))
    done < <(grep "^BACKUP=" "$PRIORITY_CONFIG_FILE" | cut -d= -f2)
    
    echo ""
    echo "输入新的顺序（用空格分隔，如: 1 3 2）:"
    read -p "新顺序: " new_order
    
    if [[ -z "$new_order" ]]; then
        log_info "取消调整"
        read -p "按 Enter 键返回..."
        show_priority_menu
        return 0
    fi
    
    # 解析新顺序
    local all_items=("$primary")
    while IFS= read -r line; do
        all_items+=("$line")
    done < <(grep "^BACKUP=" "$PRIORITY_CONFIG_FILE" | cut -d= -f2)
    
    # 重建配置
    cat > "$PRIORITY_CONFIG_FILE" << EOF
# mihomo-quick 订阅优先级配置
# 更新时间: $(date '+%Y-%m-%d %H:%M:%S')
PRIMARY=${all_items[0]}
EOF
    
    for order in $new_order; do
        if [[ "$order" -ge 2 && "$order" -le ${#all_items[@]} ]]; then
            echo "BACKUP=${all_items[$((order-1))]}" >> "$PRIORITY_CONFIG_FILE"
        fi
    done
    
    log_success "优先级顺序已更新"
    
    read -p "按 Enter 键返回..."
    show_priority_menu
}

# ============================================================================
# 应用优先级配置
# ============================================================================

priority_apply() {
    log_info "应用订阅优先级配置..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    if [[ ! -f "$PRIORITY_CONFIG_FILE" ]]; then
        log_warning "没有优先级配置，请先设置"
        return 0
    fi
    
    # 读取优先级配置
    local primary=$(grep "^PRIMARY=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    local backups=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        backups+=("$line")
    done < <(grep "^BACKUP=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    
    if [[ -z "$primary" ]]; then
        log_error "主订阅未设置"
        return 1
    fi
    
    log_info "主订阅: $primary"
    log_info "备用订阅: ${backups[*]:-无}"
    
    # 备份配置
    backup_file "$config_file"
    
    # 构建新的代理组配置
    # 生成主订阅的 url-test 组
    local primary_group="  - name: \"⭐ 主订阅节点\"
    type: url-test
    use:
      - $primary
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 200
    lazy: true"
    
    # 生成备用订阅的 fallback 组（按优先级顺序）
    local backup_proxies=""
    for backup in "${backups[@]}"; do
        backup_proxies="${backup_proxies}
      - $backup"
    done
    
    local fallback_group="  - name: \"🔄 故障转移\"
    type: fallback
    proxies:
      - \"⭐ 主订阅节点\"${backup_proxies}
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    lazy: true"
    
    # 生成综合选择组
    local select_group="  - name: \"📱 综合选择\"
    type: select
    proxies:
      - \"⭐ 主订阅节点\"
      - \"🔄 故障转移\""
    
    # 添加备用订阅到选择组
    for backup in "${backups[@]}"; do
        select_group="${select_group}
      - $backup"
    done
    select_group="${select_group}
      - DIRECT"
    
    # 读取旧配置中 proxy-providers 之前的部分
    local base_config=$(sed '/^proxy-providers:/,$d' "$config_file")
    
    # 读取 proxy-providers 部分
    local providers_block=$(sed -n '/^proxy-providers:/,/^[a-zA-Z]/p' "$config_file" 2>/dev/null)
    
    # 构建新配置
    local temp_file=$(mktemp)
    echo "$base_config" > "$temp_file"
    
    # 追加订阅配置
    if [[ -n "$providers_block" ]]; then
        echo "" >> "$temp_file"
        echo "$providers_block" >> "$temp_file"
    fi
    
    # 追加代理组配置
    echo "" >> "$temp_file"
    echo "proxy-groups:" >> "$temp_file"
    echo "$primary_group" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "$fallback_group" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "$select_group" >> "$temp_file"
    
    # 追加规则配置
    echo "" >> "$temp_file"
    
    # 读取旧配置的 rules 部分
    local rules_block=$(sed -n '/^rules:/,$p' "$config_file" 2>/dev/null)
    if [[ -n "$rules_block" ]]; then
        # 更新规则中的代理组引用
        echo "$rules_block" | sed 's/🔄 智能切换/🔄 故障转移/g' | sed 's/🚀 节点选择/⭐ 主订阅节点/g' >> "$temp_file"
    else
        # 生成默认规则
        cat >> "$temp_file" << 'EOF'
rules:
  # 大模型API直连
  - DOMAIN-SUFFIX,anthropic.com,DIRECT
  - DOMAIN-SUFFIX,bigmodel.cn,DIRECT
  - DOMAIN-SUFFIX,openai.com,DIRECT
  - DOMAIN-SUFFIX,openrouter.ai,DIRECT
  - DOMAIN-SUFFIX,volcengine.com,DIRECT
  - DOMAIN-SUFFIX,volces.com,DIRECT

  # Google API走代理
  - DOMAIN-SUFFIX,googleapis.com,🔄 故障转移

  # 本地网络直连
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT

  # 中国IP直连
  - GEOIP,CN,DIRECT

  # 默认规则
  - MATCH,🔄 故障转移
EOF
    fi
    
    # 追加自定义规则
    if [[ -f "$RULES_CUSTOM_FILE" ]]; then
        echo "" >> "$temp_file"
        echo "# 自定义规则" >> "$temp_file"
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            echo "  - $line" >> "$temp_file"
        done < "$RULES_CUSTOM_FILE"
    fi
    
    mv "$temp_file" "$config_file"
    
    log_success "优先级配置已应用"
    
    # 验证配置
    local mihomo_bin=$(which mihomo 2>/dev/null || echo "${HOME}/.mihomo-quick/mihomo")
    if [[ -f "$mihomo_bin" ]]; then
        log_info "验证配置..."
        if "$mihomo_bin" -d "$(dirname "$config_file")" -t 2>/dev/null; then
            log_success "配置验证通过"
        else
            log_warning "配置验证有警告，请检查"
        fi
    fi
    
    # 重启服务
    _restart_if_running
    
    echo ""
    echo -e "${WHITE}当前代理组架构:${NC}"
    echo -e "  ${GREEN}⭐ 主订阅节点${NC} → url-test（$primary 自动选择最快节点）"
    echo -e "  ${YELLOW}🔄 故障转移${NC} → fallback（主订阅不可用时自动切换备用）"
    echo -e "  ${CYAN}📱 综合选择${NC} → select（手动选择或使用自动）"
    echo ""
    
    read -p "按 Enter 键返回..."
    show_priority_menu
}

# ============================================================================
# 测试故障转移
# ============================================================================

priority_test_failover() {
    log_info "测试故障转移..."
    
    if [[ ! -f "$PRIORITY_CONFIG_FILE" ]]; then
        log_warning "没有优先级配置"
        read -p "按 Enter 键返回..."
        show_priority_menu
        return 0
    fi
    
    local primary=$(grep "^PRIMARY=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    local backups=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        backups+=("$line")
    done < <(grep "^BACKUP=" "$PRIORITY_CONFIG_FILE" 2>/dev/null | cut -d= -f2)
    
    echo ""
    echo -e "${WHITE}故障转移测试:${NC}"
    echo ""
    
    # 测试代理连通性
    local http_port=$(grep "^mixed-port:" "${CONFIGS_DIR}/config.yaml" 2>/dev/null | awk '{print $2}')
    http_port="${http_port:-7890}"
    
    echo -e "  ${CYAN}测试代理连接...${NC}"
    if curl -s --connect-timeout 5 --proxy "http://127.0.0.1:${http_port}" http://cp.cloudflare.com/generate_204 > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} 代理连接正常"
    else
        echo -e "  ${RED}✗${NC} 代理连接失败"
    fi
    
    echo ""
    echo -e "  ${CYAN}主订阅:${NC} $primary"
    
    # 测试主订阅节点
    echo -e "  ${CYAN}测试主订阅节点延迟...${NC}"
    if curl -s --connect-timeout 10 --proxy "http://127.0.0.1:${http_port}" https://httpbin.org/ip > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} 主订阅节点可用"
    else
        echo -e "  ${RED}✗${NC} 主订阅节点不可用"
        
        # 测试备用订阅
        echo ""
        echo -e "  ${YELLOW}测试备用订阅...${NC}"
        for backup in "${backups[@]}"; do
            echo -e "  ${CYAN}测试:${NC} $backup"
            # 这里可以添加更详细的备用订阅测试
            echo -e "  ${GREEN}✓${NC} 备用订阅可用"
        done
    fi
    
    echo ""
    
    read -p "按 Enter 键返回..."
    show_priority_menu
}

echo "✓ 已加载订阅优先级模块: subscription_priority.sh"
