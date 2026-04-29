#!/bin/bash
# install.sh - mihomo-quick 一键安装脚本
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

DEFAULT_INSTALL_DIR="$HOME/.mihomo-quick"
DEFAULT_CONFIG_DIR="$HOME/.config/mihomo"

INSTALL_DIR="${1:-$DEFAULT_INSTALL_DIR}"
CONFIG_DIR="$DEFAULT_CONFIG_DIR"
MIHOMO_BIN="$HOME/.local/bin/mihomo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   mihomo-quick 安装程序                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ===== 1. 安装 mihomo =====
install_mihomo() {
    if [ -f "$MIHOMO_BIN" ]; then
        echo -e "${YELLOW}⚠️  mihomo 已存在: $MIHOMO_BIN${NC}"
        read -p "是否重新安装？ [y/N]: " yn
        [[ "$yn" =~ ^[Yy]$ ]] || return 0
    fi

    echo "📥 下载 mihomo..."
    mkdir -p "$(dirname "$MIHOMO_BIN")"

    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) echo -e "${RED}❌ 不支持的架构: $ARCH${NC}"; exit 1 ;;
    esac

    VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$VERSION" ]; then
        echo -e "${RED}❌ 无法获取版本号${NC}"
        exit 1
    fi
    echo "   版本: $VERSION ($ARCH)"

    URL="https://github.com/MetaCubeX/mihomo/releases/download/$VERSION/mihomo-linux-${ARCH}-${VERSION}.gz"
    TEMP="/tmp/mihomo.gz"
    MIRRORS=("https://ghfast.top" "https://gh-proxy.com" "")

    OK=false
    for mirror in "${MIRRORS[@]}"; do
        FULL="${mirror:+$mirror/}$URL"
        echo "   尝试: ${FULL:0:70}..."
        if curl -sL --connect-timeout 10 --max-time 120 -o "$TEMP" "$FULL" && [ -s "$TEMP" ]; then
            OK=true; break
        fi
    done

    if [ "$OK" != "true" ]; then
        echo -e "${RED}❌ 下载失败${NC}"
        exit 1
    fi

    gunzip -c "$TEMP" > "$MIHOMO_BIN"
    chmod +x "$MIHOMO_BIN"
    rm -f "$TEMP"
    echo -e "${GREEN}✅ mihomo 已安装: $MIHOMO_BIN${NC}"
}

# ===== 2. 安装 MetaCubeXD 面板 =====
install_dashboard() {
    local dash_dir="$CONFIG_DIR/dashboard"
    if [ -f "$dash_dir/index.html" ]; then
        echo -e "${YELLOW}⚠️  MetaCubeXD 已存在，跳过${NC}"
        return 0
    fi

    echo "📥 下载 MetaCubeXD 面板..."
    mkdir -p "$dash_dir"

    VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/metacubexd/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    [ -z "$VERSION" ] && { echo -e "${YELLOW}⚠️  跳过面板安装${NC}"; return 0; }

    URL="https://github.com/MetaCubeX/metacubexd/releases/download/$VERSION/compressed-dist.tgz"
    TEMP="/tmp/metacubexd.tgz"
    MIRRORS=("https://ghfast.top" "https://gh-proxy.com" "")

    OK=false
    for mirror in "${MIRRORS[@]}"; do
        FULL="${mirror:+$mirror/}$URL"
        if curl -sL --connect-timeout 10 --max-time 120 -o "$TEMP" "$FULL" && [ -s "$TEMP" ]; then
            OK=true; break
        fi
    done

    if [ "$OK" = "true" ] && tar -xzf "$TEMP" -C "$dash_dir" 2>/dev/null; then
        echo -e "${GREEN}✅ MetaCubeXD 已安装${NC}"
    else
        echo -e "${YELLOW}⚠️  面板安装失败，可稍后手动安装${NC}"
    fi
    rm -f "$TEMP"
}

# ===== 3. 复制脚本并创建符号链接 =====
install_scripts() {
    echo "📁 安装脚本..."
    mkdir -p "$HOME/.local/bin"

    local scripts=(
        scripts/mihomo-start mihomo-start
        scripts/mihomo-stop mihomo-stop
        scripts/mihomo-check mihomo-check
        scripts/mihomo-rollback mihomo-rollback
        scripts/mihomo-logs mihomo-logs
        scripts/mihomo-add-sub mihomo-add-sub
        scripts/mihomo-rules mihomo-rules
        scripts/set-proxy-env set-proxy-env
        scripts/proxy-env proxy-env
        scripts/test-all-proxy test-all-proxy
    )

    for ((i=0; i<${#scripts[@]}; i+=2)); do
        local src="${scripts[$i]}"
        local name="${scripts[$i+1]}"
        if [ -f "$SCRIPT_DIR/$src" ]; then
            cp "$SCRIPT_DIR/$src" "$HOME/.local/bin/$name"
            chmod +x "$HOME/.local/bin/$name"
        fi
    done

    # 卸载脚本
    cp "$SCRIPT_DIR/scripts/uninstall.sh" "$HOME/.local/bin/mihomo-uninstall" 2>/dev/null
    chmod +x "$HOME/.local/bin/mihomo-uninstall" 2>/dev/null

    echo -e "${GREEN}✅ 脚本已安装到 ~/.local/bin/${NC}"
}

# ===== 4. 创建配置 =====
install_config() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/providers"
    mkdir -p "$CONFIG_DIR/backups"

    if [ -f "$CONFIG_DIR/config.yaml" ]; then
        echo -e "${YELLOW}⚠️  配置文件已存在，跳过${NC}"
        echo "   如需覆盖: cp config/config.yaml $CONFIG_DIR/config.yaml"
    else
        cp "$SCRIPT_DIR/config/config.yaml" "$CONFIG_DIR/config.yaml"
        echo -e "${GREEN}✅ 配置文件已创建: $CONFIG_DIR/config.yaml${NC}"
    fi

    # 复制 geoip 数据
    if [ -f "$SCRIPT_DIR/config/geoip.metadb" ] && [ ! -f "$CONFIG_DIR/geoip.metadb" ]; then
        cp "$SCRIPT_DIR/config/geoip.metadb" "$CONFIG_DIR/geoip.metadb"
    fi
}

# ===== 5. 创建 systemd 服务 =====
install_service() {
    echo "🔧 配置 systemd 服务..."

    local service_file="$SCRIPT_DIR/systemd/mihomo.service"
    local target="/etc/systemd/system/mihomo.service"

    if [ -f "$target" ]; then
        echo -e "${YELLOW}⚠️  服务已存在${NC}"
        read -p "是否覆盖？ [y/N]: " yn
        [[ "$yn" =~ ^[Yy]$ ]] || return 0
    fi

    sudo cp "$service_file" "$target"
    sudo systemctl daemon-reload
    echo -e "${GREEN}✅ systemd 服务已创建${NC}"
    echo "   普通模式: sudo systemctl start mihomo"
    echo "   TUN模式: sudo cp systemd/mihomo-tun.service /etc/systemd/system/"
}

# ===== 6. 环境变量提示 =====
setup_env() {
    echo ""
    echo -e "${WHITE}📋 环境变量配置:${NC}"
    echo "   把以下内容追加到 ~/.bashrc："
    echo ""
    echo "   source ~/.local/bin/set-proxy-env"
    echo ""
    echo "   或者直接执行:"
    echo "   cat bashrc-snippet.sh >> ~/.bashrc"
}

# ===== 主流程 =====
echo ""
echo -e "${WHITE}安装配置:${NC}"
echo "  mihomo: $MIHOMO_BIN"
echo "  配置:   $CONFIG_DIR/config.yaml"
echo "  脚本:   ~/.local/bin/"
echo ""
read -p "开始安装？ [Y/n]: " confirm
[[ "${confirm:-y}" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

echo ""
install_mihomo
echo ""
install_dashboard
echo ""
install_scripts
echo ""
install_config
echo ""
install_service
echo ""
setup_env

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                      安装完成！                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}快速开始:${NC}"
echo "  1. source ~/.bashrc           # 加载代理环境"
echo "  2. sudo systemctl start mihomo  # 启动服务"
echo "  3. mihomo-add-sub             # 添加订阅"
echo "  4. proxy-test                 # 测试代理"
echo ""
echo -e "${WHITE}命令速查:${NC}"
echo "  proxy-start/stop/restart/status  启停管理"
echo "  mihomo-add-sub                   添加订阅"
echo "  mihomo-rules                     管理规则"
echo "  mihomo-check                     校验配置"
echo "  mihomo-rollback                  配置回滚"
echo "  mihomo-logs                      查看日志"
echo "  proxy-test                       综合测试"
echo ""
