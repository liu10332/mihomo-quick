#!/bin/bash
# detect.sh - mihomo-quick 系统检测函数库

# 防止重复加载
[[ -n "${_DETECT_SH_LOADED:-}" ]] && return 0
_DETECT_SH_LOADED=1

# 引入公共函数
_DETECT_LIB_DIR="${BASH_SOURCE[0]%/*}"
source "$_DETECT_LIB_DIR/common.sh"

# ===== 架构检测 =====

detect_arch() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7*|armhf)
            echo "armv7"
            ;;
        i386|i486|i586|i686)
            echo "386"
            ;;
        *)
            log_error "不支持的架构: $arch"
            return 1
            ;;
    esac
}

# ===== 发行版检测 =====

detect_distro() {
    local distro="unknown"

    if [[ -f /etc/os-release ]]; then
        local id
        id=$(. /etc/os-release && echo "$ID")

        case "$id" in
            ubuntu)
                distro="ubuntu"
                ;;
            debian)
                distro="debian"
                ;;
            centos|rhel|rocky|almalinux)
                distro="centos"
                ;;
            arch|manjaro)
                distro="arch"
                ;;
            *)
                distro="unknown"
                ;;
        esac
    fi

    echo "$distro"
}

detect_distro_name() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${PRETTY_NAME:-${NAME:-${DISTRIB_DESCRIPTION:-Unknown Linux}}}"
    else
        echo "Unknown Linux"
    fi
}

# ===== TUN 设备检测 =====

detect_tun_device() {
    # 尝试常见 TUN 设备名
    local candidates=("tun0" "tun1" "utun0" "utun1" "tap0")

    for dev in "${candidates[@]}"; do
        if [[ -d "/sys/class/net/$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done

    # 检查是否有任何 TUN 设备
    for dev in /sys/class/net/tun*; do
        if [[ -d "$dev" ]]; then
            basename "$dev"
            return 0
        fi
    done

    # 默认返回 tun0
    echo "tun0"
}

# ===== 端口检测 =====

check_port_available() {
    local port="$1"

    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        return 1
    fi

    # 检查端口是否被占用
    if command -v ss &>/dev/null; then
        ! ss -tlnp | grep -q ":${port} "
    elif command -v netstat &>/dev/null; then
        ! netstat -tlnp | grep -q ":${port} "
    else
        # 简单回退：尝试连接
        ! (echo >/dev/tcp/127.0.0.1/$port) 2>/dev/null
    fi
}

find_available_port() {
    local preferred="${1:-7890}"
    local max_attempts="${2:-100}"

    for ((i=0; i<max_attempts; i++)); do
        local port=$((preferred + i))
        if check_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done

    log_error "未找到可用端口（从 $preferred 开始尝试了 $max_attempts 个端口）"
    return 1
}

# ===== 依赖检查 =====

check_dependencies() {
    local missing=()

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少以下命令: ${missing[*]}"
        return 1
    fi

    return 0
}

# ===== 用户检测 =====

detect_current_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        whoami
    fi
}

is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

get_service_user() {
    # 优先使用当前用户（非 root）
    if ! is_root; then
        detect_current_user
        return 0
    fi

    # root 用户时，查找合适的非 root 用户
    local candidates=("mihomo" "proxy" "nobody")

    for user in "${candidates[@]}"; do
        if id "$user" &>/dev/null; then
            echo "$user"
            return 0
        fi
    done

    # 默认使用 nobody
    echo "nobody"
}
