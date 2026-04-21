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
# 系统函数
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
