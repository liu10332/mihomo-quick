#!/bin/bash
# setup-service.sh - 快捷创建并启用 mihomo systemd 开机自启服务
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 加载函数库: 优先仓库位置(SCRIPT_DIR/lib)，回退安装位置(~/.mihomo-quick/lib)
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    _LIB_DIR="$SCRIPT_DIR/lib"
elif [[ -f "$HOME/.mihomo-quick/lib/common.sh" ]]; then
    _LIB_DIR="$HOME/.mihomo-quick/lib"
else
    echo "❌ 找不到函数库 (lib/common.sh)，请先运行 install.sh" >&2
    exit 1
fi
source "$_LIB_DIR/common.sh"
source "$_LIB_DIR/detect.sh"
source "$_LIB_DIR/service.sh"

SERVICE_MODE="${1:-normal}"  # normal | tun

log_step "mihomo systemd 服务安装"

# 选择服务模式
if [ "$SERVICE_MODE" = "tun" ]; then
    SERVICE_NAME="$SERVICE_NAME_TUN"
    log_step "模式: TUN (透明代理)"
else
    SERVICE_NAME="$SERVICE_NAME_MIHOMO"
    log_step "模式: 普通 (HTTP/SOCKS5)"
fi

# 安装服务（使用 lib/service.sh）
install_service "$SERVICE_MODE"

# 询问是否立即启动
if confirm "是否立即启动服务？" "y"; then
    start_service "$SERVICE_NAME"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | head -10
    else
        log_error "启动失败，查看日志:"
        echo "   journalctl -u $SERVICE_NAME -n 20 --no-pager"
    fi
fi

log_title "常用命令"
echo "   systemctl start $SERVICE_NAME     # 启动"
echo "   systemctl stop $SERVICE_NAME      # 停止"
echo "   systemctl restart $SERVICE_NAME   # 重启"
echo "   systemctl status $SERVICE_NAME    # 状态"
echo "   journalctl -u $SERVICE_NAME -f    # 实时日志"
echo ""
log_step "切换模式"
echo "   $SCRIPT_DIR/setup-service.sh       # 普通模式"
echo "   $SCRIPT_DIR/setup-service.sh tun   # TUN 模式"
