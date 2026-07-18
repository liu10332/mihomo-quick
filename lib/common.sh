#!/bin/bash
# common.sh - mihomo-quick 公共函数库
# 所有脚本通过 source lib/common.sh 引入

# 防止重复加载
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

# ===== 颜色变量 =====
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    CYAN=''
    WHITE=''
    BLUE=''
    NC=''
fi

# ===== 日志函数 =====

log_info() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

log_step() {
    echo -e "${CYAN}📋 $*${NC}"
}

log_title() {
    echo ""
    echo -e "${WHITE}$*${NC}"
    echo ""
}

# ===== 错误处理 =====

die() {
    log_error "$@"
    exit 1
}

# ===== 确认函数 =====

# confirm "提示" [默认值: y/n]
# 返回 0 表示确认，1 表示取消
confirm() {
    local prompt="${1:-继续?}"
    local default="${2:-y}"

    local hint
    if [[ "$default" == "y" ]]; then
        hint="Y/n"
    else
        hint="y/N"
    fi

    read -r -p "   $prompt [$hint]: " answer || true
    answer="${answer:-$default}"

    [[ "$answer" =~ ^[Yy]$ ]]
}

# ===== 备份函数 =====

# backup_file "文件路径"
# 备份文件到同目录下 .bak.YYYYMMDDHHMMSS 后缀
backup_file() {
    local file="$1"

    if [[ -f "$file" ]]; then
        local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        log_info "已备份: $backup"
        return 0
    fi

    return 1
}

# ===== 进度显示 =====

# show_progress 当前值 总值 [前缀]
show_progress() {
    local current="$1"
    local total="$2"
    local prefix="${3:-}"

    if [[ "$total" -le 0 ]]; then
        return
    fi

    local percent=$(( current * 100 / total ))
    local filled=$(( current * 20 / total ))
    local empty=$(( 20 - filled ))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    printf "\r   %s [%s] %3d%%" "$prefix" "$bar" "$percent"

    if [[ "$current" -ge "$total" ]]; then
        echo ""
    fi
}
