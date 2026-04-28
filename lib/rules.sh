#!/bin/bash
#
# rules.sh - 黑白名单与规则管理模块
# 提供代理规则、直连规则、黑白名单的管理功能
#

# ============================================================================
# 规则配置文件路径
# ============================================================================

RULES_CUSTOM_FILE="${CONFIGS_DIR}/rules_custom.conf"

# ============================================================================
# 规则管理菜单
# ============================================================================

show_rules_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    规则管理（黑白名单）                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. 查看当前规则"
    echo -e "  ${GREEN}2${NC}. 添加走代理的域名/IP（白名单）"
    echo -e "  ${GREEN}3${NC}. 添加排除代理的域名/IP（黑名单/直连）"
    echo -e "  ${GREEN}4${NC}. 删除自定义规则"
    echo -e "  ${GREEN}5${NC}. 列出所有自定义规则"
    echo -e "  ${GREEN}6${NC}. 切换规则模式（白名单/黑名单）"
    echo -e "  ${GREEN}7${NC}. 导入规则文件"
    echo -e "  ${GREEN}8${NC}. 导出规则文件"
    echo -e "  ${GREEN}0${NC}. 返回主菜单"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    read -p "请输入选择 (0-8): " choice
    
    case $choice in
        1) rules_show ;;
        2) rules_add_proxy ;;
        3) rules_add_direct ;;
        4) rules_delete ;;
        5) rules_list_custom ;;
        6) rules_switch_mode ;;
        7) rules_import ;;
        8) rules_export ;;
        0) return ;;
        *) log_error "无效选择"; sleep 1; show_rules_menu ;;
    esac
}

# 处理规则命令
handle_rules_command() {
    local command=$1
    shift
    
    case $command in
        show)
            rules_show
            ;;
        add-proxy|addproxy)
            rules_add_proxy "$@"
            ;;
        add-direct|adddirect)
            rules_add_direct "$@"
            ;;
        del|delete|rm)
            rules_delete "$@"
            ;;
        list|ls)
            rules_list_custom
            ;;
        mode)
            if [[ -n "$1" ]]; then
                rules_set_mode "$1"
            else
                rules_switch_mode
            fi
            ;;
        import)
            rules_import "$@"
            ;;
        export)
            rules_export "$@"
            ;;
        *)
            log_error "未知规则命令: $command"
            echo ""
            echo "用法: mihomo-quick.sh rules [命令]"
            echo ""
            echo "命令:"
            echo "  show            查看当前规则"
            echo "  add-proxy <规则>  添加走代理的域名/IP"
            echo "  add-direct <规则> 添加排除代理的域名/IP（直连）"
            echo "  del <规则>       删除自定义规则"
            echo "  list            列出所有自定义规则"
            echo "  mode [whitelist|blacklist] 切换规则模式"
            echo "  import <文件>    导入规则文件"
            echo "  export [文件]    导出规则文件"
            echo ""
            echo "规则格式:"
            echo "  DOMAIN-SUFFIX,example.com    域名后缀匹配"
            echo "  DOMAIN,example.com           精确域名匹配"
            echo "  DOMAIN-KEYWORD,example       域名关键字匹配"
            echo "  IP-CIDR,192.168.0.0/16       IP段匹配"
            echo "  GEOIP,CN                     国家IP匹配"
            echo ""
            echo "示例:"
            echo "  mihomo-quick.sh rules add-proxy DOMAIN-SUFFIX,openai.com"
            echo "  mihomo-quick.sh rules add-direct DOMAIN-SUFFIX,baidu.com"
            echo "  mihomo-quick.sh rules add-direct IP-CIDR,10.0.0.0/8"
            return 1
            ;;
    esac
}

# ============================================================================
# 规则查看
# ============================================================================

# 查看当前规则
rules_show() {
    log_info "查看当前规则..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        read -p "按 Enter 键返回..."
        show_rules_menu
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}当前规则配置:${NC}"
    echo ""
    
    # 显示规则模式
    if grep -q "# 规则配置（白名单模式）" "$config_file"; then
        echo -e "  规则模式: ${GREEN}白名单模式${NC}（只有列表中的走代理）"
    elif grep -q "# 规则配置（黑名单模式）" "$config_file"; then
        echo -e "  规则模式: ${YELLOW}黑名单模式${NC}（列表中的走直连）"
    else
        echo -e "  规则模式: ${CYAN}自定义${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}代理规则（走代理）:${NC}"
    echo ""
    
    # 提取走代理的规则（非DIRECT的规则）
    sed -n '/^rules:/,/^[a-zA-Z]/p' "$config_file" | grep -v "^rules:" | grep -v "^$" | grep -v "DIRECT" | grep -v "^#" | while read -r line; do
        if [[ -n "$line" && "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
            echo -e "  ${GREEN}→${NC} $(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')"
        fi
    done
    
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}直连规则（排除代理）:${NC}"
    echo ""
    
    # 提取直连的规则
    sed -n '/^rules:/,/^[a-zA-Z]/p' "$config_file" | grep "DIRECT" | while read -r line; do
        if [[ -n "$line" && "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
            echo -e "  ${BLUE}↗${NC} $(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')"
        fi
    done
    
    echo ""
    
    # 显示自定义规则
    if [[ -f "$RULES_CUSTOM_FILE" ]]; then
        echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
        echo -e "${WHITE}自定义规则:${NC}"
        echo ""
        cat "$RULES_CUSTOM_FILE" | while read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            if echo "$line" | grep -q "DIRECT"; then
                echo -e "  ${BLUE}↗${NC} $line"
            else
                echo -e "  ${GREEN}→${NC} $line"
            fi
        done
        echo ""
    fi
    
    read -p "按 Enter 键返回..."
    show_rules_menu
}

# ============================================================================
# 规则添加
# ============================================================================

# 添加走代理的规则（白名单）
rules_add_proxy() {
    local rule="$1"
    
    if [[ -z "$rule" ]]; then
        echo ""
        echo -e "${WHITE}添加走代理的规则${NC}"
        echo ""
        echo "规则格式:"
        echo "  DOMAIN-SUFFIX,example.com    域名后缀匹配"
        echo "  DOMAIN,example.com           精确域名匹配"
        echo "  DOMAIN-KEYWORD,example       域名关键字匹配"
        echo "  IP-CIDR,192.168.0.0/16       IP段匹配"
        echo ""
        read -p "请输入规则: " rule
        
        if [[ -z "$rule" ]]; then
            log_error "规则不能为空"
            read -p "按 Enter 键返回..."
            show_rules_menu
            return 1
        fi
    fi
    
    # 获取目标代理组
    local target_group="🔄 智能切换"
    if [[ -z "$2" ]]; then
        echo ""
        echo "选择目标代理组:"
        echo "  1. 🔄 智能切换（推荐，自动故障转移）"
        echo "  2. 🚀 节点选择（自动选择最快节点）"
        echo "  3. 📱 手动选择"
        read -p "请选择 [1-3]: " group_choice
        
        case $group_choice in
            1) target_group="🔄 智能切换" ;;
            2) target_group="🚀 节点选择" ;;
            3) target_group="📱 手动选择" ;;
        esac
    else
        target_group="$2"
    fi
    
    # 构建完整规则
    local full_rule="${rule},${target_group}"
    
    # 保存到自定义规则文件
    mkdir -p "$(dirname "$RULES_CUSTOM_FILE")"
    echo "$full_rule" >> "$RULES_CUSTOM_FILE"
    
    log_success "已添加代理规则: $full_rule"
    
    # 注入到配置文件
    _inject_rule_to_config "$full_rule"
    
    # 重启服务以生效
    _restart_if_running
    
    [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_rules_menu
}

# 添加排除代理的规则（黑名单/直连）
rules_add_direct() {
    local rule="$1"
    
    if [[ -z "$rule" ]]; then
        echo ""
        echo -e "${WHITE}添加排除代理的规则（直连）${NC}"
        echo ""
        echo "规则格式:"
        echo "  DOMAIN-SUFFIX,example.com    域名后缀匹配"
        echo "  DOMAIN,example.com           精确域名匹配"
        echo "  DOMAIN-KEYWORD,example       域名关键字匹配"
        echo "  IP-CIDR,192.168.0.0/16       IP段匹配"
        echo ""
        read -p "请输入规则: " rule
        
        if [[ -z "$rule" ]]; then
            log_error "规则不能为空"
            read -p "按 Enter 键返回..."
            show_rules_menu
            return 1
        fi
    fi
    
    # 构建完整规则
    local full_rule="${rule},DIRECT"
    
    # 保存到自定义规则文件
    mkdir -p "$(dirname "$RULES_CUSTOM_FILE")"
    echo "$full_rule" >> "$RULES_CUSTOM_FILE"
    
    log_success "已添加直连规则: $full_rule"
    
    # 注入到配置文件
    _inject_rule_to_config "$full_rule"
    
    # 重启服务以生效
    _restart_if_running
    
    [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_rules_menu
}

# ============================================================================
# 规则删除
# ============================================================================

rules_delete() {
    local rule_to_delete="$1"
    
    if [[ ! -f "$RULES_CUSTOM_FILE" ]]; then
        log_warning "没有自定义规则"
        [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_rules_menu
        return 0
    fi
    
    if [[ -z "$rule_to_delete" ]]; then
        echo ""
        echo -e "${WHITE}自定义规则列表:${NC}"
        echo ""
        
        local idx=1
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            echo -e "  ${GREEN}$idx${NC}. $line"
            ((idx++))
        done < "$RULES_CUSTOM_FILE"
        
        echo ""
        read -p "请输入要删除的规则编号（或输入规则内容）: " input
        
        if [[ "$input" =~ ^[0-9]+$ ]]; then
            # 按编号删除
            rule_to_delete=$(sed -n "${input}p" "$RULES_CUSTOM_FILE" 2>/dev/null)
        else
            rule_to_delete="$input"
        fi
    fi
    
    if [[ -z "$rule_to_delete" ]]; then
        log_error "规则不能为空"
        read -p "按 Enter 键返回..."
        show_rules_menu
        return 1
    fi
    
    # 从自定义规则文件中删除
    if grep -qF "$rule_to_delete" "$RULES_CUSTOM_FILE"; then
        sed -i "/$(echo "$rule_to_delete" | sed 's/[\/&]/\\&/g')/d" "$RULES_CUSTOM_FILE"
        log_success "已删除规则: $rule_to_delete"
    else
        log_warning "未找到规则: $rule_to_delete"
    fi
    
    # 从配置文件中删除
    _remove_rule_from_config "$rule_to_delete"
    
    # 重启服务以生效
    _restart_if_running
    
    [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_rules_menu
}

# ============================================================================
# 规则列表
# ============================================================================

rules_list_custom() {
    log_info "列出所有自定义规则..."
    
    echo ""
    
    if [[ ! -f "$RULES_CUSTOM_FILE" ]]; then
        echo -e "  ${YELLOW}没有自定义规则${NC}"
        echo ""
        echo -e "${WHITE}添加规则:${NC}"
        echo "  mihomo-quick.sh rules add-proxy DOMAIN-SUFFIX,openai.com"
        echo "  mihomo-quick.sh rules add-direct DOMAIN-SUFFIX,baidu.com"
        echo ""
        read -p "按 Enter 键返回..."
        show_rules_menu
        return 0
    fi
    
    echo -e "${WHITE}自定义规则:${NC}"
    echo ""
    
    local proxy_count=0
    local direct_count=0
    
    echo -e "${CYAN}代理规则:${NC}"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if echo "$line" | grep -q "DIRECT"; then
            continue
        fi
        echo -e "  ${GREEN}→${NC} $line"
        ((proxy_count++))
    done < "$RULES_CUSTOM_FILE"
    
    if [[ $proxy_count -eq 0 ]]; then
        echo -e "  ${YELLOW}无${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}直连规则:${NC}"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if echo "$line" | grep -q "DIRECT"; then
            echo -e "  ${BLUE}↗${NC} $line"
            ((direct_count++))
        fi
    done < "$RULES_CUSTOM_FILE"
    
    if [[ $direct_count -eq 0 ]]; then
        echo -e "  ${YELLOW}无${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}统计:${NC} 代理规则 $proxy_count 条，直连规则 $direct_count 条"
    echo ""
    
    read -p "按 Enter 键返回..."
    show_rules_menu
}

# ============================================================================
# 规则模式切换
# ============================================================================

rules_switch_mode() {
    echo ""
    echo -e "${WHITE}切换规则模式${NC}"
    echo ""
    echo "  1. 白名单模式（只有列表中的走代理，其他直连）"
    echo "  2. 黑名单模式（列表中的直连，其他走代理）"
    echo ""
    read -p "请选择 [1-2]: " mode_choice
    
    case $mode_choice in
        1) rules_set_mode "whitelist" ;;
        2) rules_set_mode "blacklist" ;;
        *) log_error "无效选择"; sleep 1; rules_switch_mode ;;
    esac
}

rules_set_mode() {
    local mode="$1"
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    log_info "切换到${mode}模式..."
    
    # 备份配置
    backup_file "$config_file"
    
    # 获取当前订阅和代理组配置
    local providers_block=$(sed -n '/^proxy-providers:/,/^[a-zA-Z]/p' "$config_file" 2>/dev/null)
    local groups_block=$(sed -n '/^proxy-groups:/,/^[a-zA-Z]/p' "$config_file" 2>/dev/null | head -n -1)
    
    # 获取基础配置（rules之前的部分）
    local base_config=$(sed '/^proxy-providers:/,$d' "$config_file")
    
    # 重新生成配置
    local temp_file=$(mktemp)
    echo "$base_config" > "$temp_file"
    
    # 追加订阅和代理组
    if [[ -n "$providers_block" ]]; then
        echo "" >> "$temp_file"
        echo "$providers_block" >> "$temp_file"
    fi
    if [[ -n "$groups_block" ]]; then
        echo "" >> "$temp_file"
        echo "$groups_block" >> "$temp_file"
    fi
    
    # 追加规则
    echo "" >> "$temp_file"
    
    if [[ "$mode" == "whitelist" ]]; then
        cat >> "$temp_file" << 'EOF'
# 规则配置（白名单模式）
rules:
  # 大模型API直连
  - DOMAIN-SUFFIX,anthropic.com,DIRECT
  - DOMAIN-SUFFIX,bigmodel.cn,DIRECT
  - DOMAIN-SUFFIX,dataeyes.ai,DIRECT
  - DOMAIN-SUFFIX,openai.com,DIRECT
  - DOMAIN-SUFFIX,openrouter.ai,DIRECT
  - DOMAIN-SUFFIX,volcengine.com,DIRECT
  - DOMAIN-SUFFIX,volces.com,DIRECT
  - DOMAIN-SUFFIX,xiaomimimo.com,DIRECT

  # Google API走代理
  - DOMAIN-SUFFIX,googleapis.com,🔄 智能切换

  # 国内常用网站直连
  - DOMAIN-SUFFIX,baidu.com,DIRECT
  - DOMAIN-SUFFIX,qq.com,DIRECT
  - DOMAIN-SUFFIX,taobao.com,DIRECT
  - DOMAIN-SUFFIX,alibaba.com,DIRECT
  - DOMAIN-SUFFIX,aliyun.com,DIRECT
  - DOMAIN-SUFFIX,jd.com,DIRECT
  - DOMAIN-SUFFIX,bilibili.com,DIRECT

  # 本地网络直连
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT

  # 中国IP直连
  - GEOIP,CN,DIRECT
EOF
    else
        cat >> "$temp_file" << 'EOF'
# 规则配置（黑名单模式）
rules:
  # 大模型API直连
  - DOMAIN-SUFFIX,anthropic.com,DIRECT
  - DOMAIN-SUFFIX,bigmodel.cn,DIRECT
  - DOMAIN-SUFFIX,dataeyes.ai,DIRECT
  - DOMAIN-SUFFIX,openai.com,DIRECT
  - DOMAIN-SUFFIX,openrouter.ai,DIRECT
  - DOMAIN-SUFFIX,volcengine.com,DIRECT
  - DOMAIN-SUFFIX,volces.com,DIRECT
  - DOMAIN-SUFFIX,xiaomimimo.com,DIRECT

  # Google API走代理
  - DOMAIN-SUFFIX,googleapis.com,🔄 智能切换

  # 本地网络直连
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT

  # 中国IP直连
  - GEOIP,CN,DIRECT
EOF
    fi
    
    # 添加默认规则
    if [[ "$mode" == "whitelist" ]]; then
        echo "  # 默认规则（其他走代理）" >> "$temp_file"
        echo "  - MATCH,🔄 智能切换" >> "$temp_file"
    else
        echo "  # 默认规则（其他走代理）" >> "$temp_file"
        echo "  - MATCH,🔄 智能切换" >> "$temp_file"
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
    
    log_success "已切换到${mode}模式"
    
    # 重启服务
    _restart_if_running
    
    read -p "按 Enter 键返回..."
    show_rules_menu
}

# ============================================================================
# 规则导入导出
# ============================================================================

rules_import() {
    local import_file="$1"
    
    if [[ -z "$import_file" ]]; then
        echo ""
        read -p "请输入规则文件路径: " import_file
    fi
    
    if [[ ! -f "$import_file" ]]; then
        log_error "文件不存在: $import_file"
        [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_rules_menu
        return 1
    fi
    
    # 追加到自定义规则文件
    mkdir -p "$(dirname "$RULES_CUSTOM_FILE")"
    cat "$import_file" >> "$RULES_CUSTOM_FILE"
    
    local count=$(wc -l < "$import_file")
    log_success "已导入 $count 条规则"
    
    # 注入到配置文件
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        _inject_rule_to_config "$line"
    done < "$import_file"
    
    _restart_if_running
    
    [[ -z "$1" ]] && read -p "按 Enter 键返回..." && show_rules_menu
}

rules_export() {
    local export_file="$1"
    
    if [[ -z "$export_file" ]]; then
        export_file="${CONFIGS_DIR}/rules_export_$(date +%Y%m%d_%H%M%S).conf"
    fi
    
    if [[ ! -f "$RULES_CUSTOM_FILE" ]]; then
        log_warning "没有自定义规则可导出"
        read -p "按 Enter 键返回..."
        show_rules_menu
        return 0
    fi
    
    cp "$RULES_CUSTOM_FILE" "$export_file"
    log_success "规则已导出: $export_file"
    
    read -p "按 Enter 键返回..."
    show_rules_menu
}

# ============================================================================
# 内部辅助函数
# ============================================================================

# 将规则注入到配置文件的rules部分
_inject_rule_to_config() {
    local rule="$1"
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # 找到 MATCH 规则（默认规则），在其前面插入
    if grep -q "^  - MATCH," "$config_file"; then
        sed -i "/^  - MATCH,/i\\  - $rule" "$config_file"
        log_debug "规则已注入配置: $rule"
    else
        # 如果没有MATCH规则，追加到rules末尾
        echo "  - $rule" >> "$config_file"
        log_debug "规则已追加到配置末尾: $rule"
    fi
}

# 从配置文件中删除规则
_remove_rule_from_config() {
    local rule="$1"
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # 删除匹配的规则行
    local escaped_rule=$(echo "$rule" | sed 's/[\/&]/\\&/g')
    sed -i "/  - ${escaped_rule}/d" "$config_file" 2>/dev/null
    log_debug "规则已从配置中删除: $rule"
}

# 重启服务（如果正在运行）
_restart_if_running() {
    if systemctl is-active --quiet mihomo-quick.service 2>/dev/null; then
        log_info "重启服务以应用规则变更..."
        sudo systemctl restart mihomo-quick.service 2>/dev/null
        log_success "服务已重启"
    fi
}

echo "✓ 已加载规则管理模块: rules.sh"
