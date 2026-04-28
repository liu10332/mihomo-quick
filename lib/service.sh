#!/bin/bash
#
# service.sh - 服务管理模块
# 提供服务启停、状态查看、日志管理等功能
#

# 显示服务管理菜单
show_service_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      服务管理                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. 启动服务"
    echo -e "  ${GREEN}2${NC}. 停止服务"
    echo -e "  ${GREEN}3${NC}. 重启服务"
    echo -e "  ${GREEN}4${NC}. 查看状态"
    echo -e "  ${GREEN}5${NC}. 查看日志"
    echo -e "  ${GREEN}6${NC}. 服务配置"
    echo -e "  ${GREEN}0${NC}. 返回主菜单"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    read -p "请输入选择 (0-6): " choice
    
    case $choice in
        1) service_start ;;
        2) service_stop ;;
        3) service_restart ;;
        4) service_status ;;
        5) service_logs ;;
        6) service_config ;;
        0) return ;;
        *) log_error "无效选择"; sleep 1; show_service_menu ;;
    esac
}

# 启动服务（参照 mihomo-proxy-export，自动配置 npm 代理）
service_start() {
    log_info "启动服务..."
    
    # 检查配置文件
    local config_file="${CONFIGS_DIR}/config.yaml"
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        log_info "请先运行配置向导: ./mihomo-quick.sh config"
        read -p "按 Enter 键返回..."
        show_service_menu
        return 1
    fi
    
    # 检查mihomo是否安装
    local mihomo_bin=$(which mihomo 2>/dev/null || echo "${HOME}/.mihomo-quick/mihomo")
    if [[ ! -f "$mihomo_bin" ]]; then
        log_error "mihomo未安装"
        log_info "请先安装mihomo"
        read -p "按 Enter 键返回..."
        show_service_menu
        return 1
    fi
    
    # 创建systemd服务文件
    create_service_file
    
    # 启动服务
    if sudo systemctl start mihomo-quick.service; then
        log_success "服务启动成功"
        
        # 启用自启动
        if sudo systemctl enable mihomo-quick.service; then
            log_success "已启用自启动"
        else
            log_warning "启用自启动失败"
        fi
        
        # 等待服务就绪
        sleep 2
        
        # 自动配置 npm 代理（参照 mihomo-proxy-export）
        local http_port="${HTTP_PORT:-7890}"
        echo ""
        log_info "配置 npm 代理..."
        if command -v npm &> /dev/null; then
            local current_proxy=$(npm config get proxy 2>/dev/null)
            local expected_proxy="http://127.0.0.1:${http_port}"
            if [[ "$current_proxy" != "$expected_proxy" ]]; then
                npm config set proxy "$expected_proxy" 2>/dev/null
                npm config set https-proxy "$expected_proxy" 2>/dev/null
                log_success "npm 代理已配置: $expected_proxy"
            else
                log_success "npm 代理已正确配置"
            fi
        else
            log_debug "npm 未安装，跳过"
        fi
        
        # 显示代理信息
        echo ""
        echo -e "${WHITE}代理服务已就绪:${NC}"
        echo "  HTTP代理: http://127.0.0.1:${http_port}"
        echo "  SOCKS5代理: socks5://127.0.0.1:${SOCKS_PORT:-7891}"
        echo "  控制面板: http://127.0.0.1:9090/ui"
        echo ""
        echo -e "${YELLOW}环境变量设置:${NC}"
        echo "  export http_proxy=http://127.0.0.1:${http_port}"
        echo "  export https_proxy=http://127.0.0.1:${http_port}"
    else
        log_error "服务启动失败"
        log_info "请查看日志: journalctl -u mihomo-quick.service -f"
    fi
    
    read -p "按 Enter 键返回..."
    show_service_menu
}

# 停止服务（参照 mihomo-proxy-export，自动清理 npm 代理）
service_stop() {
    log_info "停止服务..."
    
    if sudo systemctl stop mihomo-quick.service; then
        log_success "服务停止成功"
        
        # 禁用自启动
        if sudo systemctl disable mihomo-quick.service; then
            log_success "已禁用自启动"
        else
            log_warning "禁用自启动失败"
        fi
        
        # 自动清理 npm 代理（参照 mihomo-proxy-export）
        echo ""
        log_info "清理 npm 代理..."
        if command -v npm &> /dev/null; then
            npm config delete proxy 2>/dev/null
            npm config delete https-proxy 2>/dev/null
            log_success "npm 代理已清理"
        else
            log_debug "npm 未安装，跳过"
        fi
        
        # 提示清理环境变量
        echo ""
        echo -e "${YELLOW}提示: 如需清理环境变量，请执行:${NC}"
        echo "  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY"
    else
        log_error "服务停止失败"
    fi
    
    read -p "按 Enter 键返回..."
    show_service_menu
}

# 重启服务
service_restart() {
    log_info "重启服务..."
    
    if sudo systemctl restart mihomo-quick.service; then
        log_success "服务重启成功"
    else
        log_error "服务重启失败"
    fi
    
    read -p "按 Enter 键返回..."
    show_service_menu
}

# 查看状态
service_status() {
    log_info "查看服务状态..."
    
    echo ""
    echo -e "${WHITE}服务状态:${NC}"
    echo ""
    
    # 检查服务状态
    if systemctl is-active --quiet mihomo-quick.service 2>/dev/null; then
        echo -e "  状态: ${GREEN}运行中${NC}"
    else
        echo -e "  状态: ${RED}未运行${NC}"
    fi
    
    # 检查是否启用
    if systemctl is-enabled --quiet mihomo-quick.service 2>/dev/null; then
        echo -e "  自启动: ${GREEN}已启用${NC}"
    else
        echo -e "  自启动: ${YELLOW}未启用${NC}"
    fi
    
    # 显示详细状态
    echo ""
    echo -e "${WHITE}详细状态:${NC}"
    echo ""
    systemctl status mihomo-quick.service --no-pager
    
    echo ""
    
    read -p "按 Enter 键返回..."
    show_service_menu
}

# 查看日志
service_logs() {
    log_info "查看服务日志..."
    
    echo ""
    echo -e "${WHITE}服务日志 (最近50行):${NC}"
    echo ""
    
    # 显示日志
    journalctl -u mihomo-quick.service -n 50 --no-pager
    
    echo ""
    echo -e "${YELLOW}提示: 使用 'journalctl -u mihomo-quick.service -f' 查看实时日志${NC}"
    echo ""
    
    read -p "按 Enter 键返回..."
    show_service_menu
}

# 服务配置
service_config() {
    log_info "服务配置..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ -f "$config_file" ]]; then
        echo ""
        echo -e "${WHITE}当前配置:${NC}"
        echo ""
        
        # 显示关键配置
        echo -e "${CYAN}基本配置:${NC}"
        grep -E "^(mixed-port|socks-port|mode):" "$config_file" || echo "  未配置"
        
        echo ""
        echo -e "${CYAN}TUN配置:${NC}"
        grep -A 5 "^tun:" "$config_file" | grep -E "^(enable|stack|device):" || echo "  未配置"
        
        echo ""
        echo -e "${CYAN}DNS配置:${NC}"
        grep -A 5 "^dns:" "$config_file" | grep -E "^(enable|enhanced-mode):" || echo "  未配置"
        
        echo ""
    else
        log_warning "配置文件不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_service_menu
}

# 创建systemd服务文件
create_service_file() {
    local service_file="/etc/systemd/system/mihomo-quick.service"
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    # 获取mihomo路径
    local mihomo_bin=$(which mihomo 2>/dev/null || echo "${HOME}/.mihomo-quick/mihomo")
    local http_port="${HTTP_PORT:-7890}"
    local socks_port="${SOCKS_PORT:-7891}"
    
    # 检测当前代理模式（检查配置中是否有启用的TUN）
    local tun_enabled="false"
    if [[ -f "$config_file" ]]; then
        local tun_block=$(sed -n '/^tun:/,/^[a-zA-Z]/p' "$config_file")
        if echo "$tun_block" | grep -q "enable: true"; then
            tun_enabled="true"
        fi
    fi
    
    # 根据模式生成服务配置
    local tun_pre="" tun_post=""
    if [[ "$tun_enabled" == "true" ]]; then
        tun_pre='# 启动前创建TUN设备（- 前缀忽略已有设备的错误）
ExecStartPre=-/sbin/ip tuntap add tun0 mode tun
ExecStartPre=-/sbin/ip addr add 10.0.0.1/24 dev tun0
ExecStartPre=-/sbin/ip link set tun0 up'
        tun_post='# 停止后清理TUN设备
ExecStopPost=/sbin/ip tuntap del tun0 mode tun'
    fi
    
    # 创建服务文件
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Mihomo Quick Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root

${tun_pre}

# 启动mihomo
ExecStart=$mihomo_bin -d $(dirname "$config_file")

${tun_post}

# 重启策略
Restart=always
RestartSec=5
TimeoutStopSec=30
TimeoutStartSec=30
SuccessExitStatus=0 143
KillMode=control-group

# 环境变量
Environment=HOME=/root
Environment=TMPDIR=/tmp
Environment=HTTP_PROXY=http://127.0.0.1:${http_port}
Environment=HTTPS_PROXY=http://127.0.0.1:${http_port}
Environment=ALL_PROXY=socks5://127.0.0.1:${socks_port}
Environment=http_proxy=http://127.0.0.1:${http_port}
Environment=https_proxy=http://127.0.0.1:${http_port}
Environment=all_proxy=socks5://127.0.0.1:${socks_port}
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd配置
    sudo systemctl daemon-reload
    
    log_info "服务文件已创建: $service_file (TUN: $tun_enabled)"
}

echo "✓ 已加载服务管理模块: service.sh"
