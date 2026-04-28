#!/bin/bash
#
# mihomo-quick 卸载脚本
# 轻量级mihomo快速部署工具
#
# 用法: ./uninstall.sh [选项]
# 选项:
#   -p, --purge          完全删除所有文件
#   -b, --backup         卸载前备份配置
#   -h, --help           显示帮助
#

set -e

# ============================================================================
# 配置变量
# ============================================================================

# 默认配置
DEFAULT_INSTALL_DIR="$HOME/.mihomo-quick"
DEFAULT_CONFIG_DIR="$HOME/.config/mihomo"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ============================================================================
# 日志函数
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# 帮助函数
# ============================================================================

show_help() {
    cat << EOF
mihomo-quick 卸载脚本

用法: $0 [选项]

选项:
  -p, --purge          完全删除所有文件
  -b, --backup         卸载前备份配置
  -h, --help           显示帮助

示例:
  $0                   # 卸载但保留配置
  $0 -b                # 卸载并备份配置
  $0 -p                # 完全删除所有文件

EOF
}

# ============================================================================
# 卸载函数
# ============================================================================

# 停止服务
stop_service() {
    log_info "停止服务..."
    
    # 检查服务是否存在
    if systemctl list-unit-files | grep -q "mihomo-quick.service"; then
        # 停止服务
        if systemctl is-active --quiet mihomo-quick.service; then
            if sudo systemctl stop mihomo-quick.service; then
                log_success "服务已停止"
            else
                log_error "停止服务失败"
            fi
        else
            log_info "服务未运行"
        fi
        
        # 禁用服务
        if systemctl is-enabled --quiet mihomo-quick.service; then
            if sudo systemctl disable mihomo-quick.service; then
                log_success "服务已禁用自启动"
            else
                log_error "禁用服务失败"
            fi
        else
            log_info "服务未启用自启动"
        fi
        
        # 删除服务文件
        if [[ -f "/etc/systemd/system/mihomo-quick.service" ]]; then
            if sudo rm -f "/etc/systemd/system/mihomo-quick.service"; then
                log_success "服务文件已删除"
            else
                log_error "删除服务文件失败"
            fi
        fi
        
        # 重新加载systemd配置
        sudo systemctl daemon-reload
        
    else
        log_info "服务不存在"
    fi
}

# 清理TUN设备
cleanup_tun() {
    log_info "清理TUN设备..."
    
    # 检查tun0设备是否存在
    if ip tuntap show | grep -q "tun0"; then
        if sudo ip tuntap del tun0 mode tun; then
            log_success "TUN设备已删除"
        else
            log_error "删除TUN设备失败"
        fi
    else
        log_info "TUN设备不存在"
    fi
}

# 备份配置
backup_config() {
    if [[ "$BACKUP" != "true" ]]; then
        return 0
    fi
    
    log_info "备份配置..."
    
    local backup_dir="$HOME/mihomo-quick-backup-$(date +%Y%m%d_%H%M%S)"
    
    if [[ -d "$CONFIG_DIR" ]]; then
        mkdir -p "$backup_dir"
        cp -r "$CONFIG_DIR"/* "$backup_dir/" 2>/dev/null || true
        log_success "配置已备份到: $backup_dir"
    else
        log_info "没有配置需要备份"
    fi
}

# 删除文件
remove_files() {
    log_info "删除文件..."
    
    # 删除安装目录
    if [[ -d "$INSTALL_DIR" ]]; then
        if rm -rf "$INSTALL_DIR"; then
            log_success "安装目录已删除"
        else
            log_error "删除安装目录失败"
        fi
    else
        log_info "安装目录不存在"
    fi
    
    # 删除配置目录
    if [[ "$PURGE" == "true" ]]; then
        if [[ -d "$CONFIG_DIR" ]]; then
            if rm -rf "$CONFIG_DIR"; then
                log_success "配置目录已删除"
            else
                log_error "删除配置目录失败"
            fi
        else
            log_info "配置目录不存在"
        fi
    else
        log_info "保留配置目录: $CONFIG_DIR"
    fi
    
    # 删除符号链接
    local bin_dir="$HOME/.local/bin"
    if [[ -L "$bin_dir/mihomo-quick" ]]; then
        if rm -f "$bin_dir/mihomo-quick"; then
            log_success "符号链接已删除"
        else
            log_error "删除符号链接失败"
        fi
    fi
}

# 清理环境变量
clean_environment() {
    log_info "清理环境变量..."
    
    # 检查.bashrc中的代理设置
    local bashrc="$HOME/.bashrc"
    if [[ -f "$bashrc" ]]; then
        if grep -q "mihomo" "$bashrc"; then
            log_warning "在.bashrc中找到mihomo相关配置"
            log_info "请手动检查并清理: $bashrc"
        fi
    fi
}

# ============================================================================
# 解析参数
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--purge)
                PURGE="true"
                shift
                ;;
            -b|--backup)
                BACKUP="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# 主函数
# ============================================================================

main() {
    # 默认值
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    CONFIG_DIR="$DEFAULT_CONFIG_DIR"
    PURGE="false"
    BACKUP="false"
    
    # 解析参数
    parse_args "$@"
    
    # 显示欢迎信息
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    mihomo-quick 卸载程序                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}卸载配置:${NC}"
    echo "  安装目录: $INSTALL_DIR"
    echo "  配置目录: $CONFIG_DIR"
    echo "  完全删除: $PURGE"
    echo "  备份配置: $BACKUP"
    echo ""
    
    # 确认卸载
    read -p "确认卸载? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "取消卸载"
        exit 0
    fi
    
    # 执行卸载步骤
    stop_service
    cleanup_tun
    backup_config
    remove_files
    clean_environment
    
    # 显示卸载信息
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    卸载完成！                               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}卸载信息:${NC}"
    echo "  服务: mihomo-quick.service (已停止和禁用)"
    echo "  TUN设备: tun0 (已清理)"
    echo "  安装目录: $INSTALL_DIR (已删除)"
    
    if [[ "$PURGE" == "true" ]]; then
        echo -e "  配置目录: $CONFIG_DIR (已完全删除)"
    else
        echo -e "  配置目录: $CONFIG_DIR (已保留)"
    fi
    
    if [[ "$BACKUP" == "true" ]]; then
        echo -e "  备份: 已备份到 $HOME/mihomo-quick-backup-*"
    fi
    
    echo ""
    echo -e "${YELLOW}提示: 如果需要清理环境变量，请手动检查 ~/.bashrc 和 ~/.profile${NC}"
    echo ""
}

# 运行主函数
main "$@"
