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
    mkdir -p "$(dirname "$MIHOMO_BIN")"

    # 检查是否已存在（可能用户手动放好了）
    if [ -f "$MIHOMO_BIN" ] && [ -x "$MIHOMO_BIN" ]; then
        echo -e "${GREEN}✅ mihomo 已存在: $MIHOMO_BIN${NC}"
        "$MIHOMO_BIN" -v 2>/dev/null || true
        read -p "是否重新安装？ [y/N]: " yn
        [[ "$yn" =~ ^[Yy]$ ]] || return 0
    fi

    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) echo -e "${RED}❌ 不支持的架构: $ARCH${NC}"; exit 1 ;;
    esac

    # 尝试自动下载
    echo "📥 尝试下载 mihomo..."
    VERSION=$(curl -s --connect-timeout 5 https://api.github.com/repos/MetaCubeX/mihomo/releases/latest 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -n "$VERSION" ]; then
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

        if [ "$OK" = "true" ]; then
            gunzip -c "$TEMP" > "$MIHOMO_BIN"
            chmod +x "$MIHOMO_BIN"
            rm -f "$TEMP"
            echo -e "${GREEN}✅ mihomo 已安装: $MIHOMO_BIN${NC}"
            return 0
        fi
    fi

    # 自动下载失败，提示手动下载
    echo ""
    echo -e "${YELLOW}⚠️  自动下载失败（网络问题）${NC}"
    echo ""
    echo -e "${WHITE}请手动下载 mihomo:${NC}"
    echo "  1. 访问: https://github.com/MetaCubeX/mihomo/releases"
    echo "  2. 下载: mihomo-linux-${ARCH}-<版本号>.gz"
    echo "  3. 解压并放到指定位置:"
    echo ""
    echo "     gunzip mihomo-linux-${ARCH}-*.gz"
    echo "     mv mihomo $MIHOMO_BIN"
    echo "     chmod +x $MIHOMO_BIN"
    echo ""
    echo "  或者直接下载解压好的二进制（不带 .gz 后缀）放到:"
    echo "     $MIHOMO_BIN"
    echo ""

    # 等待用户放好
    while true; do
        read -p "已放好？按 Enter 继续，输入 q 跳过: " ans
        [[ "$ans" == "q" ]] && { echo -e "${YELLOW}⚠️  跳过 mihomo 安装${NC}"; return 0; }
        if [ -f "$MIHOMO_BIN" ] && [ -x "$MIHOMO_BIN" ]; then
            echo -e "${GREEN}✅ 检测到 mihomo: $MIHOMO_BIN${NC}"
            return 0
        fi
        echo -e "${RED}❌ 未找到 $MIHOMO_BIN，请确认文件已放好且有执行权限${NC}"
    done
}

# ===== 2. 安装 MetaCubeXD 面板 =====
install_dashboard() {
    local dash_dir="$CONFIG_DIR/dashboard"

    # 检查是否已存在
    if [ -f "$dash_dir/index.html" ]; then
        echo -e "${GREEN}✅ MetaCubeXD 已存在，跳过${NC}"
        return 0
    fi

    mkdir -p "$dash_dir"

    # 尝试自动下载
    echo "📥 尝试下载 MetaCubeXD 面板..."
    VERSION=$(curl -s --connect-timeout 5 https://api.github.com/repos/MetaCubeX/metacubexd/releases/latest 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -n "$VERSION" ]; then
        echo "   版本: $VERSION"
        URL="https://github.com/MetaCubeX/metacubexd/releases/download/$VERSION/compressed-dist.tgz"
        TEMP="/tmp/metacubexd.tgz"
        MIRRORS=("https://ghfast.top" "https://gh-proxy.com" "")

        OK=false
        for mirror in "${MIRRORS[@]}"; do
            FULL="${mirror:+$mirror/}$URL"
            echo "   尝试: ${FULL:0:70}..."
            if curl -sL --connect-timeout 10 --max-time 120 -o "$TEMP" "$FULL" && [ -s "$TEMP" ]; then
                OK=true; break
            fi
        done

        if [ "$OK" = "true" ] && tar -xzf "$TEMP" -C "$dash_dir" 2>/dev/null; then
            rm -f "$TEMP"
            echo -e "${GREEN}✅ MetaCubeXD 已安装${NC}"
            return 0
        fi
        rm -f "$TEMP"
    fi

    # 自动下载失败，提示手动下载
    echo ""
    echo -e "${YELLOW}⚠️  MetaCubeXD 自动下载失败（网络问题）${NC}"
    echo ""
    echo -e "${WHITE}请手动下载面板:${NC}"
    echo "  1. 访问: https://github.com/MetaCubeX/metacubexd/releases"
    echo "  2. 下载: compressed-dist.tgz"
    echo "  3. 解压到面板目录:"
    echo ""
    echo "     tar xzf compressed-dist.tgz -C $dash_dir"
    echo ""
    echo "  或者下载 zip 格式解压后把所有文件放到:"
    echo "     $dash_dir/"
    echo "  （目录下应直接有 index.html）"
    echo ""

    read -p "已放好？按 Enter 继续，输入 q 跳过: " ans
    [[ "$ans" == "q" ]] && { echo -e "${YELLOW}⚠️  跳过面板安装${NC}"; return 0; }

    if [ -f "$dash_dir/index.html" ]; then
        echo -e "${GREEN}✅ MetaCubeXD 已安装${NC}"
    else
        echo -e "${YELLOW}⚠️  未检测到面板文件，可稍后手动安装${NC}"
    fi
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
echo "  mihomo:  $MIHOMO_BIN"
echo "  面板:    $CONFIG_DIR/dashboard/"
echo "  配置:    $CONFIG_DIR/config.yaml"
echo "  脚本:    ~/.local/bin/"
echo ""
echo -e "${YELLOW}如果网络不通，可手动下载放到上述路径，安装脚本会自动检测${NC}"
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
