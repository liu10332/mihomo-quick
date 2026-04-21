#!/bin/bash
#
# mihomo-quick 安装脚本
# 轻量级mihomo快速部署工具
#
# 用法: ./install.sh [选项]
# 选项:
#   -d, --dir DIR        安装目录 (默认: ~/.mihomo-quick)
#   -c, --config DIR     配置目录 (默认: ~/.config/mihomo)
#   -m, --mode MODE      代理模式 (tun/system/tap/mixed)
#   -s, --sub URL        订阅URL
#   -p, --port PORT      HTTP端口 (默认: 7890)
#   -h, --help           显示帮助
#

set -e

# ============================================================================
# 配置变量
# ============================================================================

# 默认配置
DEFAULT_INSTALL_DIR="$HOME/.mihomo-quick"
DEFAULT_CONFIG_DIR="$HOME/.config/mihomo"
DEFAULT_MODE="tun"
DEFAULT_HTTP_PORT=7890
DEFAULT_SOCKS_PORT=7891

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
mihomo-quick 安装脚本

用法: $0 [选项]

选项:
  -d, --dir DIR        安装目录 (默认: $DEFAULT_INSTALL_DIR)
  -c, --config DIR     配置目录 (默认: $DEFAULT_CONFIG_DIR)
  -m, --mode MODE      代理模式 (tun/system/tap/mixed)
  -s, --sub URL        订阅URL
  -p, --port PORT      HTTP端口 (默认: $DEFAULT_HTTP_PORT)
  -h, --help           显示帮助

示例:
  $0                                    # 默认安装
  $0 -d /opt/mihomo-quick               # 自定义安装目录
  $0 -m tun -p 8080                     # TUN模式，端口8080
  $0 -s "https://example.com/sub"       # 使用订阅

EOF
}

# ============================================================================
# 检查函数
# ============================================================================

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local deps=("curl" "tar" "systemctl" "ip" "grep" "sed" "awk")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        log_info "请先安装缺少的依赖"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 检查权限
check_permissions() {
    log_info "检查安装权限..."
    
    # 检查安装目录权限
    local install_parent=$(dirname "$INSTALL_DIR")
    if [[ ! -w "$install_parent" ]]; then
        log_error "安装目录不可写: $install_parent"
        exit 1
    fi
    
    # 检查配置目录权限
    local config_parent=$(dirname "$CONFIG_DIR")
    if [[ ! -w "$config_parent" ]]; then
        log_error "配置目录不可写: $config_parent"
        exit 1
    fi
    
    log_success "权限检查通过"
}

# ============================================================================
# 安装函数
# ============================================================================

# 下载mihomo
download_mihomo() {
    log_info "下载mihomo..."
    
    # 检查是否已安装
    if [[ -f "$INSTALL_DIR/mihomo" ]]; then
        log_warning "mihomo已存在，跳过下载"
        return 0
    fi
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 获取最新版本
    local latest_version=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z "$latest_version" ]]; then
        log_error "无法获取最新版本"
        exit 1
    fi
    
    log_info "最新版本: $latest_version"
    
    # 检测架构
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv7" ;;
        *) log_error "不支持的架构: $arch"; exit 1 ;;
    esac
    
    # 下载文件
    local download_url="https://github.com/MetaCubeX/mihomo/releases/download/$latest_version/mihomo-linux-$arch-$latest_version.gz"
    local temp_file="/tmp/mihomo.gz"
    
    log_info "下载地址: $download_url"
    
    if curl -L -o "$temp_file" "$download_url"; then
        log_success "下载完成"
    else
        log_error "下载失败"
        exit 1
    fi
    
    # 解压和安装
    log_info "解压和安装..."
    
    if gunzip -c "$temp_file" > "$INSTALL_DIR/mihomo"; then
        chmod +x "$INSTALL_DIR/mihomo"
        log_success "mihomo安装成功"
    else
        log_error "解压失败"
        exit 1
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
}

# 复制项目文件
copy_project_files() {
    log_info "复制项目文件..."
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 复制脚本文件
    cp -r . "$INSTALL_DIR/"
    
    # 设置可执行权限
    chmod +x "$INSTALL_DIR/mihomo-quick.sh"
    chmod +x "$INSTALL_DIR"/lib/*.sh
    
    log_success "项目文件复制完成"
}

# 创建配置文件
create_config() {
    log_info "创建配置文件..."
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    # 如果指定了订阅，生成配置
    if [[ -n "$SUB_URL" ]]; then
        log_info "使用订阅生成配置..."
        
        # 调用配置向导
        cd "$INSTALL_DIR"
        source lib/utils.sh
        source lib/config_wizard.sh
        
        # 设置变量
        MODE="$MODE"
        HTTP_PORT="$HTTP_PORT"
        SOCKS_PORT="$DEFAULT_SOCKS_PORT"
        PROVIDER_URL="$SUB_URL"
        
        # 生成配置
        generate_wizard_config
        
        log_success "配置文件生成完成"
    else
        # 使用默认配置
        if [[ -f "$INSTALL_DIR/templates/${MODE}.yaml.template" ]]; then
            cp "$INSTALL_DIR/templates/${MODE}.yaml.template" "$CONFIG_DIR/config.yaml"
            
            # 替换端口
            sed -i "s/{{HTTP_PORT}}/$HTTP_PORT/g" "$CONFIG_DIR/config.yaml"
            sed -i "s/{{SOCKS_PORT}}/$DEFAULT_SOCKS_PORT/g" "$CONFIG_DIR/config.yaml"
            
            log_success "默认配置文件创建完成"
        else
            log_warning "配置模板不存在，使用基础配置"
            cp "$INSTALL_DIR/templates/base.yaml.template" "$CONFIG_DIR/config.yaml"
        fi
    fi
}

# 创建systemd服务
create_service() {
    log_info "创建systemd服务..."
    
    # 获取mihomo路径
    local mihomo_bin="$INSTALL_DIR/mihomo"
    
    # 创建服务文件
    sudo tee /etc/systemd/system/mihomo-quick.service > /dev/null << EOF
[Unit]
Description=Mihomo Quick Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root

# 启动前创建TUN设备
ExecStartPre=/sbin/ip tuntap add tun0 mode tun
ExecStartPre=/sbin/ip addr add 10.0.0.1/24 dev tun0
ExecStartPre=/sbin/ip link set tun0 up

# 启动mihomo
ExecStart=$mihomo_bin -d $CONFIG_DIR

# 停止后清理TUN设备
ExecStopPost=/sbin/ip tuntap del tun0 mode tun

# 重启策略
Restart=always
RestartSec=5
TimeoutStopSec=30
TimeoutStartSec=30
SuccessExitStatus=0 143
KillMode=control-group

# 环境变量
Environment=HOME=/root
Environment=TMPDIR=/tmp
Environment=HTTP_PROXY=http://127.0.0.1:$HTTP_PORT
Environment=HTTPS_PROXY=http://127.0.0.1:$HTTP_PORT
Environment=ALL_PROXY=socks5://127.0.0.1:$DEFAULT_SOCKS_PORT
Environment=http_proxy=http://127.0.0.1:$HTTP_PORT
Environment=https_proxy=http://127.0.0.1:$HTTP_PORT
Environment=all_proxy=socks5://127.0.0.1:$DEFAULT_SOCKS_PORT
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd配置
    sudo systemctl daemon-reload
    
    log_success "systemd服务创建完成"
}

# 创建符号链接
create_symlinks() {
    log_info "创建符号链接..."
    
    # 创建符号链接到PATH目录
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    
    ln -sf "$INSTALL_DIR/mihomo-quick.sh" "$bin_dir/mihomo-quick"
    
    log_success "符号链接创建完成"
}

# ============================================================================
# 解析参数
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_DIR="$2"
                shift 2
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -s|--sub)
                SUB_URL="$2"
                shift 2
                ;;
            -p|--port)
                HTTP_PORT="$2"
                shift 2
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
    MODE="$DEFAULT_MODE"
    HTTP_PORT="$DEFAULT_HTTP_PORT"
    SUB_URL=""
    
    # 解析参数
    parse_args "$@"
    
    # 显示欢迎信息
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    mihomo-quick 安装程序                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}安装配置:${NC}"
    echo "  安装目录: $INSTALL_DIR"
    echo "  配置目录: $CONFIG_DIR"
    echo "  代理模式: $MODE"
    echo "  HTTP端口: $HTTP_PORT"
    if [[ -n "$SUB_URL" ]]; then
        echo "  订阅URL: $SUB_URL"
    fi
    echo ""
    
    # 确认安装
    read -p "确认安装? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "取消安装"
        exit 0
    fi
    
    # 执行安装步骤
    check_dependencies
    check_permissions
    download_mihomo
    copy_project_files
    create_config
    create_service
    create_symlinks
    
    # 显示安装信息
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    安装完成！                               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}安装信息:${NC}"
    echo "  mihomo路径: $INSTALL_DIR/mihomo"
    echo "  配置目录: $CONFIG_DIR"
    echo "  服务名称: mihomo-quick.service"
    echo ""
    echo -e "${WHITE}使用方法:${NC}"
    echo "  1. 启动服务: sudo systemctl start mihomo-quick"
    echo "  2. 查看状态: systemctl status mihomo-quick"
    echo "  3. 查看日志: journalctl -u mihomo-quick -f"
    echo "  4. 管理工具: $INSTALL_DIR/mihomo-quick.sh"
    echo ""
    echo -e "${WHITE}代理信息:${NC}"
    echo "  HTTP代理: http://127.0.0.1:$HTTP_PORT"
    echo "  SOCKS5代理: socks5://127.0.0.1:$DEFAULT_SOCKS_PORT"
    echo "  API控制: http://127.0.0.1:9090"
    echo ""
    echo -e "${YELLOW}提示: 请根据需要修改配置文件: $CONFIG_DIR/config.yaml${NC}"
    echo ""
}

# 运行主函数
main "$@"
