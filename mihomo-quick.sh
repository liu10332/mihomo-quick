#!/bin/bash
#
# mihomo-quick - 轻量级mihomo快速部署工具
# 版本: 1.2.0
# 作者: mihomo-quick
# 许可证: MIT
#
# 功能: 快速部署和管理mihomo代理
# 支持: TUN/System/TAP/Mixed 四种代理模式
# 特点: 轻量级、易用、灵活、稳定
#

set -e

# ============================================================================
# 基本配置
# ============================================================================

# 版本信息
VERSION="1.2.0"
AUTHOR="mihomo-quick"
LICENSE="MIT"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
CONFIGS_DIR="${HOME}/.config/mihomo"
DASHBOARD_DIR="${SCRIPT_DIR}/dashboard"
LOGS_DIR="${SCRIPT_DIR}/logs"
BACKUPS_DIR="${SCRIPT_DIR}/backups"

# 默认配置
DEFAULT_HTTP_PORT=7890
DEFAULT_SOCKS_PORT=7891
DEFAULT_TUN_DEVICE="tun0"
DEFAULT_TUN_IP="10.0.0.1"
DEFAULT_TAP_DEVICE="tap0"
DEFAULT_MODE="tun"

# ============================================================================
# 颜色定义
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

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

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# ============================================================================
# 错误处理
# ============================================================================

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command=$2
    
    log_error "脚本执行出错"
    log_error "退出码: $exit_code"
    log_error "行号: $line_number"
    log_error "命令: $command"
    
    exit $exit_code
}

# 设置错误处理
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# ============================================================================
# 工具函数
# ============================================================================

# 检查命令是否存在
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        log_error "命令不存在: $cmd"
        return 1
    fi
    return 0
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq" "tar" "systemctl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! check_command "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        log_info "请先安装缺少的依赖"
        return 1
    fi
    
    log_debug "依赖检查通过"
    return 0
}

# 检查root权限
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "检测到root权限"
        return 0
    else
        log_warning "某些操作需要root权限"
        return 1
    fi
}

# 创建目录
create_dir() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "创建目录: $dir"
    fi
}

# 检查端口占用
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        log_warning "端口 $port 已被占用"
        return 1
    fi
    return 0
}

# ============================================================================
# 模块加载
# ============================================================================

# 加载模块
load_module() {
    local module=$1
    local module_file="${LIB_DIR}/${module}.sh"
    
    if [[ -f "$module_file" ]]; then
        source "$module_file"
        log_debug "已加载模块: $module"
        return 0
    else
        log_error "模块不存在: $module"
        return 1
    fi
}

# 加载所有模块
load_all_modules() {
    log_info "加载功能模块..."
    
    # 创建lib目录（如果不存在）
    create_dir "$LIB_DIR"
    
    # 模块列表
    local modules=("utils" "config" "subscription" "subscription_config" "subscription_priority" "service" "mode" "rules")
    
    for module in "${modules[@]}"; do
        if [[ -f "${LIB_DIR}/${module}.sh" ]]; then
            load_module "$module"
        else
            log_warning "模块文件不存在: ${module}.sh"
        fi
    done
    
    log_success "模块加载完成"
}

# ============================================================================
# 菜单系统
# ============================================================================

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 mihomo-quick 管理工具                      ║"
    echo "║                    版本: $VERSION                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. 安装/卸载管理"
    echo -e "  ${GREEN}2${NC}. 代理模式管理"
    echo -e "  ${GREEN}3${NC}. 订阅管理"
    echo -e "  ${GREEN}4${NC}. 配置管理"
    echo -e "  ${GREEN}5${NC}. 服务管理"
    echo -e "  ${GREEN}6${NC}. Web面板"
    echo -e "  ${GREEN}7${NC}. 规则管理（黑白名单）"
    echo -e "  ${GREEN}8${NC}. 订阅优先级（故障转移）"
    echo -e "  ${GREEN}9${NC}. 环境变量代理"
    echo -e "  ${GREEN}10${NC}. 综合代理测试"
    echo -e "  ${GREEN}11${NC}. 系统检查"
    echo -e "  ${GREEN}12${NC}. 帮助信息"
    echo -e "  ${GREEN}0${NC}. 退出"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
}

# 安装/卸载管理菜单
show_install_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    安装/卸载管理                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}请选择操作:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}. 安装 mihomo-quick"
    echo -e "  ${GREEN}2${NC}. 卸载 mihomo-quick"
    echo -e "  ${GREEN}3${NC}. 更新 mihomo"
    echo -e "  ${GREEN}0${NC}. 返回主菜单"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    read -p "请输入选择 (0-3): " choice
    
    case $choice in
        1)
            log_info "启动安装脚本..."
            if [[ -f "${SCRIPT_DIR}/install.sh" ]]; then
                bash "${SCRIPT_DIR}/install.sh"
            else
                log_error "安装脚本不存在"
            fi
            read -p "按 Enter 键返回..."
            show_install_menu
            ;;
        2)
            log_info "启动卸载脚本..."
            if [[ -f "${SCRIPT_DIR}/uninstall.sh" ]]; then
                bash "${SCRIPT_DIR}/uninstall.sh"
            else
                log_error "卸载脚本不存在"
            fi
            read -p "按 Enter 键返回..."
            show_install_menu
            ;;
        3)
            log_info "更新 mihomo..."
            local mihomo_bin="$HOME/.mihomo-quick/mihomo"
            if [[ -f "$mihomo_bin" ]]; then
                local latest=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
                if [[ -n "$latest" ]]; then
                    local arch=$(uname -m)
                    case $arch in
                        x86_64) arch="amd64" ;;
                        aarch64) arch="arm64" ;;
                        armv7l) arch="armv7" ;;
                    esac
                    local url="https://github.com/MetaCubeX/mihomo/releases/download/$latest/mihomo-linux-$arch-$latest.gz"
                    log_info "下载 $latest ..."
                    if curl -L -o /tmp/mihomo.gz "$url" && gunzip -c /tmp/mihomo.gz > "$mihomo_bin" && chmod +x "$mihomo_bin"; then
                        log_success "更新完成: $latest"
                    else
                        log_error "更新失败"
                    fi
                    rm -f /tmp/mihomo.gz
                else
                    log_error "无法获取最新版本"
                fi
            else
                log_error "mihomo 未安装，请先执行安装"
            fi
            read -p "按 Enter 键返回..."
            show_install_menu
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            sleep 1
            show_install_menu
            ;;
    esac
}

# 处理主菜单选择
handle_main_menu() {
    local choice=$1
    
    case $choice in
        1)
            log_info "进入安装/卸载管理..."
            show_install_menu
            ;;
        2)
            log_info "进入代理模式管理..."
            load_module "mode" && show_mode_menu
            ;;
        3)
            log_info "进入订阅管理..."
            load_module "subscription" && show_subscription_menu
            ;;
        4)
            log_info "进入配置管理..."
            load_module "config" && show_config_menu
            ;;
        5)
            log_info "进入服务管理..."
            load_module "service" && show_service_menu
            ;;
        6)
            log_info "打开Web面板..."
            open_dashboard
            ;;
        7)
            log_info "进入规则管理..."
            load_module "rules" && show_rules_menu
            ;;
        8)
            log_info "进入订阅优先级管理..."
            load_module "subscription_priority" && show_priority_menu
            ;;
        9)
            log_info "环境变量代理管理..."
            manage_proxy_env
            ;;
        10)
            log_info "综合代理测试..."
            run_test_all_proxy
            ;;
        11)
            log_info "执行系统检查..."
            check_system
            ;;
        12)
            show_help
            ;;
        0)
            confirm_exit
            ;;
        *)
            log_error "无效选择: $choice"
            sleep 1
            ;;
    esac
}

# ============================================================================
# 快捷命令
# ============================================================================

# 显示帮助信息
show_help() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    mihomo-quick 帮助                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}用法:${NC}"
    echo "  ./mihomo-quick.sh [命令] [选项]"
    echo ""
    echo -e "${WHITE}命令:${NC}"
    echo "  start          启动服务"
    echo "  stop           停止服务"
    echo "  restart        重启服务"
    echo "  status         查看状态"
    echo "  config         配置向导"
    echo "  sub            订阅管理"
    echo "  mode           模式切换"
    echo "  rules          规则管理（黑白名单）"
    echo "  priority       订阅优先级（故障转移）"
    echo "  proxy-env      环境变量代理管理"
    echo "  test-all       综合代理测试"
    echo "  dashboard      打开面板"
    echo "  logs           查看日志"
    echo "  test           测试节点"
    echo "  update         更新订阅"
    echo "  help           显示帮助"
    echo "  version        显示版本"
    echo ""
    echo -e "${WHITE}选项:${NC}"
    echo "  -h, --help     显示帮助"
    echo "  -v, --version  显示版本"
    echo "  -d, --debug    调试模式"
    echo ""
    echo -e "${WHITE}示例:${NC}"
    echo "  ./mihomo-quick.sh                # 启动菜单"
    echo "  ./mihomo-quick.sh start          # 启动服务"
    echo "  ./mihomo-quick.sh config         # 配置向导"
    echo "  ./mihomo-quick.sh sub add url    # 添加订阅"
    echo "  ./mihomo-quick.sh rules add-direct DOMAIN-SUFFIX,baidu.com  # 添加直连规则"
    echo "  ./mihomo-quick.sh rules add-proxy DOMAIN-SUFFIX,openai.com  # 添加代理规则"
    echo "  ./mihomo-quick.sh priority set provider-a   # 设置主订阅"
    echo "  ./mihomo-quick.sh priority apply            # 应用优先级"
    echo "  ./mihomo-quick.sh proxy-env on              # 启用代理环境变量"
    echo "  ./mihomo-quick.sh test-all                  # 综合代理测试"
    echo ""
    echo -e "${WHITE}更多信息:${NC}"
    echo "  项目地址: https://github.com/your-username/mihomo-quick"
    echo "  使用文档: 查看 README.md"
    echo ""
    
    read -p "按 Enter 键返回主菜单..."
}

# 显示版本信息
show_version() {
    echo "mihomo-quick $VERSION"
    echo "作者: $AUTHOR"
    echo "许可证: $LICENSE"
    echo ""
    echo "轻量级mihomo快速部署工具"
    echo "支持 TUN/System/TAP/Mixed 四种代理模式"
}

# 打开Web面板
open_dashboard() {
    log_info "打开Web面板..."
    
    # 检查面板是否运行
    if systemctl is-active --quiet mihomo-quick.service; then
        local ip=$(hostname -I | awk '{print $1}')
        echo ""
        echo -e "${GREEN}Web面板地址:${NC}"
        echo -e "  http://${ip}:9090/ui"
        echo ""
        echo -e "${YELLOW}提示:${NC} 请在浏览器中打开上述地址"
        echo ""
    else
        log_warning "mihomo服务未运行"
        log_info "请先启动服务: ./mihomo-quick.sh start"
    fi
    
    read -p "按 Enter 键返回主菜单..."
}

# 系统检查
check_system() {
    log_info "执行系统检查..."
    
    echo ""
    echo -e "${WHITE}系统信息:${NC}"
    echo "  操作系统: $(uname -s)"
    echo "  内核版本: $(uname -r)"
    echo "  系统架构: $(uname -m)"
    echo "  主机名: $(hostname)"
    echo ""
    
    echo -e "${WHITE}依赖检查:${NC}"
    check_dependencies
    echo ""
    
    echo -e "${WHITE}端口检查:${NC}"
    check_port $DEFAULT_HTTP_PORT && echo "  HTTP端口 ($DEFAULT_HTTP_PORT): 可用" || echo "  HTTP端口 ($DEFAULT_HTTP_PORT): 已占用"
    check_port $DEFAULT_SOCKS_PORT && echo "  SOCKS端口 ($DEFAULT_SOCKS_PORT): 可用" || echo "  SOCKS端口 ($DEFAULT_SOCKS_PORT): 已占用"
    echo ""
    
    echo -e "${WHITE}服务状态:${NC}"
    if systemctl is-active --quiet mihomo-quick.service 2>/dev/null; then
        echo "  mihomo-quick: 运行中"
    else
        echo "  mihomo-quick: 未运行"
    fi
    echo ""
    
    read -p "按 Enter 键返回主菜单..."
}

# 确认退出
confirm_exit() {
    echo ""
    read -p "确定要退出吗? (y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        log_success "感谢使用 mihomo-quick！"
        exit 0
    fi
}

# ============================================================================
# 环境变量代理管理（集成 proxy-env.sh）
# ============================================================================

manage_proxy_env() {
    local action="$1"
    shift
    
    local proxy_env_script="${SCRIPT_DIR}/scripts/proxy-env.sh"
    
    if [[ ! -f "$proxy_env_script" ]]; then
        log_error "proxy-env.sh 脚本不存在"
        return 1
    fi
    
    case "$action" in
        on|start|off|stop|status|test|config|npm-on|npm-off)
            bash "$proxy_env_script" "$action" "$@"
            ;;
        "")
            # 交互式菜单
            clear
            echo -e "${CYAN}"
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║                  环境变量代理管理                           ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo -e "${NC}"
            echo ""
            echo -e "${WHITE}请选择操作:${NC}"
            echo ""
            echo -e "  ${GREEN}1${NC}. 启用代理环境变量"
            echo -e "  ${GREEN}2${NC}. 禁用代理环境变量"
            echo -e "  ${GREEN}3${NC}. 查看当前状态"
            echo -e "  ${GREEN}4${NC}. 测试代理连接"
            echo -e "  ${GREEN}5${NC}. 配置代理参数"
            echo -e "  ${GREEN}6${NC}. 启用 npm 代理"
            echo -e "  ${GREEN}7${NC}. 禁用 npm 代理"
            echo -e "  ${GREEN}0${NC}. 返回主菜单"
            echo ""
            echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
            
            read -p "请输入选择 (0-7): " env_choice
            
            case $env_choice in
                1) bash "$proxy_env_script" on ;;
                2) bash "$proxy_env_script" off ;;
                3) bash "$proxy_env_script" status ;;
                4) bash "$proxy_env_script" test ;;
                5) bash "$proxy_env_script" config ;;
                6) bash "$proxy_env_script" npm-on ;;
                7) bash "$proxy_env_script" npm-off ;;
                0) return ;;
                *) log_error "无效选择"; sleep 1 ;;
            esac
            
            echo ""
            read -p "按 Enter 键返回..."
            manage_proxy_env
            ;;
        *)
            log_error "未知操作: $action"
            echo "用法: mihomo-quick.sh proxy-env [on|off|status|test|config|npm-on|npm-off]"
            return 1
            ;;
    esac
}

# ============================================================================
# 综合代理测试（集成 test-all-proxy.sh）
# ============================================================================

run_test_all_proxy() {
    local test_script="${SCRIPT_DIR}/scripts/test-all-proxy.sh"
    
    if [[ ! -f "$test_script" ]]; then
        log_error "test-all-proxy.sh 脚本不存在"
        return 1
    fi
    
    bash "$test_script"
}

# ============================================================================
# 主函数
# ============================================================================

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--debug)
                DEBUG=1
                log_debug "调试模式已启用"
                shift
                ;;
            start|stop|restart|status|config|sub|mode|rules|priority|proxy-env|test-all|dashboard|logs|test|update|help|version)
                # 快捷命令
                handle_short_command "$1" "${@:2}"
                exit $?
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 处理快捷命令
handle_short_command() {
    local command=$1
    shift
    
    # 确保工具函数已加载
    source "${LIB_DIR}/utils.sh" 2>/dev/null
    
    case $command in
        start)
            log_info "启动服务..."
            load_module "service" && service_start
            ;;
        stop)
            log_info "停止服务..."
            load_module "service" && service_stop
            ;;
        restart)
            log_info "重启服务..."
            load_module "service" && service_restart
            ;;
        status)
            log_info "查看状态..."
            load_module "service" && service_status
            ;;
        config)
            log_info "配置向导..."
            load_module "config" && config_wizard
            ;;
        sub)
            log_info "订阅管理..."
            load_module "subscription" && handle_sub_command "$@"
            ;;
        mode)
            log_info "模式切换..."
            load_module "mode" && handle_mode_command "$@"
            ;;
        rules)
            log_info "规则管理..."
            load_module "rules" && handle_rules_command "$@"
            ;;
        priority)
            log_info "订阅优先级..."
            load_module "subscription_priority" && handle_priority_command "$@"
            ;;
        proxy-env)
            log_info "环境变量代理..."
            manage_proxy_env "$@"
            ;;
        test-all)
            log_info "综合代理测试..."
            run_test_all_proxy
            ;;
        dashboard)
            open_dashboard
            ;;
        logs)
            log_info "查看日志..."
            load_module "service" && service_logs
            ;;
        test)
            log_info "测试节点..."
            load_module "subscription" && subscription_test "$@"
            ;;
        update)
            log_info "更新订阅..."
            load_module "subscription" && subscription_update
            ;;
        help)
            show_help
            ;;
        version)
            show_version
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 主循环
main_loop() {
    while true; do
        show_main_menu
        read -p "请输入选择 (0-12): " choice
        handle_main_menu "$choice"
    done
}

# ============================================================================
# 主程序入口
# ============================================================================

main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 如果没有参数，显示交互式菜单
    if [[ $# -eq 0 ]]; then
        # 检查依赖
        check_dependencies
        
        # 加载模块
        load_all_modules
        
        # 进入主循环
        main_loop
    fi
}

# 运行主函数
main "$@"
