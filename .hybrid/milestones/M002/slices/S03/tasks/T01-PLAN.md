# T01 配置导入功能 任务计划

## 任务目标
实现配置文件导入功能，支持多种格式和安全导入。

## 步骤分解

### 步骤1: 支持YAML格式导入
```bash
import_yaml_config() {
    local file=$1
    
    log_info "导入YAML配置: $file"
    
    # 验证YAML格式
    if ! validate_yaml_syntax "$file"; then
        log_error "YAML格式错误"
        return 1
    fi
    
    # 备份现有配置
    backup_file "${CONFIGS_DIR}/config.yaml"
    
    # 复制配置文件
    cp "$file" "${CONFIGS_DIR}/config.yaml"
    
    log_success "YAML配置导入成功"
}
```

### 步骤2: 支持JSON格式导入
```bash
import_json_config() {
    local file=$1
    
    log_info "导入JSON配置: $file"
    
    # 验证JSON格式
    if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
        log_error "JSON格式错误"
        return 1
    fi
    
    # 转换为YAML
    python3 -c "
import json, yaml
with open('$file') as f:
    data = json.load(f)
with open('${CONFIGS_DIR}/config.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False)
"
    
    log_success "JSON配置导入成功"
}
```

### 步骤3: 支持原始配置导入
```bash
import_raw_config() {
    local file=$1
    
    log_info "导入原始配置: $file"
    
    # 检查文件是否存在
    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    # 备份现有配置
    backup_file "${CONFIGS_DIR}/config.yaml"
    
    # 复制配置文件
    cp "$file" "${CONFIGS_DIR}/config.yaml"
    
    log_success "原始配置导入成功"
}
```

### 步骤4: 添加导入验证
```bash
validate_import() {
    local file=$1
    
    log_info "验证导入文件: $file"
    
    # 检查文件大小
    local size=$(du -h "$file" | cut -f1)
    echo "文件大小: $size"
    
    # 检查文件格式
    if [[ "$file" == *.yaml || "$file" == *.yml ]]; then
        echo "格式: YAML"
        validate_yaml_syntax "$file"
    elif [[ "$file" == *.json ]]; then
        echo "格式: JSON"
        python3 -c "import json; json.load(open('$file'))" 2>/dev/null
    else
        echo "格式: 原始配置"
    fi
    
    # 检查关键配置项
    if grep -q "mixed-port:" "$file" || grep -q "socks-port:" "$file"; then
        echo -e "${GREEN}✓ 关键配置项存在${NC}"
    else
        echo -e "${YELLOW}⚠ 关键配置项缺失${NC}"
    fi
    
    log_success "导入验证完成"
}
```

### 步骤5: 添加导入确认
```bash
confirm_import() {
    local file=$1
    
    echo ""
    echo -e "${WHITE}导入确认${NC}"
    echo ""
    echo "文件: $file"
    echo "目标: ${CONFIGS_DIR}/config.yaml"
    echo ""
    
    read -p "确认导入? (y/N): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        return 0
    else
        return 1
    fi
}
```

## 验收标准
1. 支持多种格式
2. 验证准确
3. 导入安全
4. 确认可靠

## 预计时间
1小时

## 创建日期
2026-04-21 13:41:50
