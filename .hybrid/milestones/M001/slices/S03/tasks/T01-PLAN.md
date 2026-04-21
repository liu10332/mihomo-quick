# T01 完善系统检查功能 任务计划

## 任务目标
添加系统环境检查和依赖验证功能，确保工具在不同环境下都能正常运行。

## 步骤分解

### 步骤1: 添加操作系统检查
```bash
check_os() {
    echo "操作系统信息:"
    echo "  系统: $(uname -s)"
    echo "  内核: $(uname -r)"
    echo "  架构: $(uname -m)"
    echo "  主机: $(hostname)"
    
    # 检查是否为Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        log_warning "此工具主要支持Linux系统"
    fi
    
    # 检查发行版
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "  发行版: $PRETTY_NAME"
    fi
}
```

### 步骤2: 添加依赖软件检查
```bash
check_dependencies() {
    local deps=("curl" "jq" "tar" "systemctl" "ip" "netstat")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        return 1
    fi
    
    log_success "依赖检查通过"
    return 0
}
```

### 步骤3: 添加权限检查
```bash
check_permissions() {
    # 检查root权限
    if [[ $EUID -eq 0 ]]; then
        log_info "当前为root用户"
    else
        log_warning "当前非root用户，某些功能可能受限"
    fi
    
    # 检查sudo权限
    if sudo -n true 2>/dev/null; then
        log_info "sudo权限可用"
    else
        log_warning "sudo权限不可用"
    fi
    
    # 检查目录权限
    local dirs=("$CONFIGS_DIR" "$LOGS_DIR" "$BACKUPS_DIR")
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" ]]; then
                log_debug "目录可写: $dir"
            else
                log_warning "目录不可写: $dir"
            fi
        fi
    done
}
```

### 步骤4: 添加端口检查
```bash
check_ports() {
    local ports=("$DEFAULT_HTTP_PORT" "$DEFAULT_SOCKS_PORT" "9090")
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_warning "端口 $port 已被占用"
        else
            log_debug "端口 $port 可用"
        fi
    done
}
```

### 步骤5: 添加综合检查
```bash
check_system() {
    log_info "执行系统检查..."
    
    check_os
    check_dependencies
    check_permissions
    check_ports
    
    log_success "系统检查完成"
}
```

## 验收标准
1. 系统检查完整
2. 依赖验证准确
3. 权限检查可靠
4. 端口检查准确

## 预计时间
30分钟

## 创建日期
2026-04-21 12:11:37
