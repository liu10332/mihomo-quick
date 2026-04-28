#!/bin/bash
#
# mode.sh - 代理模式管理模块
# 提供代理模式切换功能
#

# 显示模式管理菜单
show_mode_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      代理模式管理                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}当前模式: $(get_current_mode)${NC}"
    echo ""
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. TUN模式（透明代理）"
    echo -e "  ${GREEN}2${NC}. 系统代理（HTTP/SOCKS5）"
    echo -e "  ${GREEN}3${NC}. TAP模式（二层代理）"
    echo -e "  ${GREEN}4${NC}. 混合模式"
    echo -e "  ${GREEN}5${NC}. 查看模式详情"
    echo -e "  ${GREEN}0${NC}. 返回主菜单"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    read -p "请输入选择 (0-5): " choice
    
    case $choice in
        1) switch_mode "tun" ;;
        2) switch_mode "system" ;;
        3) switch_mode "tap" ;;
        4) switch_mode "mixed" ;;
        5) show_mode_details ;;
        0) return ;;
        *) log_error "无效选择"; sleep 1; show_mode_menu ;;
    esac
}

# 处理模式命令
handle_mode_command() {
    local command=$1
    
    case $command in
        tun)
            switch_mode "tun"
            ;;
        system)
            switch_mode "system"
            ;;
        tap)
            switch_mode "tap"
            ;;
        mixed)
            switch_mode "mixed"
            ;;
        *)
            log_error "未知模式: $command"
            echo "用法: mihomo-quick.sh mode [tun|system|tap|mixed]"
            return 1
            ;;
    esac
}

# 获取当前模式
get_current_mode() {
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ -f "$config_file" ]]; then
        # 检查TUN配置
        if grep -q "^tun:" "$config_file" && grep -q "enable: true" "$config_file"; then
            if grep -q "^mixed-port:" "$config_file"; then
                echo "混合模式"
            else
                echo "TUN模式"
            fi
        elif grep -q "^tap:" "$config_file" && grep -q "enable: true" "$config_file"; then
            echo "TAP模式"
        elif grep -q "^mixed-port:" "$config_file"; then
            echo "系统代理"
        else
            echo "未知模式"
        fi
    else
        echo "未配置"
    fi
}

# 切换模式
switch_mode() {
    local mode=$1
    
    log_info "切换到${mode}模式..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    # 备份当前配置
    if [[ -f "$config_file" ]]; then
        backup_file "$config_file"
    fi
    
    # 读取当前配置中的变量
    local http_port=$(grep "^mixed-port:" "$config_file" 2>/dev/null | awk '{print $2}')
    http_port="${http_port:-7890}"
    local socks_port=$(grep "^socks-port:" "$config_file" 2>/dev/null | awk '{print $2}')
    socks_port="${socks_port:-7891}"
    local tun_device=$(grep "device:" "$config_file" 2>/dev/null | awk '{print $2}')
    tun_device="${tun_device:-tun0}"
    local tun_ip=$(grep "gateway:" "$config_file" 2>/dev/null | awk '{print $2}')
    tun_ip="${tun_ip:-10.0.0.1}"
    
    # 提取当前订阅、代理组和规则（proxy-providers 到文件末尾）
    local _old_extra=""
    if [[ -f "$config_file" ]]; then
        _old_extra=$(sed -n '/^proxy-providers:/,$ p' "$config_file")
    fi
    
    # 设置变量供 generate_simple_config 使用
    MODE="$mode"
    HTTP_PORT="$http_port"
    SOCKS_PORT="$socks_port"
    API_PORT="9090"
    TUN_DEVICE="$tun_device"
    TUN_GATEWAY="$tun_ip"
    TUN_MTU="9000"
    
    # 使用 generate_simple_config 生成基础配置
    local _script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    source "${_script_dir}/lib/config_wizard.sh" 2>/dev/null
    generate_simple_config
    
    # 追加原有的订阅、代理组和规则配置
    if [[ -n "$_old_extra" ]]; then
        echo "" >> "$config_file"
        echo "$_old_extra" >> "$config_file"
        log_info "已保留原有订阅和规则配置"
    fi
    
    log_success "已切换到${mode}模式"
    
    # 更新systemd服务文件（TUN/非TUN模式切换）
    source "${SCRIPT_DIR}/lib/service.sh" 2>/dev/null
    if type create_service_file &>/dev/null; then
        create_service_file
        log_info "服务文件已更新"
    fi
    
    # 如果服务正在运行，重启服务
    if systemctl is-active --quiet mihomo-quick.service 2>/dev/null; then
        log_info "重启服务以应用新模式..."
        sudo systemctl restart mihomo-quick.service
        log_success "服务已重启"
    fi
    
    read -p "按 Enter 键返回..."
    show_mode_menu
}

# 显示模式详情
show_mode_details() {
    log_info "显示模式详情..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ -f "$config_file" ]]; then
        echo ""
        echo -e "${WHITE}当前模式详情:${NC}"
        echo ""
        
        # 显示基本配置
        echo -e "${CYAN}基本配置:${NC}"
        echo "  HTTP端口: $(grep "^mixed-port:" "$config_file" | awk '{print $2}' || echo "未配置")"
        echo "  SOCKS端口: $(grep "^socks-port:" "$config_file" | awk '{print $2}' || echo "未配置")"
        echo "  运行模式: $(grep "^mode:" "$config_file" | awk '{print $2}' || echo "未配置")"
        
        echo ""
        echo -e "${CYAN}TUN配置:${NC}"
        if grep -q "^tun:" "$config_file"; then
            echo "  启用: $(grep -A 1 "^tun:" "$config_file" | grep "enable:" | awk '{print $2}' || echo "未配置")"
            echo "  设备: $(grep -A 5 "^tun:" "$config_file" | grep "device:" | awk '{print $2}' || echo "未配置")"
            echo "  网关: $(grep -A 5 "^tun:" "$config_file" | grep "gateway:" | awk '{print $2}' || echo "未配置")"
        else
            echo "  未配置"
        fi
        
        echo ""
        echo -e "${CYAN}DNS配置:${NC}"
        if grep -q "^dns:" "$config_file"; then
            echo "  启用: $(grep -A 1 "^dns:" "$config_file" | grep "enable:" | awk '{print $2}' || echo "未配置")"
            echo "  模式: $(grep -A 5 "^dns:" "$config_file" | grep "enhanced-mode:" | awk '{print $2}' || echo "未配置")"
        else
            echo "  未配置"
        fi
        
        echo ""
    else
        log_warning "配置文件不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_mode_menu
}

echo "✓ 已加载代理模式管理模块: mode.sh"
