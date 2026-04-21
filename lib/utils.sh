#!/bin/bash
#
# utils.sh - 工具函数库
# 提供通用的工具函数和辅助功能
#

# ============================================================================
# 文件操作函数
# ============================================================================

# 备份文件
backup_file() {
    local file=$1
    local backup_dir="${BACKUPS_DIR:-./backups}"
    
    if [[ -f "$file" ]]; then
        mkdir -p "$backup_dir"
        local backup_file="${backup_dir}/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
        cp "$file" "$backup_file"
        log_info "已备份文件: $backup_file"
        return 0
    else
        log_warning "文件不存在: $file"
        return 1
    fi
}

# 恢复文件
restore_file() {
    local backup_file=$1
    local target_file=$2
    
    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$target_file"
        log_info "已恢复文件: $target_file"
        return 0
    else
        log_error "备份文件不存在: $backup_file"
        return 1
    fi
}

# 检查文件是否存在
file_exists() {
    local file=$1
    [[ -f "$file" ]]
}

# 检查目录是否存在
dir_exists() {
    local dir=$1
    [[ -d "$dir" ]]
}

# ============================================================================
# 字符串处理函数
# ============================================================================

# 去除字符串首尾空格
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# 转换为小写
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# 转换为大写
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# 检查字符串是否为空
is_empty() {
    [[ -z "$1" ]]
}

# 检查字符串是否不为空
is_not_empty() {
    [[ -n "$1" ]]
}

# ============================================================================
# 网络函数
# ============================================================================

# 检查网络连接
check_network() {
    if curl -s --connect-timeout 5 https://www.baidu.com > /dev/null; then
        return 0
    else
        return 1
    fi
}

# 获取公网IP
get_public_ip() {
    curl -s https://api.ipify.org
}

# 测试URL连通性
test_url() {
    local url=$1
    local timeout=${2:-5}
    
    if curl -s --connect-timeout "$timeout" "$url" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# 系统检查函数
# ============================================================================

# 检查操作系统
check_os() {
    log_info "检查操作系统..."
    
    echo ""
    echo -e "${WHITE}操作系统信息:${NC}"
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
        
        # 检查版本
        if [[ -n "$VERSION_ID" ]]; then
            echo "  版本: $VERSION_ID"
        fi
    fi
    
    echo ""
}

# 检查依赖软件
check_dependencies() {
    log_info "检查依赖软件..."
    
    local deps=("curl" "jq" "tar" "systemctl" "ip" "netstat" "grep" "sed" "awk")
    local missing=()
    
    echo ""
    echo -e "${WHITE}依赖检查:${NC}"
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} $dep"
        else
            echo -e "  ${RED}✗${NC} $dep"
            missing+=("$dep")
        fi
    done
    
    echo ""
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        log_info "请先安装缺少的依赖"
        return 1
    fi
    
    log_success "依赖检查通过"
    return 0
}

# 检查权限
check_permissions() {
    log_info "检查权限..."
    
    echo ""
    echo -e "${WHITE}权限检查:${NC}"
    
    # 检查root权限
    if [[ $EUID -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} root权限"
    else
        echo -e "  ${YELLOW}⚠${NC} 非root用户"
    fi
    
    # 检查sudo权限
    if sudo -n true 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} sudo权限"
    else
        echo -e "  ${YELLOW}⚠${NC} sudo权限不可用"
    fi
    
    # 检查目录权限
    local dirs=("$CONFIGS_DIR" "$LOGS_DIR" "$BACKUPS_DIR" "$TEMPLATES_DIR")
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" ]]; then
                echo -e "  ${GREEN}✓${NC} 目录可写: $dir"
            else
                echo -e "  ${RED}✗${NC} 目录不可写: $dir"
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} 目录不存在: $dir"
        fi
    done
    
    echo ""
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用..."
    
    local ports=("$DEFAULT_HTTP_PORT" "$DEFAULT_SOCKS_PORT" "9090")
    local port_names=("HTTP代理" "SOCKS5代理" "API控制")
    
    echo ""
    echo -e "${WHITE}端口检查:${NC}"
    
    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${port_names[$i]}"
        
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "  ${RED}✗${NC} $name端口 ($port): 已占用"
        else
            echo -e "  ${GREEN}✓${NC} $name端口 ($port): 可用"
        fi
    done
    
    echo ""
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    
    echo ""
    echo -e "${WHITE}网络检查:${NC}"
    
    # 测试外网连接
    if curl -s --connect-timeout 5 https://www.baidu.com > /dev/null; then
        echo -e "  ${GREEN}✓${NC} 外网连接: 正常"
    else
        echo -e "  ${RED}✗${NC} 外网连接: 失败"
    fi
    
    # 测试DNS解析
    if nslookup baidu.com > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} DNS解析: 正常"
    else
        echo -e "  ${RED}✗${NC} DNS解析: 失败"
    fi
    
    # 获取公网IP
    local public_ip=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null)
    if [[ -n "$public_ip" ]]; then
        echo -e "  ${GREEN}✓${NC} 公网IP: $public_ip"
    else
        echo -e "  ${YELLOW}⚠${NC} 公网IP: 无法获取"
    fi
    
    echo ""
}

# 综合系统检查
check_system() {
    log_info "执行系统检查..."
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}系统检查报告${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    check_os
    check_dependencies
    check_permissions
    check_ports
    check_network
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    log_success "系统检查完成"
}

# ============================================================================
# 系统信息函数
# ============================================================================

# 获取系统信息
get_system_info() {
    echo "操作系统: $(uname -s)"
    echo "内核版本: $(uname -r)"
    echo "系统架构: $(uname -m)"
    echo "主机名: $(hostname)"
    echo "用户: $(whoami)"
}

# 检查是否为root用户
is_root() {
    [[ $EUID -eq 0 ]]
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 获取CPU核心数
get_cpu_cores() {
    nproc
}

# 获取内存信息
get_memory_info() {
    free -h | awk '/^Mem:/ {print $2}'
}

# 获取磁盘使用情况
get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}'
}

# ============================================================================
# 网络测试函数
# ============================================================================

# 测试网络连接
test_network_connection() {
    local target=${1:-"https://www.baidu.com"}
    local timeout=${2:-5}
    
    if curl -s --connect-timeout "$timeout" "$target" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# 测试网络延迟
test_network_latency() {
    local target=${1:-"baidu.com"}
    local count=${2:-4}
    
    log_info "测试网络延迟: $target"
    
    echo ""
    echo -e "${WHITE}延迟测试结果:${NC}"
    
    # 使用ping测试延迟
    if command -v ping &> /dev/null; then
        local result=$(ping -c "$count" "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
        if [[ -n "$result" ]]; then
            echo -e "  平均延迟: ${GREEN}${result}ms${NC}"
        else
            echo -e "  ${RED}延迟测试失败${NC}"
        fi
    else
        echo -e "  ${YELLOW}ping命令不可用${NC}"
    fi
    
    echo ""
}

# 测试代理延迟
test_proxy_latency() {
    local proxy_type=${1:-"socks5"}
    local proxy_host=${2:-"127.0.0.1"}
    local proxy_port=${3:-"$DEFAULT_SOCKS_PORT"}
    local target=${4:-"https://httpbin.org/ip"}
    
    log_info "测试代理延迟..."
    
    echo ""
    echo -e "${WHITE}代理延迟测试:${NC}"
    echo "  代理类型: $proxy_type"
    echo "  代理地址: $proxy_host:$proxy_port"
    echo "  测试目标: $target"
    
    local start_time=$(date +%s%N)
    
    if [[ "$proxy_type" == "socks5" ]]; then
        curl -s --connect-timeout 10 --socks5 "$proxy_host:$proxy_port" "$target" > /dev/null
    else
        curl -s --connect-timeout 10 --proxy "http://$proxy_host:$proxy_port" "$target" > /dev/null
    fi
    
    local end_time=$(date +%s%N)
    local latency=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $? -eq 0 ]]; then
        echo -e "  ${GREEN}代理连接成功${NC}"
        echo -e "  延迟: ${GREEN}${latency}ms${NC}"
    else
        echo -e "  ${RED}代理连接失败${NC}"
    fi
    
    echo ""
}

# 测试节点延迟
test_node_latency() {
    local node_name=$1
    local node_address=$2
    local node_port=$3
    
    if [[ -z "$node_name" || -z "$node_address" ]]; then
        log_error "节点信息不完整"
        return 1
    fi
    
    log_info "测试节点: $node_name"
    
    echo ""
    echo -e "${WHITE}节点测试:${NC}"
    echo "  节点名称: $node_name"
    echo "  节点地址: $node_address"
    echo "  节点端口: $node_port"
    
    # 测试TCP连接
    if timeout 5 bash -c "echo > /dev/tcp/$node_address/$node_port" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} TCP连接成功"
        
        # 测试延迟
        local start_time=$(date +%s%N)
        timeout 5 bash -c "echo > /dev/tcp/$node_address/$node_port" 2>/dev/null
        local end_time=$(date +%s%N)
        local latency=$(( (end_time - start_time) / 1000000 ))
        
        echo -e "  延迟: ${GREEN}${latency}ms${NC}"
    else
        echo -e "  ${RED}✗${NC} TCP连接失败"
    fi
    
    echo ""
}

# 测试代理速度
test_proxy_speed() {
    local proxy_type=${1:-"socks5"}
    local proxy_host=${2:-"127.0.0.1"}
    local proxy_port=${3:-"$DEFAULT_SOCKS_PORT"}
    local test_url=${4:-"https://httpbin.org/bytes/102400"}
    
    log_info "测试代理速度..."
    
    echo ""
    echo -e "${WHITE}速度测试:${NC}"
    echo "  测试文件: 100KB"
    
    local start_time=$(date +%s%N)
    
    if [[ "$proxy_type" == "socks5" ]]; then
        curl -s --socks5 "$proxy_host:$proxy_port" -o /dev/null "$test_url"
    else
        curl -s --proxy "http://$proxy_host:$proxy_port" -o /dev/null "$test_url"
    fi
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $? -eq 0 ]]; then
        local speed=$(( 100000 / duration ))
        echo -e "  ${GREEN}下载成功${NC}"
        echo -e "  耗时: ${duration}ms"
        echo -e "  速度: ${GREEN}${speed} KB/s${NC}"
    else
        echo -e "  ${RED}下载失败${NC}"
    fi
    
    echo ""
}

# 批量测试节点
test_nodes_batch() {
    local config_file="${CONFIGS_DIR}/config.yaml"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    log_info "批量测试节点..."
    
    echo ""
    echo -e "${WHITE}节点测试报告:${NC}"
    echo ""
    
    # 提取节点信息
    local nodes=$(grep -E "^[a-zA-Z0-9_-]+:" "$config_file" | head -10)
    
    if [[ -z "$nodes" ]]; then
        echo -e "  ${YELLOW}未找到节点配置${NC}"
    else
        echo "  测试节点..."
    fi
    
    echo ""
}

# ============================================================================
# 用户交互函数
# ============================================================================

# 确认操作
confirm() {
    local message=$1
    local default=${2:-n}
    
    if [[ "$default" == "y" ]]; then
        read -p "$message (Y/n): " response
        response=${response:-y}
    else
        read -p "$message (y/N): " response
        response=${response:-n}
    fi
    
    [[ "$response" == "y" || "$response" == "Y" ]]
}

# 选择菜单
select_option() {
    local prompt=$1
    shift
    local options=("$@")
    
    echo "$prompt"
    PS3="请选择: "
    
    select option in "${options[@]}"; do
        if [[ -n "$option" ]]; then
            echo "$option"
            return 0
        else
            echo "无效选择，请重新选择"
        fi
    done
}

# 输入验证
validate_input() {
    local input=$1
    local pattern=$2
    local message=$3
    
    if [[ "$input" =~ $pattern ]]; then
        return 0
    else
        log_error "$message"
        return 1
    fi
}

# ============================================================================
# 配置处理函数
# ============================================================================

# 读取配置文件
read_config() {
    local config_file=$1
    local key=$2
    
    if [[ -f "$config_file" ]]; then
        grep "^${key}=" "$config_file" | cut -d'=' -f2-
    else
        log_error "配置文件不存在: $config_file"
        return 1
    fi
}

# 写入配置文件
write_config() {
    local config_file=$1
    local key=$2
    local value=$3
    
    if [[ -f "$config_file" ]]; then
        if grep -q "^${key}=" "$config_file"; then
            sed -i "s/^${key}=.*/${key}=${value}/" "$config_file"
        else
            echo "${key}=${value}" >> "$config_file"
        fi
        return 0
    else
        log_error "配置文件不存在: $config_file"
        return 1
    fi
}

# ============================================================================
# 日志和调试函数
# ============================================================================

# 记录日志
log_to_file() {
    local level=$1
    local message=$2
    local log_file="${LOGS_DIR:-./logs}/mihomo-quick.log"
    
    mkdir -p "$(dirname "$log_file")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$log_file"
}

# 调试信息
debug_info() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
        log_to_file "DEBUG" "$1"
    fi
}

# ============================================================================
# 进度显示函数
# ============================================================================

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" "" | tr ' ' '='
    printf "%${empty}s" "" | tr ' ' '-'
    printf "] %d%%" "$percentage"
}

# 完成进度
finish_progress() {
    printf "\n"
}

# ============================================================================
# 测试函数
# ============================================================================

# 运行测试
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -n "测试 $test_name: "
    
    if eval "$test_command" &> /dev/null; then
        echo -e "${GREEN}通过${NC}"
        return 0
    else
        echo -e "${RED}失败${NC}"
        return 1
    fi
}

# 批量运行测试
run_tests() {
    local tests=("$@")
    local passed=0
    local failed=0
    
    for test in "${tests[@]}"; do
        if run_test "$test" "true"; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    echo ""
    echo "测试结果: 通过 $passed, 失败 $failed"
    
    [[ $failed -eq 0 ]]
}

echo "✓ 已加载工具函数库: utils.sh"
