#!/bin/bash
#
# config.sh - 配置管理模块
# 提供配置向导、导入导出等功能
#

# 显示配置管理菜单
show_config_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      配置管理                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. 配置向导"
    echo -e "  ${GREEN}2${NC}. 查看当前配置"
    echo -e "  ${GREEN}3${NC}. 导出配置"
    echo -e "  ${GREEN}4${NC}. 导入配置"
    echo -e "  ${GREEN}5${NC}. 备份配置"
    echo -e "  ${GREEN}6${NC}. 恢复配置"
    echo -e "  ${GREEN}0${NC}. 返回主菜单"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    read -p "请输入选择 (0-6): " choice
    
    case $choice in
        1) config_wizard ;;
        2) config_show ;;
        3) config_export ;;
        4) config_import ;;
        5) config_backup ;;
        6) config_restore ;;
        0) return ;;
        *) log_error "无效选择"; sleep 1; show_config_menu ;;
    esac
}

# 配置向导
config_wizard() {
    log_info "启动配置向导..."
    
    echo ""
    echo -e "${WHITE}配置向导${NC}"
    echo ""
    
    # 选择代理模式
    echo -e "${WHITE}第一步: 选择代理模式${NC}"
    echo "1. TUN模式（透明代理）"
    echo "2. 系统代理（HTTP/SOCKS5）"
    echo "3. TAP模式（二层代理）"
    echo "4. 混合模式"
    read -p "请选择 [1-4]: " mode_choice
    
    case $mode_choice in
        1) mode="tun" ;;
        2) mode="system" ;;
        3) mode="tap" ;;
        4) mode="mixed" ;;
        *) log_error "无效选择"; return 1 ;;
    esac
    
    # 配置端口
    echo ""
    echo -e "${WHITE}第二步: 配置端口${NC}"
    read -p "HTTP代理端口 [7890]: " http_port
    http_port=${http_port:-7890}
    read -p "SOCKS5代理端口 [7891]: " socks_port
    socks_port=${socks_port:-7891}
    
    # 配置TUN（如果选择TUN或混合模式）
    if [[ "$mode" == "tun" || "$mode" == "mixed" ]]; then
        echo ""
        echo -e "${WHITE}第三步: 配置TUN${NC}"
        read -p "TUN设备名 [tun0]: " tun_device
        tun_device=${tun_device:-tun0}
        read -p "TUN IP地址 [10.0.0.1]: " tun_ip
        tun_ip=${tun_ip:-10.0.0.1}
    fi
    
    # 配置订阅
    echo ""
    echo -e "${WHITE}第四步: 配置订阅${NC}"
    read -p "订阅URL (可选): " sub_url
    if [[ -n "$sub_url" ]]; then
        read -p "订阅名称 [provider-a]: " sub_name
        sub_name=${sub_name:-provider-a}
    fi
    
    # 配置规则模式
    echo ""
    echo -e "${WHITE}第五步: 配置规则${NC}"
    echo "1. 白名单模式（只有列表中的走代理）"
    echo "2. 黑名单模式（列表中的走直连）"
    read -p "请选择 [1-2]: " rule_mode
    
    # 生成配置
    log_info "生成配置文件..."
    
    # 创建配置目录
    mkdir -p "$CONFIGS_DIR"
    
    # 设置变量供 generate_simple_config 使用
    MODE="$mode"
    HTTP_PORT="$http_port"
    SOCKS_PORT="$socks_port"
    API_PORT="9090"
    TUN_DEVICE="${tun_device:-tun0}"
    TUN_GATEWAY="${tun_ip:-10.0.0.1}"
    TUN_MTU="9000"
    PROVIDER_NAME="${sub_name:-}"
    PROVIDER_URL="${sub_url:-}"
    PROVIDER_INTERVAL="3600"
    [[ "$rule_mode" == "1" ]] && RULE_MODE="whitelist" || RULE_MODE="blacklist"
    
    # 加载配置向导模块并使用其生成函数
    local _script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    source "${_script_dir}/lib/config_wizard.sh" 2>/dev/null
    generate_simple_config
    
    # 添加订阅配置
    if [[ -n "$sub_url" ]]; then
        add_subscription_config
    fi
    
    # 添加规则配置
    add_rules_config
    
    log_success "配置文件生成完成: ${CONFIGS_DIR}/config.yaml"
        
    echo ""
    echo -e "${GREEN}配置生成完成！${NC}"
    echo -e "配置文件: ${CONFIGS_DIR}/config.yaml"
    echo ""
    echo -e "${YELLOW}提示: 请根据实际情况修改配置文件中的订阅URL和规则${NC}"
    
    read -p "按 Enter 键返回..."
    show_config_menu
}

# 查看当前配置
config_show() {
    log_info "查看当前配置..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ -f "$config_file" ]]; then
        echo ""
        echo -e "${WHITE}当前配置:${NC}"
        echo ""
        cat "$config_file"
        echo ""
    else
        log_warning "配置文件不存在: $config_file"
        log_info "请先运行配置向导"
    fi
    
    read -p "按 Enter 键返回..."
    show_config_menu
}

# 导出配置
config_export() {
    log_info "导出配置..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    local export_file="${CONFIGS_DIR}/config-$(date +%Y%m%d_%H%M%S).yaml"
    
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$export_file"
        log_success "配置已导出: $export_file"
    else
        log_error "配置文件不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_config_menu
}

# 导入配置
config_import() {
    log_info "导入配置..."
    
    read -p "请输入配置文件路径: " import_file
    
    if [[ -f "$import_file" ]]; then
        cp "$import_file" "${CONFIGS_DIR}/config.yaml"
        log_success "配置已导入"
    else
        log_error "文件不存在: $import_file"
    fi
    
    read -p "按 Enter 键返回..."
    show_config_menu
}

# 备份配置
config_backup() {
    log_info "备份配置..."
    
    backup_file "${CONFIGS_DIR}/config.yaml"
    
    read -p "按 Enter 键返回..."
    show_config_menu
}

# 恢复配置
config_restore() {
    log_info "恢复配置..."
    
    local backup_dir="${BACKUPS_DIR:-./backups}"
    
    if [[ -d "$backup_dir" ]]; then
        echo ""
        echo -e "${WHITE}可用的备份文件:${NC}"
        ls -1 "$backup_dir"/*.bak 2>/dev/null | head -10
        echo ""
        
        read -p "请输入备份文件路径: " backup_file
        
        if [[ -f "$backup_file" ]]; then
            restore_file "$backup_file" "${CONFIGS_DIR}/config.yaml"
        else
            log_error "备份文件不存在: $backup_file"
        fi
    else
        log_warning "备份目录不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_config_menu
}

echo "✓ 已加载配置管理模块: config.sh"
