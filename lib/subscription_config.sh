#!/bin/bash
#
# subscription_config.sh - 订阅配置生成模块
# 生成mihomo的proxy-providers配置，让内核自己处理订阅
#

# ============================================================================
# 订阅配置生成
# ============================================================================

# 生成proxy-providers配置
generate_proxy_providers() {
    local provider_name=$1
    local provider_url=$2
    local provider_interval=${3:-3600}
    local health_check_url=${4:-"http://cp.cloudflare.com/generate_204"}
    local health_check_interval=${5:-600}
    
    cat << EOF
  $provider_name:
    type: http
    url: "$provider_url"
    interval: $provider_interval
    header:
      User-Agent:
        - "clash-verge/v2.2.3"
    health-check:
      enable: true
      interval: $health_check_interval
      url: $health_check_url
    override:
      skip-cert-verify: true
EOF
}

# 生成proxy-groups配置（使用订阅）
generate_proxy_groups_with_provider() {
    local provider_name=$1
    
    cat << EOF
proxy-groups:
  - name: "🎯 全球直连"
    type: select
    proxies:
      - DIRECT
      
  - name: "🚀 节点选择"
    type: select
    use:
      - $provider_name
      
  - name: "♻️ 自动选择"
    type: url-test
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    use:
      - $provider_name
      
  - name: "🔯 故障转移"
    type: fallback
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    use:
      - $provider_name
EOF
}

# 生成完整配置（包含订阅）
generate_config_with_subscription() {
    local mode=$1
    local http_port=$2
    local socks_port=$3
    local provider_name=$4
    local provider_url=$5
    local provider_interval=${6:-3600}
    local output_file=$7
    
    log_info "生成包含订阅的配置..."
    
    # 读取模板
    local template_file="${TEMPLATES_DIR}/${mode}.yaml.template"
    if [[ ! -f "$template_file" ]]; then
        template_file="${TEMPLATES_DIR}/base.yaml.template"
    fi
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 复制模板并替换变量
    sed -e "s/{{HTTP_PORT}}/$http_port/g" \
        -e "s/{{SOCKS_PORT}}/$socks_port/g" \
        -e "s/{{CONFIG_DIR}}/$CONFIGS_DIR/g" \
        -e "s/{{TUN_DEVICE}}/tun0/g" \
        -e "s/{{TUN_GATEWAY}}/10.0.0.1/g" \
        "$template_file" > "$temp_file"
    
    # 添加proxy-providers配置
    echo "" >> "$temp_file"
    echo "# 订阅配置" >> "$temp_file"
    echo "proxy-providers:" >> "$temp_file"
    generate_proxy_providers "$provider_name" "$provider_url" "$provider_interval" >> "$temp_file"
    
    # 添加proxy-groups配置
    echo "" >> "$temp_file"
    generate_proxy_groups_with_provider "$provider_name" >> "$temp_file"
    
    # 添加规则配置
    echo "" >> "$temp_file"
    echo "# 规则配置" >> "$temp_file"
    echo "rules:" >> "$temp_file"
    echo "  # 本地网络" >> "$temp_file"
    echo "  - DOMAIN-SUFFIX,local,DIRECT" >> "$temp_file"
    echo "  - DOMAIN-SUFFIX,localhost,DIRECT" >> "$temp_file"
    echo "  - IP-CIDR,127.0.0.0/8,DIRECT" >> "$temp_file"
    echo "  - IP-CIDR,172.16.0.0/12,DIRECT" >> "$temp_file"
    echo "  - IP-CIDR,192.168.0.0/16,DIRECT" >> "$temp_file"
    echo "  - IP-CIDR,10.0.0.0/8,DIRECT" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "  # 中国IP" >> "$temp_file"
    echo "  - GEOIP,CN,🎯 全球直连" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "  # 广告拦截" >> "$temp_file"
    echo "  - DOMAIN-SUFFIX,ads.google.com,REJECT" >> "$temp_file"
    echo "  - DOMAIN-SUFFIX,ads.youtube.com,REJECT" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "  # 默认规则" >> "$temp_file"
    echo "  - MATCH,🚀 节点选择" >> "$temp_file"
    
    # 复制到输出文件
    mv "$temp_file" "$output_file"
    
    log_success "配置生成完成: $output_file"
}

# ============================================================================
# 订阅配置向导
# ============================================================================

# 订阅配置向导
subscription_config_wizard() {
    log_info "订阅配置向导..."
    
    echo ""
    echo -e "${WHITE}订阅配置向导${NC}"
    echo ""
    
    # 获取订阅名称
    read -p "订阅名称 [provider-a]: " provider_name
    provider_name=${provider_name:-provider-a}
    
    # 获取订阅URL
    read -p "订阅URL: " provider_url
    if [[ -z "$provider_url" ]]; then
        log_error "订阅URL不能为空"
        return 1
    fi
    
    # 获取更新间隔
    read -p "更新间隔(秒) [3600]: " provider_interval
    provider_interval=${provider_interval:-3600}
    
    # 获取代理模式
    echo ""
    echo "选择代理模式:"
    echo "1. TUN模式（透明代理）"
    echo "2. 系统代理（HTTP/SOCKS5）"
    echo "3. 混合模式"
    read -p "请选择 [1-3]: " mode_choice
    
    case $mode_choice in
        1) mode="tun" ;;
        2) mode="system" ;;
        3) mode="mixed" ;;
        *) mode="tun" ;;
    esac
    
    # 获取端口
    read -p "HTTP端口 [7890]: " http_port
    http_port=${http_port:-7890}
    
    read -p "SOCKS端口 [7891]: " socks_port
    socks_port=${socks_port:-7891}
    
    # 生成配置
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    # 备份现有配置
    if [[ -f "$config_file" ]]; then
        backup_file "$config_file"
    fi
    
    # 生成新配置
    generate_config_with_subscription "$mode" "$http_port" "$socks_port" "$provider_name" "$provider_url" "$provider_interval" "$config_file"
    
    echo ""
    echo -e "${GREEN}订阅配置生成完成！${NC}"
    echo ""
    echo "配置信息:"
    echo "  订阅名称: $provider_name"
    echo "  订阅URL: $provider_url"
    echo "  更新间隔: ${provider_interval}秒"
    echo "  代理模式: $mode"
    echo "  HTTP端口: $http_port"
    echo "  SOCKS端口: $socks_port"
    echo "  配置文件: $config_file"
    echo ""
    echo -e "${YELLOW}提示: mihomo内核会自动下载和解析订阅${NC}"
    echo ""
}

# ============================================================================
# 测试订阅配置
# ============================================================================

# 测试订阅配置
test_subscription_config() {
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    log_info "测试订阅配置..."
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}订阅配置测试:${NC}"
    echo ""
    
    # 检查proxy-providers配置
    if grep -q "proxy-providers:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} proxy-providers配置存在"
        
        # 提取订阅信息
        local providers=$(grep -A 10 "proxy-providers:" "$config_file" | grep "url:" | sed 's/.*url: "//' | sed 's/".*//')
        
        if [[ -n "$providers" ]]; then
            echo "  订阅列表:"
            echo "$providers" | while read url; do
                echo "    - $url"
            done
        else
            echo -e "  ${YELLOW}⚠${NC} 未找到订阅URL"
        fi
    else
        echo -e "  ${RED}✗${NC} proxy-providers配置不存在"
    fi
    
    # 检查proxy-groups配置
    if grep -q "proxy-groups:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} proxy-groups配置存在"
        
        # 提取代理组信息
        local groups=$(grep -A 5 "proxy-groups:" "$config_file" | grep "name:" | sed 's/.*name: "//' | sed 's/".*//')
        
        if [[ -n "$groups" ]]; then
            echo "  代理组:"
            echo "$groups" | while read group; do
                echo "    - $group"
            done
        fi
    else
        echo -e "  ${RED}✗${NC} proxy-groups配置不存在"
    fi
    
    # 检查规则配置
    if grep -q "rules:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} rules配置存在"
        
        # 统计规则数量
        local rule_count=$(grep -c "^  - " "$config_file" 2>/dev/null || echo "0")
        echo "  规则数量: $rule_count"
    else
        echo -e "  ${YELLOW}⚠${NC} rules配置不存在"
    fi
    
    echo ""
    
    log_success "订阅配置测试完成"
}

# ============================================================================
# 主函数
# ============================================================================

# 订阅配置主菜单
subscription_config_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                      订阅配置管理                           ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        echo -e "${WHITE}请选择操作:${NC}"
        echo ""
        echo -e "  ${GREEN}1${NC}. 订阅配置向导"
        echo -e "  ${GREEN}2${NC}. 测试订阅配置"
        echo -e "  ${GREEN}3${NC}. 查看当前配置"
        echo -e "  ${GREEN}0${NC}. 返回主菜单"
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        
        read -p "请输入选择 (0-3): " choice
        
        case $choice in
            1) subscription_config_wizard ;;
            2) test_subscription_config ;;
            3) 
                if [[ -f "${CONFIGS_DIR}/config.yaml" ]]; then
                    echo ""
                    echo -e "${WHITE}当前配置:${NC}"
                    echo ""
                    cat "${CONFIGS_DIR}/config.yaml"
                    echo ""
                else
                    log_warning "配置文件不存在"
                fi
                read -p "按 Enter 键返回..."
                ;;
            0) return ;;
            *) log_error "无效选择"; sleep 1 ;;
        esac
    done
}

echo "✓ 已加载订阅配置生成模块: subscription_config.sh"
