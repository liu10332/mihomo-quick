#!/bin/bash
#
# config_validate.sh - 配置验证模块
# 提供配置文件验证和修复功能
#

# ============================================================================
# 配置验证函数
# ============================================================================

# 验证YAML语法
validate_yaml_syntax() {
    local config_file=$1
    
    log_info "验证YAML语法: $config_file"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 检查文件是否为空
    if [[ ! -s "$config_file" ]]; then
        log_error "配置文件为空"
        return 1
    fi
    
    # 使用python验证YAML语法
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
            log_success "YAML语法正确"
            return 0
        else
            log_error "YAML语法错误"
            return 1
        fi
    else
        # 简单验证
        if grep -q ":" "$config_file"; then
            log_success "配置文件格式基本正确"
            return 0
        else
            log_error "配置文件格式错误"
            return 1
        fi
    fi
}

# 验证端口配置
validate_ports() {
    local config_file=$1
    
    log_info "验证端口配置..."
    
    echo ""
    echo -e "${WHITE}端口配置验证:${NC}"
    
    # 检查HTTP端口
    local http_port=$(grep "^mixed-port:" "$config_file" | awk '{print $2}')
    if [[ -n "$http_port" ]]; then
        if [[ "$http_port" =~ ^[0-9]+$ ]] && [[ "$http_port" -ge 1 && "$http_port" -le 65535 ]]; then
            echo -e "  ${GREEN}✓${NC} HTTP端口: $http_port"
        else
            echo -e "  ${RED}✗${NC} HTTP端口无效: $http_port"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} HTTP端口未配置"
    fi
    
    # 检查SOCKS端口
    local socks_port=$(grep "^socks-port:" "$config_file" | awk '{print $2}')
    if [[ -n "$socks_port" ]]; then
        if [[ "$socks_port" =~ ^[0-9]+$ ]] && [[ "$socks_port" -ge 1 && "$socks_port" -le 65535 ]]; then
            echo -e "  ${GREEN}✓${NC} SOCKS端口: $socks_port"
        else
            echo -e "  ${RED}✗${NC} SOCKS端口无效: $socks_port"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} SOCKS端口未配置"
    fi
    
    # 检查API端口
    local api_port=$(grep "external-controller:" "$config_file" | awk -F: '{print $3}')
    if [[ -n "$api_port" ]]; then
        if [[ "$api_port" =~ ^[0-9]+$ ]] && [[ "$api_port" -ge 1 && "$api_port" -le 65535 ]]; then
            echo -e "  ${GREEN}✓${NC} API端口: $api_port"
        else
            echo -e "  ${RED}✗${NC} API端口无效: $api_port"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} API端口未配置"
    fi
    
    echo ""
}

# 验证TUN配置
validate_tun_config() {
    local config_file=$1
    
    log_info "验证TUN配置..."
    
    echo ""
    echo -e "${WHITE}TUN配置验证:${NC}"
    
    # 检查TUN是否启用
    local tun_enabled=$(grep -A 1 "^tun:" "$config_file" | grep "enable:" | awk '{print $2}')
    if [[ "$tun_enabled" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} TUN已启用"
        
        # 检查TUN设备
        local tun_device=$(grep -A 5 "^tun:" "$config_file" | grep "device:" | awk '{print $2}')
        if [[ -n "$tun_device" ]]; then
            echo -e "  ${GREEN}✓${NC} TUN设备: $tun_device"
        else
            echo -e "  ${YELLOW}⚠${NC} TUN设备未配置"
        fi
        
        # 检查TUN网关
        local tun_gateway=$(grep -A 5 "^tun:" "$config_file" | grep "gateway:" | awk '{print $2}')
        if [[ -n "$tun_gateway" ]]; then
            if [[ "$tun_gateway" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "  ${GREEN}✓${NC} TUN网关: $tun_gateway"
            else
                echo -e "  ${RED}✗${NC} TUN网关格式错误: $tun_gateway"
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} TUN网关未配置"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} TUN未启用"
    fi
    
    echo ""
}

# 验证DNS配置
validate_dns_config() {
    local config_file=$1
    
    log_info "验证DNS配置..."
    
    echo ""
    echo -e "${WHITE}DNS配置验证:${NC}"
    
    # 检查DNS是否启用
    local dns_enabled=$(grep -A 1 "^dns:" "$config_file" | grep "enable:" | awk '{print $2}')
    if [[ "$dns_enabled" == "true" ]]; then
        echo -e "  ${GREEN}✓${NC} DNS已启用"
        
        # 检查DNS模式
        local dns_mode=$(grep -A 5 "^dns:" "$config_file" | grep "enhanced-mode:" | awk '{print $2}')
        if [[ -n "$dns_mode" ]]; then
            echo -e "  ${GREEN}✓${NC} DNS模式: $dns_mode"
        else
            echo -e "  ${YELLOW}⚠${NC} DNS模式未配置"
        fi
        
        # 检查DNS服务器
        local dns_servers=$(grep -A 10 "^dns:" "$config_file" | grep "nameserver:" | head -1)
        if [[ -n "$dns_servers" ]]; then
            echo -e "  ${GREEN}✓${NC} DNS服务器已配置"
        else
            echo -e "  ${YELLOW}⚠${NC} DNS服务器未配置"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} DNS未启用"
    fi
    
    echo ""
}

# 验证订阅配置
validate_subscription_config() {
    local config_file=$1
    
    log_info "验证订阅配置..."
    
    echo ""
    echo -e "${WHITE}订阅配置验证:${NC}"
    
    # 检查是否有订阅配置
    if grep -q "proxy-providers:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} 订阅配置存在"
        
        # 统计订阅数量
        local sub_count=$(grep -c "^[a-zA-Z0-9_-]*:" "$config_file" | head -1)
        if [[ -n "$sub_count" && "$sub_count" -gt 0 ]]; then
            echo -e "  ${GREEN}✓${NC} 订阅数量: $sub_count"
        else
            echo -e "  ${YELLOW}⚠${NC} 订阅数量: 0"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} 订阅配置不存在"
    fi
    
    echo ""
}

# 验证规则配置
validate_rules_config() {
    local config_file=$1
    
    log_info "验证规则配置..."
    
    echo ""
    echo -e "${WHITE}规则配置验证:${NC}"
    
    # 检查是否有规则配置
    if grep -q "rules:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} 规则配置存在"
        
        # 统计规则数量
        local rule_count=$(grep -c "^  - " "$config_file")
        if [[ -n "$rule_count" && "$rule_count" -gt 0 ]]; then
            echo -e "  ${GREEN}✓${NC} 规则数量: $rule_count"
        else
            echo -e "  ${YELLOW}⚠${NC} 规则数量: 0"
        fi
        
        # 检查是否有默认规则
        if grep -q "MATCH" "$config_file"; then
            echo -e "  ${GREEN}✓${NC} 默认规则存在"
        else
            echo -e "  ${YELLOW}⚠${NC} 默认规则不存在"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} 规则配置不存在"
    fi
    
    echo ""
}

# 综合配置验证
validate_config() {
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    log_info "执行配置验证..."
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        log_info "请先运行配置向导: ./mihomo-quick.sh config"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}配置验证报告${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    validate_yaml_syntax "$config_file"
    validate_ports "$config_file"
    validate_tun_config "$config_file"
    validate_dns_config "$config_file"
    validate_subscription_config "$config_file"
    validate_rules_config "$config_file"
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    log_success "配置验证完成"
}

# ============================================================================
# 配置修复函数
# ============================================================================

# 修复配置问题
fix_config_issues() {
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    log_info "修复配置问题..."
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}配置修复:${NC}"
    
    # 备份配置文件
    backup_file "$config_file"
    
    # 修复端口配置
    if ! grep -q "^mixed-port:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} 添加HTTP端口配置"
        sed -i '1i mixed-port: 7890' "$config_file"
    fi
    
    if ! grep -q "^socks-port:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} 添加SOCKS端口配置"
        sed -i '2i socks-port: 7891' "$config_file"
    fi
    
    # 修复模式配置
    if ! grep -q "^mode:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} 添加运行模式配置"
        sed -i '3i mode: rule' "$config_file"
    fi
    
    # 修复日志配置
    if ! grep -q "^log-level:" "$config_file"; then
        echo -e "  ${GREEN}✓${NC} 添加日志级别配置"
        sed -i '4i log-level: info' "$config_file"
    fi
    
    echo ""
    log_success "配置修复完成"
}

# 生成配置报告
generate_config_report() {
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    log_info "生成配置报告..."
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}配置报告:${NC}"
    echo ""
    echo "配置文件: $config_file"
    echo "文件大小: $(du -h "$config_file" | cut -f1)"
    echo "修改时间: $(stat -c %y "$config_file" 2>/dev/null || stat -f %Sm "$config_file" 2>/dev/null)"
    echo ""
    
    # 统计配置项
    echo -e "${CYAN}配置统计:${NC}"
    echo "  配置行数: $(wc -l < "$config_file")"
    echo "  注释行数: $(grep -c "^#" "$config_file")"
    echo "  空行行数: $(grep -c "^$" "$config_file")"
    echo "  有效行数: $(grep -cv "^#\|^$" "$config_file")"
    echo ""
}

echo "✓ 已加载配置验证模块: config_validate.sh"
