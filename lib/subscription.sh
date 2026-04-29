#!/bin/bash
#
# subscription.sh - 订阅管理模块
# 提供订阅添加、更新、测试等功能
#

# 显示订阅管理菜单
show_subscription_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      订阅管理                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. 添加订阅"
    echo -e "  ${GREEN}2${NC}. 查看订阅列表"
    echo -e "  ${GREEN}3${NC}. 更新订阅"
    echo -e "  ${GREEN}4${NC}. 测试节点"
    echo -e "  ${GREEN}5${NC}. 删除订阅"
    echo -e "  ${GREEN}6${NC}. 订阅状态"
    echo -e "  ${GREEN}0${NC}. 返回主菜单"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    read -p "请输入选择 (0-6): " choice
    
    case $choice in
        1) subscription_add ;;
        2) subscription_list ;;
        3) subscription_update ;;
        4) subscription_test ;;
        5) subscription_delete ;;
        6) subscription_status ;;
        0) return ;;
        *) log_error "无效选择"; sleep 1; show_subscription_menu ;;
    esac
}

# 添加订阅（增强版：支持代理链、skip-cert-verify、完整代理组）
subscription_add() {
    log_info "添加订阅..."
    
    echo ""
    read -p "订阅URL: " sub_url
    if [[ -z "$sub_url" ]]; then
        log_error "订阅URL不能为空"
        read -p "按 Enter 键返回..."
        show_subscription_menu
        return 1
    fi
    
    read -p "订阅名称 [provider-a]: " sub_name
    sub_name=${sub_name:-provider-a}
    
    read -p "更新间隔(秒) [3600]: " interval
    interval=${interval:-3600}
    
    # 询问是否需要通过其他代理下载（代理链）
    echo ""
    echo "是否需要通过已有代理下载此订阅？（代理链）"
    echo "  1. 直接下载"
    echo "  2. 通过代理下载（适用于订阅站被墙的情况）"
    read -p "请选择 [1-2]: " proxy_choice
    
    local proxy_line=""
    local proxy_group_ref=""
    
    if [[ "$proxy_choice" == "2" ]]; then
        # 检测当前可用的代理组
        local config_file="${CONFIGS_DIR}/config.yaml"
        if [[ -f "$config_file" ]]; then
            local existing_groups=$(grep -E "^  - name:" "$config_file" 2>/dev/null | head -5 | sed 's/.*name: "//' | sed 's/".*//')
            if [[ -n "$existing_groups" ]]; then
                echo ""
                echo "可用的代理组:"
                echo "$existing_groups" | while read g; do echo "  - $g"; done
                echo ""
                read -p "选择代理组名称（用于下载订阅）: " proxy_group_ref
            fi
        fi
        
        if [[ -z "$proxy_group_ref" ]]; then
            # 回退到直接使用代理端口
            if curl -s --connect-timeout 2 --proxy http://127.0.0.1:7890 http://cp.cloudflare.com/generate_204 > /dev/null 2>&1; then
                proxy_line='    proxy: "http://127.0.0.1:7890"'
                log_info "使用本地代理下载订阅"
            else
                log_warning "代理不可用，将直接下载"
            fi
        else
            proxy_line="    proxy: \"$proxy_group_ref\""
            log_info "使用代理组 [$proxy_group_ref] 下载订阅"
        fi
    fi
    
    # 检测代理是否可用（用于下载验证）
    local curl_opts=()
    if curl -s --connect-timeout 2 --proxy http://127.0.0.1:7890 http://cp.cloudflare.com/generate_204 > /dev/null 2>&1; then
        curl_opts=(--proxy http://127.0.0.1:7890)
        log_info "使用代理下载订阅"
    fi
    
    # 订阅解析完全交给 mihomo 内核，这里只做配置写入
    log_info "添加订阅配置（mihomo 内核将自动下载和解析）..."

    # 添加到配置
    local config_file="${CONFIGS_DIR}/config.yaml"
    mkdir -p "${CONFIGS_DIR}/providers"

    if [[ -f "$config_file" ]]; then
        # 检查是否已有proxy-providers部分
        if grep -q "proxy-providers:" "$config_file"; then
            # 检查是否已存在同名订阅
            if grep -q "  ${sub_name}:" "$config_file"; then
                log_warning "订阅 [$sub_name] 已存在，将更新配置"
                # 删除旧配置
                sed -i "/  ${sub_name}:/,/^  [a-zA-Z]/d" "$config_file"
            fi

            # 在proxy-providers部分添加（参照 mihomo-proxy-export 格式）
            local provider_block="  ${sub_name}:
    type: http
    url: \"${sub_url}\"
    interval: ${interval}
    path: ./providers/${sub_name}.yaml
    health-check:
      enable: true
      interval: 600
      url: http://cp.cloudflare.com/generate_204
    override:
      skip-cert-verify: true"

            # 添加代理链配置
            if [[ -n "$proxy_line" ]]; then
                provider_block="${provider_block}
${proxy_line}"
            fi

            # 使用sed插入到proxy-providers:之后
            local temp_insert=$(mktemp)
            echo "$provider_block" > "$temp_insert"
            sed -i "/proxy-providers:/r $temp_insert" "$config_file"
            rm -f "$temp_insert"

            # 将新订阅添加到所有代理组的 use 列表中
            if grep -q "    use:" "$config_file"; then
                if ! grep -A 5 "    use:" "$config_file" | grep -q "- ${sub_name}"; then
                    local temp_file2=$(mktemp)
                    awk -v name="$sub_name" '
                    /    use:/ {
                        print;
                        getline;
                        if ($0 ~ /^      - /) {
                            print "      - " name
                        }
                        print;
                        next
                    }
                    { print }
                    ' "$config_file" > "$temp_file2"
                    mv "$temp_file2" "$config_file"
                    log_info "已将 [$sub_name] 添加到代理组"
                fi
            fi

            log_success "订阅已添加到配置"
        else
            log_warning "配置文件中没有proxy-providers部分，请先运行配置向导"
        fi
    else
        log_error "配置文件不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_subscription_menu
}

# 处理订阅命令
handle_sub_command() {
    local command=$1
    shift
    
    case $command in
        add)
            subscription_add "$@"
            ;;
        list)
            subscription_list
            ;;
        update)
            subscription_update
            ;;
        test)
            subscription_test "$@"
            ;;
        delete)
            subscription_delete
            ;;
        status)
            subscription_status
            ;;
        *)
            log_error "未知命令: $command"
            echo "用法: mihomo-quick.sh sub [add|list|update|test|delete|status]"
            return 1
            ;;
    esac
}

# 查看订阅列表
subscription_list() {
    log_info "查看订阅列表..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ -f "$config_file" ]]; then
        echo ""
        echo -e "${WHITE}订阅列表:${NC}"
        echo ""
        
        # 提取proxy-providers部分
        sed -n '/^proxy-providers:/,/^[a-zA-Z]/p' "$config_file" | grep -E "^  [a-zA-Z]" | sed 's/://g' | sed 's/^  //'
        
        echo ""
    else
        log_warning "配置文件不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_subscription_menu
}

# 更新订阅（通知 mihomo 内核重新下载）
subscription_update() {
    log_info "更新订阅..."

    local config_file="${CONFIGS_DIR}/config.yaml"

    if [[ -f "$config_file" ]]; then
        # 检查是否有订阅配置
        if ! grep -q "proxy-providers:" "$config_file"; then
            log_warning "未找到订阅配置"
            read -p "按 Enter 键返回..."
            show_subscription_menu
            return 1
        fi

        # 列出当前订阅
        echo ""
        echo -e "${WHITE}当前订阅:${NC}"
        sed -n '/^proxy-providers:/,/^[a-zA-Z]/p' "$config_file" | grep -E "^  [a-zA-Z]" | sed 's/://g' | sed 's/^  /  - /'
        echo ""

        # 通过 API 通知 mihomo 内核刷新订阅
        local api_port=$(grep "^external-controller:" "$config_file" | sed 's/.*://' | tr -d ' ')
        api_port="${api_port:-9090}"

        if curl -s --connect-timeout 3 "http://127.0.0.1:${api_port}/providers" > /dev/null 2>&1; then
            log_info "通过 mihomo API 触发订阅刷新..."
            # mihomo 的 proxy-providers 会在 interval 到期时自动刷新
            # 也可以通过 PUT /providers/proxies/:name 触发
            local providers=$(sed -n '/^proxy-providers:/,/^[a-zA-Z]/p' "$config_file" | grep -E "^  [a-zA-Z]" | sed 's/://g' | sed 's/^  //')
            for provider in $providers; do
                curl -s -X PUT "http://127.0.0.1:${api_port}/providers/proxies/${provider}" > /dev/null 2>&1
                log_info "已触发刷新: $provider"
            done
            log_success "订阅刷新请求已发送，mihomo 将在后台下载"
        else
            log_warning "mihomo 未运行或 API 不可达 (端口: $api_port)"
            log_info "订阅将在 mihomo 下次启动时自动下载"
            log_info "也可以手动重启 mihomo 来立即下载订阅"
        fi
    else
        log_error "配置文件不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_subscription_menu
}

# 测试节点
subscription_test() {
    log_info "测试节点..."
    
    # 检查服务是否运行
    if ! systemctl is-active --quiet mihomo-quick.service 2>/dev/null; then
        log_warning "mihomo服务未运行"
        read -p "按 Enter 键返回..."
        show_subscription_menu
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}测试节点延迟...${NC}"
    echo ""
    
    # 测试代理连接
    if curl -s --connect-timeout 5 --socks5 127.0.0.1:${DEFAULT_SOCKS_PORT} https://httpbin.org/ip > /dev/null; then
        log_success "代理连接正常"
        
        # 获取代理IP
        local proxy_ip=$(curl -s --socks5 127.0.0.1:${DEFAULT_SOCKS_PORT} https://httpbin.org/ip | grep origin | cut -d'"' -f4)
        echo -e "  代理IP: $proxy_ip"
    else
        log_error "代理连接失败"
    fi
    
    echo ""
    
    read -p "按 Enter 键返回..."
    show_subscription_menu
}

# 删除订阅
subscription_delete() {
    log_info "删除订阅..."
    
    subscription_list
    
    read -p "请输入要删除的订阅名称: " sub_name
    
    if [[ -z "$sub_name" ]]; then
        log_error "订阅名称不能为空"
        read -p "按 Enter 键返回..."
        show_subscription_menu
        return 1
    fi
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ -f "$config_file" ]]; then
        # 删除订阅配置
        sed -i "/$sub_name:/,/^[^ ]/d" "$config_file"
        log_success "订阅已删除: $sub_name"
    else
        log_error "配置文件不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_subscription_menu
}

# 订阅状态
subscription_status() {
    log_info "查看订阅状态..."
    
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ -f "$config_file" ]]; then
        echo ""
        echo -e "${WHITE}订阅状态:${NC}"
        echo ""
        
        # 提取订阅信息
        awk '/proxy-providers:/,/^[^ ]/' "$config_file" | while IFS= read -r line; do
            if [[ "$line" =~ ^[a-zA-Z0-9_-]+: ]]; then
                echo -e "${GREEN}${line}${NC}"
            elif [[ "$line" =~ url: ]]; then
                echo "  URL: $(echo "$line" | sed 's/.*url: "//' | sed 's/".*//')"
            elif [[ "$line" =~ interval: ]]; then
                echo "  间隔: $(echo "$line" | sed 's/.*interval: //')"
            fi
        done
        
        echo ""
    else
        log_warning "配置文件不存在"
    fi
    
    read -p "按 Enter 键返回..."
    show_subscription_menu
}

echo "✓ 已加载订阅管理模块: subscription.sh"
