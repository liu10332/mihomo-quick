#!/bin/bash
# uninstall.sh - 卸载 mihomo-quick

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   卸载 mihomo-quick                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

read -p "确认卸载？ [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

echo ""

# 停止服务
echo "🛑 停止 mihomo..."
if systemctl is-active --quiet mihomo.service 2>/dev/null; then
    sudo systemctl stop mihomo.service
fi
if systemctl is-active --quiet mihomo-tun.service 2>/dev/null; then
    sudo systemctl stop mihomo-tun.service
fi
if [ -f "$HOME/.cache/mihomo/mihomo.pid" ]; then
    PID=$(cat "$HOME/.cache/mihomo/mihomo.pid")
    kill "$PID" 2>/dev/null
    rm -f "$HOME/.cache/mihomo/mihomo.pid"
fi
echo "  ✅ 已停止"

# 删除 systemd 服务
echo "🗑️  删除 systemd 服务..."
sudo systemctl disable mihomo.service 2>/dev/null
sudo systemctl disable mihomo-tun.service 2>/dev/null
sudo rm -f /etc/systemd/system/mihomo.service
sudo rm -f /etc/systemd/system/mihomo-tun.service
sudo systemctl daemon-reload
echo "  ✅ 已删除"

# 删除脚本
echo "🗑️  删除脚本..."
rm -f "$HOME/.local/bin/mihomo"
rm -f "$HOME/.local/bin/mihomo-start"
rm -f "$HOME/.local/bin/mihomo-stop"
rm -f "$HOME/.local/bin/mihomo-check"
rm -f "$HOME/.local/bin/mihomo-rollback"
rm -f "$HOME/.local/bin/mihomo-logs"
rm -f "$HOME/.local/bin/mihomo-add-sub"
rm -f "$HOME/.local/bin/mihomo-rules"
rm -f "$HOME/.local/bin/mihomo-update"
rm -f "$HOME/.local/bin/mihomo-uninstall"
rm -f "$HOME/.local/bin/set-proxy-env"
rm -f "$HOME/.local/bin/proxy-env"
rm -f "$HOME/.local/bin/test-all-proxy"
# 清理旧备份目录
rm -rf "$HOME/.local/bin/.mihomo-quick-backup."*
echo "  ✅ 已删除"

# 可选删除配置
echo ""
read -p "是否删除配置文件 (~/.config/mihomo)？ [y/N]: " del_config
[[ "$del_config" =~ ^[Yy]$ ]] && rm -rf "$HOME/.config/mihomo" && echo "  ✅ 配置已删除" || echo "  ⏭️  配置已保留"

# 可选删除二进制
read -p "是否删除 mihomo 二进制 (~/.local/bin/mihomo-core)？ [y/N]: " del_bin
[[ "$del_bin" =~ ^[Yy]$ ]] && rm -f "$HOME/.local/bin/mihomo-core" && rm -f "$HOME/.local/bin/mihomo-core.bak" && echo "  ✅ 二进制已删除" || echo "  ⏭️  二进制已保留"

# 可选删除缓存
read -p "是否删除缓存 (~/.cache/mihomo)？ [y/N]: " del_cache
[[ "$del_cache" =~ ^[Yy]$ ]] && rm -rf "$HOME/.cache/mihomo" && echo "  ✅ 缓存已删除" || echo "  ⏭️  缓存已保留"

echo ""
echo -e "${GREEN}✅ 卸载完成${NC}"
