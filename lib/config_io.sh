#!/bin/bash
#
# config_io.sh - 配置导入导出模块
# 提供配置导入、导出、备份和恢复功能
#

# ============================================================================
# 配置导入函数
# ============================================================================

# 导入配置文件
import_config() {
    local file=$1
    local format=${2:-"auto"}
    
    log_info "导入配置文件: $file"
    
    # 检查文件是否存在
    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file"
        return 1
    fi
    
    # 自动检测格式
    if [[ "$format" == "auto" ]]; then
        format=$(detect_config_format "$file")
    fi
    
    # 验证文件
    if ! validate_import_file "$file" "$format"; then
        log_error "文件验证失败"
        return 1
    fi
    
    # 确认导入
    if ! confirm_import "$file"; then
        log_info "取消导入"
        return 1
    fi
    
    # 备份现有配置
    if [[ -f "${CONFIGS_DIR}/config.yaml" ]]; then
        backup_file "${CONFIGS_DIR}/config.yaml"
    fi
    
    # 执行导入
    case $format in
        yaml)
            import_yaml_config "$file"
            ;;
        json)
            import_json_config "$file"
            ;;
        raw)
            import_raw_config "$file"
            ;;
        *)
            log_error "不支持的格式: $format"
            return 1
            ;;
    esac
    
    log_success "配置导入完成"
    return 0
}

# 检测配置格式
detect_config_format() {
    local file=$1
    
    if [[ "$file" == *.yaml || "$file" == *.yml ]]; then
        echo "yaml"
    elif [[ "$file" == *.json ]]; then
        echo "json"
    else
        # 检查文件内容
        if head -1 "$file" | grep -q ":"; then
            echo "yaml"
        elif head -1 "$file" | grep -q "{"; then
            echo "json"
        else
            echo "raw"
        fi
    fi
}

# 验证导入文件
validate_import_file() {
    local file=$1
    local format=$2
    
    log_info "验证导入文件..."
    
    echo ""
    echo -e "${WHITE}文件验证:${NC}"
    echo "  文件: $file"
    echo "  格式: $format"
    echo "  大小: $(du -h "$file" | cut -f1)"
    echo "  修改: $(stat -c %y "$file" 2>/dev/null | cut -d. -f1)"
    echo ""
    
    # 格式验证
    case $format in
        yaml)
            if command -v python3 &> /dev/null; then
                if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} YAML格式正确"
                else
                    echo -e "  ${RED}✗${NC} YAML格式错误"
                    return 1
                fi
            else
                echo -e "  ${YELLOW}⚠${NC} 无法验证YAML格式"
            fi
            ;;
        json)
            if python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} JSON格式正确"
            else
                echo -e "  ${RED}✗${NC} JSON格式错误"
                return 1
            fi
            ;;
        raw)
            echo -e "  ${GREEN}✓${NC} 原始配置文件"
            ;;
    esac
    
    # 内容验证
    if grep -q "mixed-port:" "$file" || grep -q "socks-port:" "$file"; then
        echo -e "  ${GREEN}✓${NC} 关键配置项存在"
    else
        echo -e "  ${YELLOW}⚠${NC} 关键配置项缺失"
    fi
    
    echo ""
    
    return 0
}

# 确认导入
confirm_import() {
    local file=$1
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}导入确认${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "源文件: $file"
    echo "目标文件: ${CONFIGS_DIR}/config.yaml"
    echo ""
    echo -e "${YELLOW}警告: 导入将覆盖现有配置${NC}"
    echo ""
    
    read -p "确认导入? (y/N): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

# 导入YAML配置
import_yaml_config() {
    local file=$1
    
    log_info "导入YAML配置..."
    
    # 复制配置文件
    cp "$file" "${CONFIGS_DIR}/config.yaml"
    
    # 设置权限
    chmod 644 "${CONFIGS_DIR}/config.yaml"
    
    log_success "YAML配置导入完成"
}

# 导入JSON配置
import_json_config() {
    local file=$1
    
    log_info "导入JSON配置..."
    
    # 转换为YAML
    if command -v python3 &> /dev/null; then
        python3 -c "
import json, yaml, sys
try:
    with open('$file') as f:
        data = json.load(f)
    with open('${CONFIGS_DIR}/config.yaml', 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    print('JSON转换成功')
except Exception as e:
    print(f'转换失败: {e}', file=sys.stderr)
    sys.exit(1)
"
        
        if [[ $? -eq 0 ]]; then
            log_success "JSON配置导入完成"
        else
            log_error "JSON转换失败"
            return 1
        fi
    else
        log_error "需要python3支持"
        return 1
    fi
}

# 导入原始配置
import_raw_config() {
    local file=$1
    
    log_info "导入原始配置..."
    
    # 复制配置文件
    cp "$file" "${CONFIGS_DIR}/config.yaml"
    
    # 设置权限
    chmod 644 "${CONFIGS_DIR}/config.yaml"
    
    log_success "原始配置导入完成"
}

# ============================================================================
# 配置导出函数
# ============================================================================

# 导出配置文件
export_config() {
    local format=${1:-"yaml"}
    local output=${2:-""}
    
    log_info "导出配置文件..."
    
    # 检查配置文件是否存在
    if [[ ! -f "${CONFIGS_DIR}/config.yaml" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    # 生成输出文件名
    if [[ -z "$output" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        output="${CONFIGS_DIR}/config_export_${timestamp}.${format}"
    fi
    
    # 执行导出
    case $format in
        yaml)
            export_yaml_config "$output"
            ;;
        json)
            export_json_config "$output"
            ;;
        backup)
            export_backup_config "$output"
            ;;
        *)
            log_error "不支持的格式: $format"
            return 1
            ;;
    esac
    
    log_success "配置导出完成: $output"
    return 0
}

# 导出为YAML格式
export_yaml_config() {
    local output=$1
    
    log_info "导出为YAML格式..."
    
    # 复制配置文件
    cp "${CONFIGS_DIR}/config.yaml" "$output"
    
    # 添加导出信息
    sed -i "1i# mihomo-quick 配置导出" "$output"
    sed -i "2i# 导出时间: $(date '+%Y-%m-%d %H:%M:%S')" "$output"
    sed -i "3i# 版本: $VERSION" "$output"
    sed -i "4i" "$output"
    
    log_success "YAML导出完成"
}

# 导出为JSON格式
export_json_config() {
    local output=$1
    
    log_info "导出为JSON格式..."
    
    # 转换为JSON
    if command -v python3 &> /dev/null; then
        python3 -c "
import json, yaml, sys
try:
    with open('${CONFIGS_DIR}/config.yaml') as f:
        data = yaml.safe_load(f)
    
    # 添加导出信息
    export_data = {
        '_export_info': {
            'tool': 'mihomo-quick',
            'version': '$VERSION',
            'time': '$(date '+%Y-%m-%d %H:%M:%S')',
            'format': 'json'
        },
        'config': data
    }
    
    with open('$output', 'w') as f:
        json.dump(export_data, f, indent=2, ensure_ascii=False)
    
    print('JSON导出成功')
except Exception as e:
    print(f'导出失败: {e}', file=sys.stderr)
    sys.exit(1)
"
        
        if [[ $? -eq 0 ]]; then
            log_success "JSON导出完成"
        else
            log_error "JSON导出失败"
            return 1
        fi
    else
        log_error "需要python3支持"
        return 1
    fi
}

# 导出为备份格式
export_backup_config() {
    local output=$1
    
    log_info "导出为备份格式..."
    
    # 创建备份目录
    local backup_dir="${BACKUPS_DIR}/exports"
    mkdir -p "$backup_dir"
    
    # 复制配置文件
    cp "${CONFIGS_DIR}/config.yaml" "$output"
    
    # 添加备份信息
    cat > "${output}.info" << EOF
# mihomo-quick 配置备份
# 导出时间: $(date '+%Y-%m-%d %H:%M:%S')
# 版本: $VERSION
# 格式: backup
# 文件: $(basename "$output")
EOF
    
    log_success "备份导出完成"
}

# ============================================================================
# 配置备份恢复函数
# ============================================================================

# 创建配置备份
backup_config() {
    log_info "创建配置备份..."
    
    # 检查配置文件是否存在
    if [[ ! -f "${CONFIGS_DIR}/config.yaml" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    # 创建备份
    backup_file "${CONFIGS_DIR}/config.yaml"
    
    log_success "配置备份完成"
}

# 恢复配置备份
restore_config() {
    local backup_file=$1
    
    log_info "恢复配置备份..."
    
    # 检查备份文件是否存在
    if [[ ! -f "$backup_file" ]]; then
        log_error "备份文件不存在: $backup_file"
        return 1
    fi
    
    # 确认恢复
    if ! confirm_restore "$backup_file"; then
        log_info "取消恢复"
        return 1
    fi
    
    # 恢复备份
    restore_file "$backup_file" "${CONFIGS_DIR}/config.yaml"
    
    log_success "配置恢复完成"
}

# 确认恢复
confirm_restore() {
    local backup_file=$1
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}恢复确认${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "备份文件: $backup_file"
    echo "目标文件: ${CONFIGS_DIR}/config.yaml"
    echo ""
    echo -e "${YELLOW}警告: 恢复将覆盖现有配置${NC}"
    echo ""
    
    read -p "确认恢复? (y/N): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

# 列出配置备份
list_config_backups() {
    log_info "列出配置备份..."
    
    local backup_dir="${BACKUPS_DIR}"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_warning "备份目录不存在"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}配置备份列表:${NC}"
    echo ""
    
    local count=0
    for backup in "$backup_dir"/config.yaml.*.bak; do
        if [[ -f "$backup" ]]; then
            local filename=$(basename "$backup")
            local size=$(du -h "$backup" | cut -f1)
            local time=$(stat -c %y "$backup" 2>/dev/null | cut -d. -f1)
            echo -e "  ${GREEN}✓${NC} $filename ($size) - $time"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo -e "  ${YELLOW}没有备份文件${NC}"
    fi
    
    echo ""
}

# 清理旧备份
clean_old_backups() {
    local keep_days=${1:-30}
    
    log_info "清理${keep_days}天前的备份..."
    
    local backup_dir="${BACKUPS_DIR}"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_warning "备份目录不存在"
        return 1
    fi
    
    # 查找并删除旧备份
    local deleted=0
    find "$backup_dir" -name "config.yaml.*.bak" -mtime +$keep_days -type f | while read backup; do
        rm -f "$backup"
        echo "删除: $(basename "$backup")"
        ((deleted++))
    done
    
    log_success "清理完成，删除了 $deleted 个旧备份"
}

# ============================================================================
# 配置分享函数
# ============================================================================

# 生成分享配置
generate_share_config() {
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    log_info "生成分享配置..."
    
    # 检查配置文件是否存在
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    # 创建分享目录
    local share_dir="${CONFIGS_DIR}/shares"
    mkdir -p "$share_dir"
    
    # 生成分享ID
    local share_id=$(date +%Y%m%d_%H%M%S)_$(openssl rand -hex 4)
    local share_file="${share_dir}/share_${share_id}.yaml"
    
    # 创建分享配置
    cat > "$share_file" << EOF
# mihomo-quick 分享配置
# 分享ID: $share_id
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 工具版本: $VERSION

# 原始配置
$(cat "$config_file")

# 分享信息
_share_info:
  id: "$share_id"
  tool: "mihomo-quick"
  version: "$VERSION"
  time: "$(date '+%Y-%m-%d %H:%M:%S')"
  description: "mihomo-quick 配置分享"
EOF
    
    echo ""
    echo -e "${GREEN}分享配置已生成:${NC}"
    echo "  文件: $share_file"
    echo "  ID: $share_id"
    echo ""
    echo -e "${YELLOW}提示: 可以将此文件分享给其他用户${NC}"
    echo ""
    
    log_success "分享配置生成完成"
}

# 导入分享配置
import_share_config() {
    local share_file=$1
    
    log_info "导入分享配置..."
    
    # 检查文件是否存在
    if [[ ! -f "$share_file" ]]; then
        log_error "分享文件不存在: $share_file"
        return 1
    fi
    
    # 验证分享文件
    if ! grep -q "_share_info:" "$share_file"; then
        log_warning "不是标准的分享文件"
    fi
    
    # 提取原始配置
    local temp_config=$(mktemp)
    sed -n '/^# mihomo-quick 分享配置/,/^_share_info:/p' "$share_file" | \
        grep -v "^#" | grep -v "^_share_info:" > "$temp_config"
    
    # 导入配置
    import_config "$temp_config" "yaml"
    
    # 清理临时文件
    rm -f "$temp_config"
    
    log_success "分享配置导入完成"
}

# 列出分享配置
list_share_configs() {
    log_info "列出分享配置..."
    
    local share_dir="${CONFIGS_DIR}/shares"
    
    if [[ ! -d "$share_dir" ]]; then
        log_warning "分享目录不存在"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}分享配置列表:${NC}"
    echo ""
    
    local count=0
    for share in "$share_dir"/share_*.yaml; do
        if [[ -f "$share" ]]; then
            local filename=$(basename "$share")
            local size=$(du -h "$share" | cut -f1)
            local time=$(stat -c %y "$share" 2>/dev/null | cut -d. -f1)
            echo -e "  ${GREEN}✓${NC} $filename ($size) - $time"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo -e "  ${YELLOW}没有分享文件${NC}"
    fi
    
    echo ""
}

echo "✓ 已加载配置导入导出模块: config_io.sh"
