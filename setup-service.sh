#!/bin/bash
# setup-service.sh - 快捷创建并启用 mihomo systemd 开机自启服务
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_MODE="${1:-normal}"  # normal | tun

echo -e "${CYAN}🔧 mihomo systemd 服务安装${NC}"
echo ""

# 检查 systemd 是否可用
if ! command -v systemctl &>/dev/null; then
    echo -e "${RED}❌ systemctl 不可用，当前系统可能未使用 systemd${NC}"
    exit 1
fi

# 选择服务文件
if [ "$SERVICE_MODE" = "tun" ]; then
    SERVICE_FILE="$SCRIPT_DIR/systemd/mihomo-tun.service"
    SERVICE_NAME="mihomo-tun"
    echo -e "${YELLOW}📡 模式: TUN (透明代理)${NC}"
else
    SERVICE_FILE="$SCRIPT_DIR/systemd/mihomo.service"
    SERVICE_NAME="mihomo"
    echo -e "📡 模式: 普通 (HTTP/SOCKS5)"
fi

if [ ! -f "$SERVICE_FILE" ]; then
    echo -e "${RED}❌ 服务文件不存在: $SERVICE_FILE${NC}"
    exit 1
fi

TARGET="/etc/systemd/system/${SERVICE_NAME}.service"

# 检查是否已存在
if [ -f "$TARGET" ]; then
    echo -e "${YELLOW}⚠️  服务已存在: $TARGET${NC}"
    read -p "是否覆盖？ [y/N]: " yn || true
    [[ "$yn" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }
fi

# 检查 mihomo 二进制
MIHOMO_BIN="$HOME/.local/bin/mihomo-core"
if [ ! -x "$MIHOMO_BIN" ]; then
    echo -e "${YELLOW}⚠️  未找到 mihomo: $MIHOMO_BIN${NC}"
    echo "   请先确保 mihomo 已安装到该路径"
    read -p "继续？ [y/N]: " yn || true
    [[ "$yn" =~ ^[Yy]$ ]] || exit 1
fi

# 安装服务（动态替换路径）
sed "s|/root|$HOME|g" "$SERVICE_FILE" | sudo tee "$TARGET" > /dev/null
sudo systemctl daemon-reload
echo -e "${GREEN}✅ 服务已创建: $TARGET${NC}"

# 启用开机自启
sudo systemctl enable "$SERVICE_NAME"
echo -e "${GREEN}✅ 已设置开机自启${NC}"

# 询问是否立即启动
read -p "是否立即启动服务？ [Y/n]: " yn || true
if [[ ! "$yn" =~ ^[Nn]$ ]]; then
    sudo systemctl start "$SERVICE_NAME"
    sleep 1
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✅ 服务已启动${NC}"
        systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | head -10
    else
        echo -e "${RED}❌ 启动失败，查看日志:${NC}"
        echo "   journalctl -u $SERVICE_NAME -n 20 --no-pager"
    fi
fi

echo ""
echo -e "${CYAN}📋 常用命令:${NC}"
echo "   systemctl start $SERVICE_NAME     # 启动"
echo "   systemctl stop $SERVICE_NAME      # 停止"
echo "   systemctl restart $SERVICE_NAME   # 重启"
echo "   systemctl status $SERVICE_NAME    # 状态"
echo "   journalctl -u $SERVICE_NAME -f    # 实时日志"
echo ""
echo -e "${CYAN}🔄 切换模式:${NC}"
echo "   $SCRIPT_DIR/setup-service.sh       # 普通模式"
echo "   $SCRIPT_DIR/setup-service.sh tun   # TUN 模式"
