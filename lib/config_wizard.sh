#!/bin/bash
#
# config_wizard.sh - 配置向导模块
# 提供交互式配置向导功能
#

# ============================================================================
# 向导界面函数
# ============================================================================

# 显示欢迎界面
show_wizard_welcome() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    mihomo-quick 配置向导                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}欢迎使用 mihomo-quick 配置向导！${NC}"
    echo ""
    echo "这个向导将帮助您快速生成mihomo配置文件。"
    echo "请按照提示逐步完成配置。"
    echo ""
    echo -e "${YELLOW}提示: 可以随时按 Ctrl+C 取消${NC}"
    echo ""
    read -p "按 Enter 键开始..."
}

# 显示步骤导航
show_step() {
    local current=$1
    local total=$2
    local step_name=$3
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}步骤 $current/$total: $step_name${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# 显示输入提示
show_prompt() {
    local prompt=$1
    local default=$2
    local options=$3
    
    echo -e "${WHITE}$prompt${NC}"
    
    if [[ -n "$default" ]]; then
        echo -e "默认值: ${GREEN}$default${NC}"
    fi
    
    if [[ -n "$options" ]]; then
        echo -e "可选值: $options"
    fi
    
    echo ""
}

# 获取用户输入
get_input() {
    local prompt=$1
    local default=$2
    local validation=$3
    
    while true; do
        read -p "$prompt: " input
        
        # 使用默认值
        if [[ -z "$input" && -n "$default" ]]; then
            input="$default"
        fi
        
        # 验证输入
        if [[ -n "$validation" ]]; then
            if eval "$validation" "$input"; then
                echo "$input"
                return 0
            else
                log_error "输入无效，请重新输入"
            fi
        else
            echo "$input"
            return 0
        fi
    done
}

# 获取用户选择
get_choice() {
    local prompt=$1
    shift
    local options=("$@")
    
    echo -e "${WHITE}$prompt${NC}"
    echo ""
    
    for i in "${!options[@]}"; do
        echo -e "  ${GREEN}$((i+1))${NC}. ${options[$i]}"
    done
    
    echo ""
    
    while true; do
        read -p "请选择 (1-${#options[@]}): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le ${#options[@]} ]]; then
            echo "${options[$((choice-1))]}"
            return 0
        else
            log_error "无效选择，请重新选择"
        fi
    done
}

# ============================================================================
# 配置步骤函数
# ============================================================================

# 步骤1: 代理模式选择
step_mode_selection() {
    show_step 1 6 "代理模式选择"
    
    echo -e "${WHITE}请选择代理模式:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. TUN模式（透明代理） - 推荐"
    echo -e "  ${GREEN}2${NC}. 系统代理（HTTP/SOCKS5）"
    echo -e "  ${GREEN}3${NC}. TAP模式（二层代理）"
    echo -e "  ${GREEN}4${NC}. 混合模式"
    echo ""
    
    local mode_choice=$(get_input "请选择模式" "1" "validate_mode_choice")
    
    case $mode_choice in
        1) MODE="tun" ;;
        2) MODE="system" ;;
        3) MODE="tap" ;;
        4) MODE="mixed" ;;
        *) MODE="tun" ;;
    esac
    
    log_info "选择的模式: $MODE"
}

# 步骤2: 端口配置
step_port_config() {
    show_step 2 6 "端口配置"
    
    echo -e "${WHITE}配置代理端口:${NC}"
    echo ""
    
    HTTP_PORT=$(get_input "HTTP代理端口" "7890" "validate_port")
    SOCKS_PORT=$(get_input "SOCKS5代理端口" "7891" "validate_port")
    API_PORT=$(get_input "API控制端口" "9090" "validate_port")
    
    log_info "端口配置: HTTP=$HTTP_PORT, SOCKS=$SOCKS_PORT, API=$API_PORT"
}

# 步骤3: TUN配置
step_tun_config() {
    if [[ "$MODE" != "tun" && "$MODE" != "mixed" ]]; then
        return 0
    fi
    
    show_step 3 6 "TUN配置"
    
    echo -e "${WHITE}配置TUN参数:${NC}"
    echo ""
    
    TUN_DEVICE=$(get_input "TUN设备名" "tun0")
    TUN_GATEWAY=$(get_input "TUN网关地址" "10.0.0.1" "validate_ip")
    TUN_MTU=$(get_input "MTU大小" "9000" "validate_number")
    
    log_info "TUN配置: device=$TUN_DEVICE, gateway=$TUN_GATEWAY, mtu=$TUN_MTU"
}

# 步骤4: 订阅配置
step_subscription_config() {
    show_step 4 6 "订阅配置"
    
    echo -e "${WHITE}配置订阅源:${NC}"
    echo ""
    
    # 询问是否配置订阅
    local has_subscription=$(get_choice "是否配置订阅源?" "是" "否")
    
    if [[ "$has_subscription" == "是" ]]; then
        PROVIDER_NAME=$(get_input "订阅名称" "provider-a")
        PROVIDER_URL=$(get_input "订阅URL" "")
        PROVIDER_INTERVAL=$(get_input "更新间隔(秒)" "3600" "validate_number")
        
        if [[ -n "$PROVIDER_URL" ]]; then
            log_info "订阅配置: name=$PROVIDER_NAME, url=$PROVIDER_URL, interval=$PROVIDER_INTERVAL"
        else
            log_warning "订阅URL为空，跳过订阅配置"
            PROVIDER_NAME=""
            PROVIDER_URL=""
        fi
    else
        PROVIDER_NAME=""
        PROVIDER_URL=""
        log_info "跳过订阅配置"
    fi
}

# 步骤5: 规则配置
step_rules_config() {
    show_step 5 6 "规则配置"
    
    echo -e "${WHITE}配置规则模式:${NC}"
    echo ""
    
    local rule_mode=$(get_choice "选择规则模式" "白名单模式（只有列表中的走代理）" "黑名单模式（列表中的走直连）")
    
    if [[ "$rule_mode" == "白名单模式（只有列表中的走代理）" ]]; then
        RULE_MODE="whitelist"
    else
        RULE_MODE="blacklist"
    fi
    
    log_info "规则模式: $RULE_MODE"
}

# 步骤6: 配置预览和确认
step_preview_confirm() {
    show_step 6 6 "配置预览和确认"
    
    echo -e "${WHITE}配置摘要:${NC}"
    echo ""
    echo -e "  代理模式: ${GREEN}$MODE${NC}"
    echo -e "  HTTP端口: ${GREEN}$HTTP_PORT${NC}"
    echo -e "  SOCKS端口: ${GREEN}$SOCKS_PORT${NC}"
    echo -e "  API端口: ${GREEN}$API_PORT${NC}"
    
    if [[ "$MODE" == "tun" || "$MODE" == "mixed" ]]; then
        echo -e "  TUN设备: ${GREEN}$TUN_DEVICE${NC}"
        echo -e "  TUN网关: ${GREEN}$TUN_GATEWAY${NC}"
        echo -e "  MTU: ${GREEN}$TUN_MTU${NC}"
    fi
    
    if [[ -n "$PROVIDER_NAME" ]]; then
        echo -e "  订阅名称: ${GREEN}$PROVIDER_NAME${NC}"
        echo -e "  订阅URL: ${GREEN}$PROVIDER_URL${NC}"
    else
        echo -e "  订阅: ${YELLOW}未配置${NC}"
    fi
    
    echo -e "  规则模式: ${GREEN}$RULE_MODE${NC}"
    echo ""
    
    local confirm=$(get_choice "确认生成配置?" "确认生成" "重新配置" "取消")
    
    case $confirm in
        "确认生成") return 0 ;;
        "重新配置") return 1 ;;
        "取消") return 2 ;;
    esac
}

# ============================================================================
# 配置生成函数
# ============================================================================

# 生成配置文件
generate_wizard_config() {
    log_info "生成配置文件..."
    
    # 创建配置目录
    mkdir -p "$CONFIGS_DIR"
    
    # 备份现有配置
    if [[ -f "${CONFIGS_DIR}/config.yaml" ]]; then
        backup_file "${CONFIGS_DIR}/config.yaml"
    fi
    
    # 准备变量
    local vars=(
        "HTTP_PORT=$HTTP_PORT"
        "SOCKS_PORT=$SOCKS_PORT"
        "API_PORT=$API_PORT"
        "CONFIG_DIR=$CONFIGS_DIR"
    )
    
    # 添加TUN变量
    if [[ "$MODE" == "tun" || "$MODE" == "mixed" ]]; then
        vars+=("TUN_DEVICE=$TUN_DEVICE")
        vars+=("TUN_GATEWAY=$TUN_GATEWAY")
        vars+=("TUN_MTU=$TUN_MTU")
    fi
    
    # 调用模板系统生成配置
    if source lib/template.sh 2>/dev/null; then
        replace_template_vars "${TEMPLATES_DIR}/${MODE}.yaml.template" "${CONFIGS_DIR}/config.yaml" "${vars[@]}"
    else
        # 如果模板系统不可用，使用简单配置
        generate_simple_config
    fi
    
    # 添加订阅配置
    if [[ -n "$PROVIDER_URL" ]]; then
        add_subscription_config
    fi
    
    # 添加规则配置
    add_rules_config
    
    log_success "配置文件生成完成: ${CONFIGS_DIR}/config.yaml"
}

# 生成简单配置
generate_simple_config() {
    cat > "${CONFIGS_DIR}/config.yaml" << EOF
# mihomo-quick 生成配置
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

mixed-port: $HTTP_PORT
socks-port: $SOCKS_PORT
allow-lan: true
bind-address: '*'
mode: rule
log-level: info
external-controller: 0.0.0.0:$API_PORT

# DNS配置
dns:
  enable: true
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
  - '*.lan'
  - localhost.ptlogin2.qq.com
  default-nameserver:
  - 223.5.5.5
  - 119.29.29.29
  nameserver:
  - 223.5.5.5
  - 119.29.29.29

EOF

    # 添加TUN配置
    if [[ "$MODE" == "tun" || "$MODE" == "mixed" ]]; then
        cat >> "${CONFIGS_DIR}/config.yaml" << EOF
# TUN配置
tun:
  enable: true
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true
  device: $TUN_DEVICE
  mtu: $TUN_MTU
  strict-route: true
  gateway: $TUN_GATEWAY

EOF
    fi
}

# 添加订阅配置
add_subscription_config() {
    cat >> "${CONFIGS_DIR}/config.yaml" << EOF

# 订阅配置
proxy-providers:
  $PROVIDER_NAME:
    type: http
    url: "$PROVIDER_URL"
    interval: $PROVIDER_INTERVAL
    health-check:
      enable: true
      interval: 300
      url: http://cp.cloudflare.com/generate_204

proxy-groups:
  - name: "🎯 全球直连"
    type: select
    proxies:
      - DIRECT
      
  - name: "🚀 节点选择"
    type: select
    proxies:
      - 🎯 全球直连
      - $PROVIDER_NAME
      
  - name: "♻️ 自动选择"
    type: url-test
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    proxies:
      - $PROVIDER_NAME

EOF
}

# 添加规则配置
add_rules_config() {
    if [[ "$RULE_MODE" == "whitelist" ]]; then
        cat >> "${CONFIGS_DIR}/config.yaml" << EOF
# 规则配置（白名单模式）
rules:
  # 国外网站走代理
  - DOMAIN-SUFFIX,google.com,🚀 节点选择
  - DOMAIN-SUFFIX,youtube.com,🚀 节点选择
  - DOMAIN-SUFFIX,github.com,🚀 节点选择
  
  # 国内网站直连
  - GEOIP,CN,🎯 全球直连
  - DOMAIN-SUFFIX,baidu.com,🎯 全球直连
  - DOMAIN-SUFFIX,qq.com,🎯 全球直连
  
  # 默认规则
  - MATCH,🎯 全球直连
EOF
    else
        cat >> "${CONFIGS_DIR}/config.yaml" << EOF
# 规则配置（黑名单模式）
rules:
  # 黑名单（这些走直连）
  - DOMAIN-SUFFIX,baidu.com,🎯 全球直连
  - DOMAIN-SUFFIX,qq.com,🎯 全球直连
  - DOMAIN-SUFFIX,taobao.com,🎯 全球直连
  - GEOIP,CN,🎯 全球直连
  
  # 其他走代理
  - MATCH,🚀 节点选择
EOF
    fi
}

# ============================================================================
# 验证函数
# ============================================================================

# 验证模式选择
validate_mode_choice() {
    local input=$1
    [[ "$input" =~ ^[1-4]$ ]]
}

# 验证端口
validate_port() {
    local input=$1
    [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge 1 && "$input" -le 65535 ]]
}

# 验证IP地址
validate_ip() {
    local input=$1
    [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# 验证数字
validate_number() {
    local input=$1
    [[ "$input" =~ ^[0-9]+$ ]]
}

# ============================================================================
# 主向导函数
# ============================================================================

# 启动配置向导
start_config_wizard() {
    log_info "启动配置向导..."
    
    # 显示欢迎界面
    show_wizard_welcome
    
    while true; do
        # 执行配置步骤
        step_mode_selection
        step_port_config
        step_tun_config
        step_subscription_config
        step_rules_config
        
        # 预览和确认
        if step_preview_confirm; then
            # 生成配置
            generate_wizard_config
            
            echo ""
            echo -e "${GREEN}配置生成完成！${NC}"
            echo ""
            echo -e "配置文件: ${CONFIGS_DIR}/config.yaml"
            echo ""
            echo -e "${YELLOW}提示: 请根据实际情况修改配置文件中的订阅URL和规则${NC}"
            echo ""
            
            read -p "按 Enter 键返回主菜单..."
            return 0
        else
            local action=$?
            if [[ $action -eq 2 ]]; then
                log_info "取消配置向导"
                return 1
            fi
            # 重新配置，继续循环
        fi
    done
}

# ============================================================================
# 快捷命令
# ============================================================================

# 快捷配置向导
config_wizard() {
    start_config_wizard
}

echo "✓ 已加载配置向导模块: config_wizard.sh"
