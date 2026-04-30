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
MIHOMO_BIN="$HOME/.local/bin/mihomo-core"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   mihomo-quick 安装程序                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ===== 工具函数 =====

detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armv7" ;;
        *)       echo "$arch" ;;
    esac
}

get_current_version() {
    if [ -x "$MIHOMO_BIN" ]; then
        "$MIHOMO_BIN" -v 2>/dev/null | grep -oP 'v[\d.]+' | head -1 || echo "unknown"
    else
        echo ""
    fi
}

get_latest_release() {
    local repo="$1"
    curl -s --connect-timeout 5 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'
}

download_with_mirrors() {
    local url="$1"
    local output="$2"
    local desc="$3"
    local mirrors=("https://ghfast.top" "https://gh-proxy.com" "")

    for mirror in "${mirrors[@]}"; do
        local full="${mirror:+$mirror/}$url"
        echo "   尝试: ${full:0:70}..."
        if curl -sL --connect-timeout 10 --max-time 120 -o "$output" "$full" && [ -s "$output" ]; then
            return 0
        fi
    done
    echo -e "${RED}   ❌ $desc 下载失败${NC}"
    return 1
}

# ===== 1. 安装 mihomo =====

install_mihomo() {
    mkdir -p "$(dirname "$MIHOMO_BIN")"

    local current=$(get_current_version)
    local latest=$(get_latest_release "MetaCubeX/mihomo")
    local arch=$(detect_arch)

    if [ -n "$current" ]; then
        echo -e "${GREEN}✅ mihomo 已安装: $MIHOMO_BIN${NC}"
        echo "   当前版本: $current"
        if [ -n "$latest" ]; then
            echo "   最新版本: $latest"
            if [ "$current" = "$latest" ]; then
                echo -e "${GREEN}   ✅ 已是最新版本，跳过${NC}"
                return 0
            fi
            echo ""
            read -p "   是否更新到 $latest？ [Y/n]: " yn || true
        else
            echo ""
            read -p "   是否重新安装？ [y/N]: " yn || true
        fi
        [[ "$yn" =~ ^[Nn]$ ]] && return 0
    fi

    # 检测架构
    if [ "$arch" = "armv7l" ] || [ "$arch" = "arm64" ] || [ "$arch" = "amd64" ]; then
        : # ok
    else
        echo -e "${RED}❌ 不支持的架构: $arch${NC}"
        exit 1
    fi

    # 尝试自动下载
    if [ -z "$latest" ]; then
        latest=$(get_latest_release "MetaCubeX/mihomo")
    fi

    if [ -n "$latest" ]; then
        echo "📥 下载 mihomo $latest ($arch)..."
        URL="https://github.com/MetaCubeX/mihomo/releases/download/$latest/mihomo-linux-${arch}-${latest}.gz"
        TEMP="/tmp/mihomo.gz"

        if download_with_mirrors "$URL" "$TEMP" "mihomo"; then
            # 备份旧版本
            if [ -f "$MIHOMO_BIN" ]; then
                cp "$MIHOMO_BIN" "${MIHOMO_BIN}.bak"
                echo "   📋 已备份旧版本到 ${MIHOMO_BIN}.bak"
            fi
            gunzip -c "$TEMP" > "$MIHOMO_BIN"
            chmod +x "$MIHOMO_BIN"
            rm -f "$TEMP"
            echo -e "${GREEN}✅ mihomo 已安装: $MIHOMO_BIN${NC}"
            "$MIHOMO_BIN" -v 2>/dev/null || true
            return 0
        fi
    fi

    # 自动下载失败，提示手动下载
    echo ""
    echo -e "${YELLOW}⚠️  自动下载失败（网络问题）${NC}"
    echo ""
    echo -e "${WHITE}请手动下载 mihomo:${NC}"
    echo "  1. 访问: https://github.com/MetaCubeX/mihomo/releases"
    echo "  2. 下载: mihomo-linux-${arch}-<版本号>.gz"
    echo "  3. 解压并放到指定位置:"
    echo ""
    echo "     gunzip mihomo-linux-${arch}-*.gz"
    echo "     mv mihomo $MIHOMO_BIN"
    echo "     chmod +x $MIHOMO_BIN"
    echo ""
    echo "  或者直接下载解压好的二进制（不带 .gz 后缀）放到:"
    echo "     $MIHOMO_BIN"
    echo ""

    while true; do
        read -p "已放好？按 Enter 继续，输入 q 跳过: " ans || true
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
    mkdir -p "$dash_dir"

    local latest=$(get_latest_release "MetaCubeX/metacubexd")

    if [ -f "$dash_dir/index.html" ]; then
        echo -e "${GREEN}✅ MetaCubeXD 面板已安装${NC}"
        if [ -n "$latest" ]; then
            echo "   最新版本: $latest"
            read -p "   是否更新面板？ [y/N]: " yn || true
            [[ "$yn" =~ ^[Yy]$ ]] || return 0
            # 备份旧面板
            local backup="$CONFIG_DIR/dashboard.bak.$(date +%Y%m%d%H%M%S)"
            mv "$dash_dir" "$backup"
            mkdir -p "$dash_dir"
            echo "   📋 已备份旧面板到 $backup"
        else
            return 0
        fi
    fi

    if [ -z "$latest" ]; then
        latest=$(get_latest_release "MetaCubeX/metacubexd")
    fi

    if [ -n "$latest" ]; then
        echo "📥 下载 MetaCubeXD $latest..."
        URL="https://github.com/MetaCubeX/metacubexd/releases/download/$latest/compressed-dist.tgz"
        TEMP="/tmp/metacubexd.tgz"

        if download_with_mirrors "$URL" "$TEMP" "Dashboard"; then
            if tar -xzf "$TEMP" -C "$dash_dir" 2>/dev/null; then
                rm -f "$TEMP"
                echo -e "${GREEN}✅ MetaCubeXD 已安装${NC}"
                return 0
            fi
            rm -f "$TEMP"
        fi
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

    read -p "已放好？按 Enter 继续，输入 q 跳过: " ans || true
    [[ "$ans" == "q" ]] && { echo -e "${YELLOW}⚠️  跳过面板安装${NC}"; return 0; }

    if [ -f "$dash_dir/index.html" ]; then
        echo -e "${GREEN}✅ MetaCubeXD 已安装${NC}"
    else
        echo -e "${YELLOW}⚠️  未检测到面板文件，可稍后通过 mihomo-update 安装${NC}"
    fi
}

# ===== 3. 复制脚本 =====

install_scripts() {
    echo "📁 安装脚本..."
    mkdir -p "$HOME/.local/bin"

    local scripts=(
        scripts/mihomo-menu       mihomo
        scripts/mihomo-start      mihomo-start
        scripts/mihomo-stop       mihomo-stop
        scripts/mihomo-check      mihomo-check
        scripts/mihomo-rollback   mihomo-rollback
        scripts/mihomo-logs       mihomo-logs
        scripts/mihomo-add-sub    mihomo-add-sub
        scripts/mihomo-rules      mihomo-rules
        scripts/set-proxy-env     set-proxy-env
        scripts/proxy-env         proxy-env
        scripts/test-all-proxy    test-all-proxy
        scripts/mihomo-update     mihomo-update
    )

    # 检测是否有旧脚本需要备份
    local has_old=false
    for ((i=0; i<${#scripts[@]}; i+=2)); do
        local name="${scripts[$i+1]}"
        if [ -f "$HOME/.local/bin/$name" ]; then
            has_old=true
            break
        fi
    done

    if [ "$has_old" = "true" ]; then
        local backup_dir="$HOME/.local/bin/.mihomo-quick-backup.$(date +%Y%m%d%H%M%S)"
        mkdir -p "$backup_dir"
        for ((i=0; i<${#scripts[@]}; i+=2)); do
            local name="${scripts[$i+1]}"
            [ -f "$HOME/.local/bin/$name" ] && cp "$HOME/.local/bin/$name" "$backup_dir/"
        done
        echo "   📋 已备份旧脚本到 $backup_dir"
    fi

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
        echo -e "${GREEN}✅ 配置文件已存在${NC}"
        echo "   路径: $CONFIG_DIR/config.yaml"
        read -p "   是否用默认配置覆盖？ [y/N]: " yn || true
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            cp "$CONFIG_DIR/config.yaml" "$CONFIG_DIR/config.yaml.bak.$(date +%Y%m%d%H%M%S)"
            cp "$SCRIPT_DIR/config/config.yaml" "$CONFIG_DIR/config.yaml"
            echo -e "${GREEN}   ✅ 已覆盖（旧配置已备份）${NC}"
        else
            echo "   ⏭️  保留现有配置"
        fi
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

install_one_service() {
    local service_name="$1"  # mihomo 或 mihomo-tun
    local service_file="$SCRIPT_DIR/systemd/${service_name}.service"
    local target="/etc/systemd/system/${service_name}.service"

    if [ -f "$target" ]; then
        echo -e "${GREEN}✅ ${service_name} 服务已存在${NC}"
        read -p "   是否覆盖更新？ [y/N]: " yn || true
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            sudo cp "$target" "${target}.bak.$(date +%Y%m%d%H%M%S)"
            sed "s|/root|$HOME|g" "$service_file" | sudo tee "$target" > /dev/null
            sudo systemctl daemon-reload
            echo -e "${GREEN}   ✅ ${service_name} 服务已更新（旧版本已备份）${NC}"
        else
            echo "   ⏭️  保留现有 ${service_name} 服务"
        fi
    else
        sed "s|/root|$HOME|g" "$service_file" | sudo tee "$target" > /dev/null
        sudo systemctl daemon-reload
        echo -e "${GREEN}✅ ${service_name} 服务已创建${NC}"
    fi
}

install_service() {
    echo "🔧 配置 systemd 服务..."
    echo ""
    echo -e "${WHITE}普通模式 (mihomo.service):${NC}"
    install_one_service "mihomo"
    echo ""
    echo -e "${WHITE}TUN 模式 (mihomo-tun.service):${NC}"
    install_one_service "mihomo-tun"
    echo ""
    echo -e "   💡 运行 ${CYAN}mihomo${NC} 打开管理菜单，选择 '安装/更新服务' 设置开机自启"
}

# ===== 6. 环境变量提示 =====

setup_env() {
    # 检查是否已配置
    if grep -q 'set-proxy-env' "$HOME/.bashrc" 2>/dev/null; then
        echo -e "${GREEN}✅ 代理环境变量已配置${NC}"
        return 0
    fi

    echo ""
    echo -e "${WHITE}📋 环境变量配置:${NC}"
    echo "   把以下内容追加到 ~/.bashrc："
    echo ""
    echo "   source ~/.local/bin/set-proxy-env"
    echo ""
    echo "   或者直接执行:"
    echo "   cat bashrc-snippet.sh >> ~/.bashrc"
    echo ""
    read -p "   是否自动追加到 ~/.bashrc？ [Y/n]: " yn || true
    if [[ ! "$yn" =~ ^[Nn]$ ]]; then
        cat "$SCRIPT_DIR/bashrc-snippet.sh" >> "$HOME/.bashrc"
        echo -e "${GREEN}   ✅ 已追加到 ~/.bashrc${NC}"
        echo "   执行 'source ~/.bashrc' 立即生效"
    fi
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
read -p "开始安装？ [Y/n]: " confirm || true
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
echo "  2. mihomo                     # 打开管理菜单"
echo ""
echo -e "${WHITE}命令速查:${NC}"
echo "  mihomo                        打开管理菜单（推荐）"
echo "  mihomo-update                 检查更新内核/面板/GeoIP"
echo "  mihomo-add-sub                添加订阅"
echo "  mihomo-rules                  管理规则"
echo "  mihomo-check                  校验配置"
echo "  mihomo-rollback               配置回滚"
echo "  mihomo-logs                   查看日志"
echo "  proxy-test                    综合测试"
echo ""
echo -e "${WHITE}服务管理:${NC}"
echo "  ./setup-service.sh            创建普通模式服务并开机自启"
echo "  ./setup-service.sh tun        创建 TUN 模式服务并开机自启"
echo ""
