#!/bin/bash
#
# template.sh - 模板处理模块
# 提供模板变量替换和模板生成功能
#

# ============================================================================
# 模板变量替换函数
# ============================================================================

# 默认变量值
declare -A DEFAULT_VARS=(
    # 基本配置
    ["HTTP_PORT"]="7890"
    ["SOCKS_PORT"]="7891"
    ["ALLOW_LAN"]="true"
    ["BIND_ADDRESS"]="*"
    ["MODE"]="rule"
    ["LOG_LEVEL"]="info"
    ["API_ADDRESS"]="0.0.0.0"
    ["API_PORT"]="9090"
    ["API_SECRET"]=""
    ["CONFIG_DIR"]="$CONFIGS_DIR"
    ["IPV6_ENABLED"]="false"
    
    # DNS配置
    ["DNS_ENABLED"]="true"
    ["DNS_IPV6"]="false"
    ["DNS_MODE"]="fake-ip"
    ["FAKE_IP_RANGE"]="198.18.0.1/16"
    ["FAKE_IP_FILTER"]="  - '*.lan'
  - localhost.ptlogin2.qq.com"
    ["DEFAULT_DNS"]="  - 223.5.5.5
  - 119.29.29.29"
    ["NAMESERVER"]="  - 223.5.5.5
  - 119.29.29.29
  - tls://dns.alidns.com
  - tls://dot.pub"
    ["FALLBACK_DNS"]="  - https://1.1.1.1/dns-query
  - https://8.8.8.8/dns-query
  - tls://8.8.4.4"
    ["FALLBACK_GEOIP"]="true"
    ["FALLBACK_GEOIP_CODE"]="CN"
    ["FALLBACK_IPCIDR"]="    - 240.0.0.0/4"
    
    # TUN配置
    ["TUN_STACK"]="system"
    ["TUN_AUTO_ROUTE"]="true"
    ["TUN_AUTO_DETECT"]="true"
    ["TUN_DEVICE"]="tun0"
    ["TUN_MTU"]="9000"
    ["TUN_STRICT_ROUTE"]="true"
    ["TUN_GATEWAY"]="10.0.0.1"
    ["TUN_ROUTE_TABLE"]="100"
    ["TUN_ROUTE_RULE"]="9000"
    ["TUN_GSO"]="true"
    ["TUN_CHECKSUM"]="true"
    
    # 其他配置
    ["CLIENT_FINGERPRINT"]="chrome"
    ["SNIFFING_ENABLED"]="true"
    ["SNIFFING_PORTS"]="  - 80
  - 443"
    ["SNIFFING_OVERRIDE"]="true"
    ["QUIC_DISABLE_GSO"]="true"
    ["QUIC_DISABLE_ECN"]="true"
    
    # 代理组配置
    ["CHINA_PROXY_GROUP"]="🎯 全球直连"
    ["DEFAULT_PROXY_GROUP"]="🚀 节点选择"
    ["USER_RULES"]=""
    ["AD_BLOCKING_RULES"]="  - DOMAIN-SUFFIX,ads.google.com,REJECT
  - DOMAIN-SUFFIX,ads.youtube.com,REJECT"
    
    # 订阅配置
    ["PROVIDER_NAME"]="provider-a"
    ["PROVIDER_URL"]=""
    ["PROVIDER_INTERVAL"]="3600"
    ["HEALTH_CHECK_INTERVAL"]="300"
    ["HEALTH_CHECK_URL"]="http://cp.cloudflare.com/generate_204"
    ["SKIP_CERT_VERIFY"]="true"
    ["PROVIDER_FILTER"]=""
    ["PROVIDER_EXCLUDE"]=""
    ["TOLERANCE"]="50"
)

# ============================================================================
# 模板处理函数
# ============================================================================

# 替换模板变量
replace_template_vars() {
    local template_file=$1
    local output_file=$2
    shift 2
    local vars=("$@")
    
    if [[ ! -f "$template_file" ]]; then
        log_error "模板文件不存在: $template_file"
        return 1
    fi
    
    # 复制模板到输出文件
    cp "$template_file" "$output_file"
    
    # 创建变量数组
    declare -A var_dict
    
    # 首先加载默认变量
    for key in "${!DEFAULT_VARS[@]}"; do
        var_dict["$key"]="${DEFAULT_VARS[$key]}"
    done
    
    # 然后加载用户提供的变量
    for var in "${vars[@]}"; do
        if [[ "$var" == *"="* ]]; then
            local key=$(echo "$var" | cut -d'=' -f1)
            local value=$(echo "$var" | cut -d'=' -f2-)
            var_dict["$key"]="$value"
        fi
    done
    
    # 替换变量
    for key in "${!var_dict[@]}"; do
        local value="${var_dict[$key]}"
        # 使用sed进行替换，处理多行值
        if [[ "$value" == *$'\n'* ]]; then
            # 多行值，使用临时文件
            local temp_file=$(mktemp)
            echo "$value" > "$temp_file"
            sed -i "/{{${key}}}/ {
                r $temp_file
                d
            }" "$output_file"
            rm -f "$temp_file"
        else
            # 单行值，直接替换（使用 | 作为分隔符避免 URL 中的 / 冲突）
            sed -i "s|{{${key}}}|${value}|g" "$output_file"
        fi
    done
    
    log_success "模板变量替换完成: $output_file"
    return 0
}

# 生成配置文件
generate_config() {
    local mode=$1
    local output_file="${CONFIGS_DIR}/config.yaml"
    
    log_info "生成配置文件: $mode 模式"
    
    # 选择模板
    local template_file
    case $mode in
        tun)
            template_file="${TEMPLATES_DIR}/tun.yaml.template"
            ;;
        system)
            template_file="${TEMPLATES_DIR}/system.yaml.template"
            ;;
        tap)
            template_file="${TEMPLATES_DIR}/tap.yaml.template"
            ;;
        mixed)
            template_file="${TEMPLATES_DIR}/mixed.yaml.template"
            ;;
        *)
            template_file="${TEMPLATES_DIR}/base.yaml.template"
            ;;
    esac
    
    # 检查模板文件
    if [[ ! -f "$template_file" ]]; then
        log_error "模板文件不存在: $template_file"
        return 1
    fi
    
    # 创建配置目录
    mkdir -p "$CONFIGS_DIR"
    
    # 收集变量
    local vars=()
    
    # 基本变量
    vars+=("HTTP_PORT=${HTTP_PORT:-7890}")
    vars+=("SOCKS_PORT=${SOCKS_PORT:-7891}")
    vars+=("CONFIG_DIR=${CONFIGS_DIR}")
    
    # TUN变量
    if [[ "$mode" == "tun" || "$mode" == "mixed" ]]; then
        vars+=("TUN_DEVICE=${TUN_DEVICE:-tun0}")
        vars+=("TUN_GATEWAY=${TUN_GATEWAY:-10.0.0.1}")
    fi
    
    # 生成配置
    replace_template_vars "$template_file" "$output_file" "${vars[@]}"
    
    # 添加订阅配置
    if [[ -n "${PROVIDER_URL:-}" ]]; then
        add_subscription_to_config "$output_file"
    fi
    
    # 添加规则配置
    add_rules_to_config "$output_file"
    
    log_success "配置文件生成完成: $output_file"
    return 0
}

# 添加订阅配置到配置文件（参照 mihomo-proxy-export 的完整架构）
add_subscription_to_config() {
    local config_file=$1
    
    log_info "添加订阅配置..."
    
    cat >> "$config_file" << EOF

# 订阅配置
proxy-providers:
  ${PROVIDER_NAME:-provider-a}:
    type: http
    url: "${PROVIDER_URL}"
    interval: ${PROVIDER_INTERVAL:-3600}
    header:
      User-Agent:
        - "clash-verge/v2.2.3"
    health-check:
      enable: true
      interval: 600
      url: ${HEALTH_CHECK_URL:-http://cp.cloudflare.com/generate_204}
    override:
      skip-cert-verify: ${SKIP_CERT_VERIFY:-true}

# 代理组配置（url-test + fallback + select 三层架构）
proxy-groups:
  - name: "🚀 节点选择"
    type: url-test
    use:
      - ${PROVIDER_NAME:-provider-a}
    url: ${HEALTH_CHECK_URL:-http://cp.cloudflare.com/generate_204}
    interval: 300
    tolerance: 200
    lazy: true

  - name: "🔄 智能切换"
    type: fallback
    proxies:
      - "🚀 节点选择"
    url: ${HEALTH_CHECK_URL:-http://cp.cloudflare.com/generate_204}
    interval: 300
    lazy: true

  - name: "📱 手动选择"
    type: select
    use:
      - ${PROVIDER_NAME:-provider-a}
    proxies:
      - "🔄 智能切换"
      - "🚀 节点选择"
      - DIRECT
EOF
    
    log_success "订阅配置已添加"
}

# 添加规则配置到配置文件（参照 mihomo-proxy-export 的完整规则架构）
add_rules_to_config() {
    local config_file=$1
    local rule_mode=${2:-"whitelist"}
    
    log_info "添加规则配置..."
    
    cat >> "$config_file" << EOF

# 规则配置
rules:
  # 大模型API直连（不走代理）
  - DOMAIN-SUFFIX,anthropic.com,DIRECT
  - DOMAIN-SUFFIX,bigmodel.cn,DIRECT
  - DOMAIN-SUFFIX,dataeyes.ai,DIRECT
  - DOMAIN-SUFFIX,openai.com,DIRECT
  - DOMAIN-SUFFIX,openrouter.ai,DIRECT
  - DOMAIN-SUFFIX,volcengine.com,DIRECT
  - DOMAIN-SUFFIX,volces.com,DIRECT
  - DOMAIN-SUFFIX,xiaomimimo.com,DIRECT

  # Google API走代理（Gemini等需要代理）
  - DOMAIN-SUFFIX,googleapis.com,🔄 智能切换

  # 本地网络直连
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT

  # 中国IP直连
  - GEOIP,CN,DIRECT

  # 默认规则
  - MATCH,🔄 智能切换
EOF
    
    log_success "规则配置已添加"
}

# ============================================================================
# 模板验证函数
# ============================================================================

# 验证模板
validate_template() {
    local template_file=$1
    
    log_info "验证模板: $template_file"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "模板文件不存在: $template_file"
        return 1
    fi
    
    # 检查模板语法
    if ! grep -q "{{" "$template_file"; then
        log_warning "模板中没有变量"
    fi
    
    # 提取模板变量
    local vars=$(grep -o "{{[^}]*}}" "$template_file" | sort | uniq)
    
    echo ""
    echo -e "${WHITE}模板变量:${NC}"
    for var in $vars; do
        local var_name=$(echo "$var" | sed 's/{{//g' | sed 's/}}//g')
        if [[ -n "${DEFAULT_VARS[$var_name]}" ]]; then
            echo -e "  ${GREEN}✓${NC} $var_name: ${DEFAULT_VARS[$var_name]}"
        else
            echo -e "  ${YELLOW}⚠${NC} $var_name: 未定义默认值"
        fi
    done
    
    echo ""
    
    log_success "模板验证完成"
    return 0
}

# 列出所有模板
list_templates() {
    log_info "列出所有模板..."
    
    echo ""
    echo -e "${WHITE}可用模板:${NC}"
    
    for template in "${TEMPLATES_DIR}"/*.template; do
        if [[ -f "$template" ]]; then
            local name=$(basename "$template" .template)
            local size=$(du -h "$template" | cut -f1)
            echo -e "  ${GREEN}✓${NC} $name ($size)"
        fi
    done
    
    echo ""
}

echo "✓ 已加载模板处理模块: template.sh"
