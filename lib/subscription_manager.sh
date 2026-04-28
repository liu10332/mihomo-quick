#!/bin/bash
#
# subscription_manager.sh - 订阅管理模块
# 提供订阅解析、存储、更新和管理功能
#

# ============================================================================
# 订阅目录结构
# ============================================================================

# 订阅目录
SUBSCRIPTIONS_DIR="${CONFIGS_DIR}/subscriptions"
NODES_DIR="${CONFIGS_DIR}/nodes"

# 创建订阅目录
create_subscription_dirs() {
    mkdir -p "$SUBSCRIPTIONS_DIR"
    mkdir -p "$NODES_DIR"
    log_debug "订阅目录创建完成"
}

# ============================================================================
# 订阅格式解析
# ============================================================================

# 检测订阅格式
detect_subscription_format() {
    local file=$1
    
    # 检查文件内容
    if head -1 "$file" | grep -q "^proxies:"; then
        echo "yaml"
    elif head -1 "$file" | grep -q "{"; then
        echo "json"
    elif file "$file" | grep -q "ASCII text"; then
        echo "raw"
    else
        echo "unknown"
    fi
}

# 解析订阅文件
parse_subscription() {
    local subscription_file=$1
    local provider_name=$2
    local output_file="${NODES_DIR}/${provider_name}_nodes.yaml"
    
    log_info "解析订阅: $provider_name"
    
    # 检查文件是否存在
    if [[ ! -f "$subscription_file" ]]; then
        log_error "订阅文件不存在: $subscription_file"
        return 1
    fi
    
    # 检测格式
    local format=$(detect_subscription_format "$subscription_file")
    
    # 解析订阅
    case $format in
        yaml)
            parse_yaml_subscription "$subscription_file" "$output_file"
            ;;
        json)
            parse_json_subscription "$subscription_file" "$output_file"
            ;;
        raw)
            parse_raw_subscription "$subscription_file" "$output_file"
            ;;
        *)
            log_error "不支持的格式: $format"
            return 1
            ;;
    esac
    
    # 统计节点数量
    local node_count=$(grep -c "^  - name:" "$output_file" 2>/dev/null || echo "0")
    
    log_success "订阅解析完成: $provider_name ($node_count 个节点)"
    
    # 保存订阅信息
    save_subscription_info "$provider_name" "$subscription_file" "$format" "$node_count"
    
    return 0
}

# 解析YAML格式订阅
parse_yaml_subscription() {
    local subscription_file=$1
    local output_file=$2
    
    log_debug "解析YAML订阅..."
    
    # 验证YAML格式
    if ! validate_yaml_syntax "$subscription_file"; then
        log_error "YAML格式错误"
        return 1
    fi
    
    # 提取proxies部分
    if grep -q "^proxies:" "$subscription_file"; then
        # 提取proxies部分到临时文件
        local temp_file=$(mktemp)
        sed -n '/^proxies:/,/^[a-zA-Z]/p' "$subscription_file" | head -n -1 > "$temp_file"
        
        # 添加头部信息
        cat > "$output_file" << EOF
# mihomo-quick 订阅节点
# 来源: $(basename "$subscription_file")
# 解析时间: $(date '+%Y-%m-%d %H:%M:%S')
# 格式: YAML

proxies:
$(cat "$temp_file" | grep -v "^proxies:")
EOF
        
        rm -f "$temp_file"
    else
        # 如果没有proxies部分，直接复制
        cp "$subscription_file" "$output_file"
    fi
    
    log_debug "YAML解析完成"
}

# 解析JSON格式订阅
parse_json_subscription() {
    local subscription_file=$1
    local output_file=$2
    
    log_debug "解析JSON订阅..."
    
    # 验证JSON格式
    if ! python3 -c "import json; json.load(open('$subscription_file'))" 2>/dev/null; then
        log_error "JSON格式错误"
        return 1
    fi
    
    # 转换为YAML
    python3 -c "
import json, yaml, sys
from datetime import datetime

try:
    with open('$subscription_file') as f:
        data = json.load(f)
    
    # 提取proxies部分
    if 'proxies' in data:
        proxies = data['proxies']
    else:
        proxies = data
    
    # 添加头部信息
    output_data = {
        '_header': {
            'tool': 'mihomo-quick',
            'source': '$(basename "$subscription_file")',
            'time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'format': 'JSON'
        },
        'proxies': proxies
    }
    
    with open('$output_file', 'w') as f:
        yaml.dump(output_data, f, default_flow_style=False, allow_unicode=True)
    
    print('JSON解析完成')
except Exception as e:
    print(f'解析失败: {e}', file=sys.stderr)
    sys.exit(1)
"
    
    if [[ $? -eq 0 ]]; then
        log_debug "JSON解析完成"
    else
        log_error "JSON解析失败"
        return 1
    fi
}

# 解析原始格式订阅
parse_raw_subscription() {
    local subscription_file=$1
    local output_file=$2
    
    log_debug "解析原始订阅..."
    
    # 检查是否为base64编码
    if file "$subscription_file" | grep -q "ASCII text"; then
        # 尝试base64解码
        local temp_file=$(mktemp)
        if base64 -d "$subscription_file" > "$temp_file" 2>/dev/null; then
            # 解码成功，解析解码后的内容
            local decoded_format=$(detect_subscription_format "$temp_file")
            
            case $decoded_format in
                yaml)
                    parse_yaml_subscription "$temp_file" "$output_file"
                    ;;
                json)
                    parse_json_subscription "$temp_file" "$output_file"
                    ;;
                *)
                    # 如果解码后格式未知，直接复制
                    cp "$temp_file" "$output_file"
                    ;;
            esac
            
            rm -f "$temp_file"
            log_debug "Base64解码完成"
        else
            # 不是base64，直接复制
            cp "$subscription_file" "$output_file"
            log_debug "原始格式解析完成"
        fi
    else
        # 二进制文件，尝试base64解码
        local temp_file=$(mktemp)
        if base64 -d "$subscription_file" > "$temp_file" 2>/dev/null; then
            cp "$temp_file" "$output_file"
            rm -f "$temp_file"
            log_debug "Base64解码完成"
        else
            cp "$subscription_file" "$output_file"
            log_debug "原始格式解析完成"
        fi
    fi
}

# ============================================================================
# 订阅信息管理
# ============================================================================

# 保存订阅信息
save_subscription_info() {
    local provider_name=$1
    local subscription_file=$2
    local format=$3
    local node_count=$4
    
    local info_file="${SUBSCRIPTIONS_DIR}/providers.json"
    
    # 创建或更新providers.json
    if [[ -f "$info_file" ]]; then
        # 更新现有文件
        python3 -c "
import json, sys
from datetime import datetime

try:
    with open('$info_file') as f:
        data = json.load(f)
except:
    data = {}

data['$provider_name'] = {
    'file': '$(basename "$subscription_file")',
    'format': '$format',
    'nodes': $node_count,
    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
    'status': 'active'
}

with open('$info_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"
    else
        # 创建新文件
        cat > "$info_file" << EOF
{
  "$provider_name": {
    "file": "$(basename "$subscription_file")",
    "format": "$format",
    "nodes": $node_count,
    "update_time": "$(date '+%Y-%m-%d %H:%M:%S')",
    "status": "active"
  }
}
EOF
    fi
    
    log_debug "订阅信息已保存: $provider_name"
}

# 获取订阅信息
get_subscription_info() {
    local provider_name=$1
    local info_file="${SUBSCRIPTIONS_DIR}/providers.json"
    
    if [[ -f "$info_file" ]]; then
        python3 -c "
import json
with open('$info_file') as f:
    data = json.load(f)
if '$provider_name' in data:
    info = data['$provider_name']
    print(f\"名称: $provider_name\")
    print(f\"文件: {info['file']}\")
    print(f\"格式: {info['format']}\")
    print(f\"节点: {info['nodes']}\")
    print(f\"更新: {info['update_time']}\")
    print(f\"状态: {info['status']}\")
else:
    print('订阅不存在')
"
    else
        echo "订阅信息文件不存在"
    fi
}

# 列出所有订阅
list_subscriptions() {
    local info_file="${SUBSCRIPTIONS_DIR}/providers.json"
    
    log_info "列出所有订阅..."
    
    if [[ -f "$info_file" ]]; then
        echo ""
        echo -e "${WHITE}订阅列表:${NC}"
        echo ""
        
        python3 -c "
import json
with open('$info_file') as f:
    data = json.load(f)

for name, info in data.items():
    status_color = '\033[32m' if info['status'] == 'active' else '\033[31m'
    print(f\"  {status_color}✓\033[0m {name}: {info['nodes']} 个节点 - {info['update_time']}\")
"
        echo ""
    else
        echo -e "  ${YELLOW}没有订阅配置${NC}"
    fi
}

# ============================================================================
# 订阅更新管理
# ============================================================================

# 更新订阅
update_subscription() {
    local provider_name=$1
    local subscription_url=$2
    
    log_info "更新订阅: $provider_name"
    
    # 创建订阅目录
    create_subscription_dirs
    
    # 下载订阅
    local temp_file=$(mktemp)
    local subscription_file="${SUBSCRIPTIONS_DIR}/${provider_name}.yaml"
    
    if curl -s -o "$temp_file" "$subscription_url"; then
        log_success "订阅下载成功"
        
        # 解析订阅
        if parse_subscription "$temp_file" "$provider_name"; then
            # 复制订阅文件
            cp "$temp_file" "$subscription_file"
            
            # 清理临时文件
            rm -f "$temp_file"
            
            log_success "订阅更新完成: $provider_name"
            return 0
        else
            log_error "订阅解析失败"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "订阅下载失败"
        rm -f "$temp_file"
        return 1
    fi
}

# 批量更新订阅
update_all_subscriptions() {
    log_info "批量更新订阅..."
    
    local info_file="${SUBSCRIPTIONS_DIR}/providers.json"
    
    if [[ ! -f "$info_file" ]]; then
        log_warning "没有订阅配置"
        return 0
    fi
    
    # 读取所有订阅
    local providers=$(python3 -c "
import json
with open('$info_file') as f:
    data = json.load(f)
for name in data.keys():
    print(name)
")
    
    local updated=0
    local failed=0
    
    for provider in $providers; do
        local subscription_file="${SUBSCRIPTIONS_DIR}/${provider}.yaml"
        
        if [[ -f "$subscription_file" ]]; then
            # 从文件中提取URL
            local url=$(grep "^url:" "$subscription_file" | head -1 | cut -d: -f2- | tr -d ' ')
            
            if [[ -n "$url" ]]; then
                if update_subscription "$provider" "$url"; then
                    ((updated++))
                else
                    ((failed++))
                fi
            else
                log_warning "订阅URL不存在: $provider"
            fi
        else
            log_warning "订阅文件不存在: $provider"
        fi
    done
    
    log_success "批量更新完成: 成功 $updated, 失败 $failed"
}

# 自动更新订阅（定时任务）
auto_update_subscriptions() {
    log_info "自动更新订阅..."
    
    # 检查是否启用自动更新
    local auto_update=$(grep "^auto-update:" "${CONFIGS_DIR}/config.yaml" 2>/dev/null | awk '{print $2}')
    
    if [[ "$auto_update" != "true" ]]; then
        log_debug "自动更新未启用"
        return 0
    fi
    
    # 更新所有订阅
    update_all_subscriptions
    
    # 记录更新日志
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 自动更新完成" >> "${LOGS_DIR}/subscription_update.log"
}

# ============================================================================
# 订阅验证和清理
# ============================================================================

# 验证订阅
validate_subscription() {
    local provider_name=$1
    
    log_info "验证订阅: $provider_name"
    
    local nodes_file="${NODES_DIR}/${provider_name}_nodes.yaml"
    
    if [[ ! -f "$nodes_file" ]]; then
        log_error "节点文件不存在: $nodes_file"
        return 1
    fi
    
    # 验证节点格式
    local node_count=$(grep -c "^  - name:" "$nodes_file" 2>/dev/null || echo "0")
    
    if [[ "$node_count" -eq 0 ]]; then
        log_warning "订阅中没有节点"
        return 1
    fi
    
    # 验证节点信息完整性
    local invalid_nodes=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]* ]]; then
            local node_name=$(echo "$line" | cut -d: -f2 | tr -d ' ')
            
            # 检查必要字段
            if ! grep -A 10 "name: $node_name" "$nodes_file" | grep -q "server:"; then
                log_warning "节点缺少server字段: $node_name"
                ((invalid_nodes++))
            fi
            
            if ! grep -A 10 "name: $node_name" "$nodes_file" | grep -q "port:"; then
                log_warning "节点缺少port字段: $node_name"
                ((invalid_nodes++))
            fi
        fi
    done < "$nodes_file"
    
    if [[ "$invalid_nodes" -gt 0 ]]; then
        log_warning "发现 $invalid_nodes 个无效节点"
    fi
    
    log_success "订阅验证完成: $provider_name ($node_count 个节点)"
    return 0
}

# 清理无效订阅
cleanup_invalid_subscriptions() {
    log_info "清理无效订阅..."
    
    local info_file="${SUBSCRIPTIONS_DIR}/providers.json"
    
    if [[ ! -f "$info_file" ]]; then
        log_warning "没有订阅配置"
        return 0
    fi
    
    # 读取所有订阅
    local providers=$(python3 -c "
import json
with open('$info_file') as f:
    data = json.load(f)
for name in data.keys():
    print(name)
")
    
    local cleaned=0
    
    for provider in $providers; do
        local nodes_file="${NODES_DIR}/${provider}_nodes.yaml"
        
        # 检查节点文件是否存在
        if [[ ! -f "$nodes_file" ]]; then
            log_warning "节点文件不存在: $provider"
            # 标记为无效
            python3 -c "
import json
with open('$info_file') as f:
    data = json.load(f)
data['$provider']['status'] = 'invalid'
with open('$info_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"
            ((cleaned++))
        else
            # 验证订阅
            if ! validate_subscription "$provider"; then
                log_warning "订阅验证失败: $provider"
                # 标记为无效
                python3 -c "
import json
with open('$info_file') as f:
    data = json.load(f)
data['$provider']['status'] = 'invalid'
with open('$info_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"
                ((cleaned++))
            fi
        fi
    done
    
    log_success "清理完成: $cleaned 个无效订阅"
}

# ============================================================================
# 订阅合并和导出
# ============================================================================

# 合并所有节点
merge_all_nodes() {
    log_info "合并所有节点..."
    
    local all_nodes_file="${NODES_DIR}/all_nodes.yaml"
    
    # 创建合并文件
    cat > "$all_nodes_file" << EOF
# mihomo-quick 合并节点
# 合并时间: $(date '+%Y-%m-%d %H:%M:%S')
# 来源: 所有订阅

proxies:
EOF
    
    # 合并所有节点文件
    for nodes_file in "${NODES_DIR}"/*_nodes.yaml; do
        if [[ -f "$nodes_file" ]]; then
            local provider_name=$(basename "$nodes_file" _nodes.yaml)
            
            # 提取节点部分
            if grep -q "^proxies:" "$nodes_file"; then
                echo "" >> "$all_nodes_file"
                echo "# 来源: $provider_name" >> "$all_nodes_file"
                grep -A 1000 "^proxies:" "$nodes_file" | grep -v "^proxies:" >> "$all_nodes_file"
            fi
        fi
    done
    
    # 统计节点数量
    local node_count=$(grep -c "^  - name:" "$all_nodes_file" 2>/dev/null || echo "0")
    
    log_success "节点合并完成: $node_count 个节点"
}

# 导出订阅
export_subscription() {
    local provider_name=$1
    local format=${2:-"yaml"}
    local output_file="${CONFIGS_DIR}/export_${provider_name}_${date +%Y%m%d_%H%M%S}.${format}"
    
    log_info "导出订阅: $provider_name"
    
    local nodes_file="${NODES_DIR}/${provider_name}_nodes.yaml"
    
    if [[ ! -f "$nodes_file" ]]; then
        log_error "节点文件不存在: $nodes_file"
        return 1
    fi
    
    # 导出订阅
    case $format in
        yaml)
            cp "$nodes_file" "$output_file"
            ;;
        json)
            # 转换为JSON
            python3 -c "
import yaml, json
with open('$nodes_file') as f:
    data = yaml.safe_load(f)
with open('$output_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"
            ;;
        *)
            log_error "不支持的格式: $format"
            return 1
            ;;
    esac
    
    log_success "订阅导出完成: $output_file"
}

echo "✓ 已加载订阅管理模块: subscription_manager.sh"
