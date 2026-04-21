# T01 订阅格式解析 任务计划

## 任务目标
实现多种订阅格式的解析，支持YAML、JSON、原始格式和链接格式。

## 步骤分解

### 步骤1: 解析YAML格式
```bash
parse_yaml_subscription() {
    local subscription_file=$1
    local output_file=$2
    
    log_info "解析YAML订阅: $subscription_file"
    
    # 验证YAML格式
    if ! validate_yaml_syntax "$subscription_file"; then
        log_error "YAML格式错误"
        return 1
    fi
    
    # 提取proxies部分
    if grep -q "^proxies:" "$subscription_file"; then
        sed -n '/^proxies:/,/^[a-zA-Z]/p' "$subscription_file" |             head -n -1 > "$output_file"
    else
        # 如果没有proxies部分，复制整个文件
        cp "$subscription_file" "$output_file"
    fi
    
    log_success "YAML解析完成"
}
```

### 步骤2: 解析JSON格式
```bash
parse_json_subscription() {
    local subscription_file=$1
    local output_file=$2
    
    log_info "解析JSON订阅: $subscription_file"
    
    # 验证JSON格式
    if ! python3 -c "import json; json.load(open('$subscription_file'))" 2>/dev/null; then
        log_error "JSON格式错误"
        return 1
    fi
    
    # 转换为YAML
    python3 -c "
import json, yaml
with open('$subscription_file') as f:
    data = json.load(f)

# 提取proxies部分
if 'proxies' in data:
    proxies = data['proxies']
else:
    proxies = data

with open('$output_file', 'w') as f:
    yaml.dump({'proxies': proxies}, f, default_flow_style=False)
"
    
    log_success "JSON解析完成"
}
```

### 步骤3: 解析原始格式
```bash
parse_raw_subscription() {
    local subscription_file=$1
    local output_file=$2
    
    log_info "解析原始订阅: $subscription_file"
    
    # 检查是否为base64编码
    if file "$subscription_file" | grep -q "ASCII text"; then
        # 尝试base64解码
        if base64 -d "$subscription_file" > "$output_file" 2>/dev/null; then
            log_success "Base64解码完成"
        else
            # 如果不是base64，直接复制
            cp "$subscription_file" "$output_file"
            log_success "原始格式解析完成"
        fi
    else
        # 二进制文件，尝试base64解码
        base64 -d "$subscription_file" > "$output_file" 2>/dev/null ||             cp "$subscription_file" "$output_file"
        log_success "原始格式解析完成"
    fi
}
```

### 步骤4: 解析链接格式
```bash
parse_link_subscription() {
    local subscription_url=$1
    local output_file=$2
    
    log_info "解析链接订阅: $subscription_url"
    
    # 下载订阅
    local temp_file=$(mktemp)
    
    if curl -s -o "$temp_file" "$subscription_url"; then
        log_success "订阅下载成功"
        
        # 检测格式并解析
        local format=$(detect_subscription_format "$temp_file")
        
        case $format in
            yaml)
                parse_yaml_subscription "$temp_file" "$output_file"
                ;;
            json)
                parse_json_subscription "$temp_file" "$output_file"
                ;;
            raw)
                parse_raw_subscription "$temp_file" "$output_file"
                ;;
            *)
                log_error "未知格式: $format"
                rm -f "$temp_file"
                return 1
                ;;
        esac
        
        rm -f "$temp_file"
        log_success "链接订阅解析完成"
    else
        log_error "订阅下载失败"
        rm -f "$temp_file"
        return 1
    fi
}
```

### 步骤5: 添加格式检测
```bash
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
```

## 验收标准
1. 支持多种格式
2. 解析准确
3. 错误处理完善

## 预计时间
2小时

## 创建日期
2026-04-21 13:55:01
