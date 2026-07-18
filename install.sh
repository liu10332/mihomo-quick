#!/bin/bash
# install.sh - mihomo-quick 一键安装脚本
# 使用 lib/ 库函数实现自动检测和安装
set -e

# ===== 加载库 =====

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/service.sh"

# ===== 常量 =====

DEFAULT_INSTALL_DIR="$HOME/.mihomo-quick"
DEFAULT_CONFIG_DIR="$HOME/.config/mihomo"

INSTALL_DIR="${1:-$DEFAULT_INSTALL_DIR}"
CONFIG_DIR="$DEFAULT_CONFIG_DIR"

# ===== 系统信息显示 =====

show_system_info() {
    echo ""
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   mihomo-quick 安装程序                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    local arch=$(detect_arch 2>/dev/null || echo "unknown")
    local distro=$(detect_distro_name 2>/dev/null || echo "unknown")
    local user=$(detect_current_user)

    log_title "系统信息"
    echo "  系统:      $distro"
    echo "  架构:      $arch"
    echo "  用户:      $user"
    echo "  HOME:      $HOME"
    echo ""
}

# ===== 依赖检查 =====

check_required_deps() {
    log_step "检查依赖..."
    local required=("curl" "tar" "openssl")

    if ! check_dependencies "${required[@]}"; then
        die "缺少必要依赖，请先安装: ${required[*]}"
    fi

    log_info "依赖检查通过"
    echo ""
}

# ===== 1. 安装 mihomo =====

install_mihomo() {
    log_title "安装 mihomo"

    mkdir -p "$(dirname "$MIHOMO_BIN")"

    local current=""
    if [[ -x "$MIHOMO_BIN" ]]; then
        current=$("$MIHOMO_BIN" -v 2>/dev/null | grep -oP 'v[\d.]+' | head -1 || echo "")
    fi

    local latest=$(get_latest_release "MetaCubeX/mihomo")
    local arch=$(detect_arch)

    if [[ -n "$current" ]]; then
        log_info "mihomo 已安装: $MIHOMO_BIN"
        echo "   当前版本: $current"
        if [[ -n "$latest" ]]; then
            echo "   最新版本: $latest"
            if [[ "$current" == "$latest" ]]; then
                log_info "已是最新版本，跳过"
                return 0
            fi
            if ! confirm "是否更新到 $latest？"; then
                return 0
            fi
        else
            if ! confirm "是否重新安装？" "n"; then
                return 0
            fi
        fi
    fi

    if [[ -z "$latest" ]]; then
        latest=$(get_latest_release "MetaCubeX/mihomo")
    fi

    if [[ -n "$latest" ]]; then
        echo "下载 mihomo $latest ($arch)..."
        local url="https://github.com/MetaCubeX/mihomo/releases/download/$latest/mihomo-linux-${arch}-${latest}.gz"
        local temp="/tmp/mihomo.gz"

        if download_with_mirrors "$url" "$temp" "mihomo"; then
            backup_file "$MIHOMO_BIN" 2>/dev/null || true
            gunzip -c "$temp" > "$MIHOMO_BIN"
            chmod +x "$MIHOMO_BIN"
            rm -f "$temp"
            log_info "mihomo 已安装: $MIHOMO_BIN"
            "$MIHOMO_BIN" -v 2>/dev/null || true
            return 0
        fi
    fi

    # 自动下载失败，提示手动下载
    echo ""
    log_warn "自动下载失败（网络问题）"
    echo ""
    echo "请手动下载 mihomo:"
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
        read -r -p "已放好？按 Enter 继续，输入 q 跳过: " ans || true
        [[ "$ans" == "q" ]] && { log_warn "跳过 mihomo 安装"; return 0; }
        if [[ -f "$MIHOMO_BIN" ]] && [[ -x "$MIHOMO_BIN" ]]; then
            log_info "检测到 mihomo: $MIHOMO_BIN"
            return 0
        fi
        log_error "未找到 $MIHOMO_BIN，请确认文件已放好且有执行权限"
    done
}

# ===== 2. 安装 MetaCubeXD 面板 =====

install_dashboard() {
    log_title "安装 MetaCubeXD 面板"

    local dash_dir="$CONFIG_DIR/dashboard"
    mkdir -p "$dash_dir"

    local latest=$(get_latest_release "MetaCubeX/metacubexd")

    if [[ -f "$dash_dir/index.html" ]]; then
        log_info "MetaCubeXD 面板已安装"
        if [[ -n "$latest" ]]; then
            echo "   最新版本: $latest"
            if ! confirm "是否更新面板？" "n"; then
                return 0
            fi
            backup_file "$dash_dir" 2>/dev/null || true
            rm -rf "$dash_dir"
            mkdir -p "$dash_dir"
        else
            return 0
        fi
    fi

    if [[ -z "$latest" ]]; then
        latest=$(get_latest_release "MetaCubeX/metacubexd")
    fi

    if [[ -n "$latest" ]]; then
        echo "下载 MetaCubeXD $latest..."
        local url="https://github.com/MetaCubeX/metacubexd/releases/download/$latest/compressed-dist.tgz"
        local temp="/tmp/metacubexd.tgz"

        if download_with_mirrors "$url" "$temp" "Dashboard"; then
            if tar -xzf "$temp" -C "$dash_dir" 2>/dev/null; then
                rm -f "$temp"
                log_info "MetaCubeXD 已安装"
                return 0
            fi
            rm -f "$temp"
        fi
    fi

    # 自动下载失败，提示手动下载
    echo ""
    log_warn "MetaCubeXD 自动下载失败（网络问题）"
    echo ""
    echo "请手动下载面板:"
    echo "  1. 访问: https://github.com/MetaCubeX/metacubexd/releases"
    echo "  2. 下载: compressed-dist.tgz"
    echo "  3. 解压到面板目录:"
    echo ""
    echo "     tar xzf compressed-dist.tgz -C $dash_dir"
    echo ""

    read -r -p "已放好？按 Enter 继续，输入 q 跳过: " ans || true
    [[ "$ans" == "q" ]] && { log_warn "跳过面板安装"; return 0; }

    if [[ -f "$dash_dir/index.html" ]]; then
        log_info "MetaCubeXD 已安装"
    else
        log_warn "未检测到面板文件，可稍后通过 mihomo-update 安装"
    fi
}

# ===== 3. 安装管理脚本 =====

install_scripts() {
    log_title "安装管理脚本"
    mkdir -p "$HOME/.local/bin"

    local scripts=(
        scripts/mihomo-menu       mihomo
        scripts/mihomo-start      mihomo-start
        scripts/mihomo-stop       mihomo-stop
        scripts/mihomo-check      mihomo-check
        scripts/mihomo-rollback   mihomo-rollback
        scripts/mihomo-logs       mihomo-logs
        scripts/mihomo-add-sub    mihomo-add-sub
        scripts/mihomo-sub         mihomo-sub
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
        if [[ -f "$HOME/.local/bin/$name" ]]; then
            has_old=true
            break
        fi
    done

    if [[ "$has_old" == "true" ]]; then
        local backup_dir="$HOME/.local/bin/.mihomo-quick-backup.$(date +%Y%m%d%H%M%S)"
        mkdir -p "$backup_dir"
        for ((i=0; i<${#scripts[@]}; i+=2)); do
            local name="${scripts[$i+1]}"
            [[ -f "$HOME/.local/bin/$name" ]] && cp "$HOME/.local/bin/$name" "$backup_dir/"
        done
        log_info "已备份旧脚本到 $backup_dir"
    fi

    for ((i=0; i<${#scripts[@]}; i+=2)); do
        local src="${scripts[$i]}"
        local name="${scripts[$i+1]}"
        if [[ -f "$SCRIPT_DIR/$src" ]]; then
            cp "$SCRIPT_DIR/$src" "$HOME/.local/bin/$name"
            chmod +x "$HOME/.local/bin/$name"
        fi
    done

    # Create compatibility symlink
    ln -sf mihomo-sub "$DEFAULT_INSTALL_DIR/mihomo-add-sub"

    # 卸载脚本
    if [[ -f "$SCRIPT_DIR/scripts/uninstall.sh" ]]; then
        cp "$SCRIPT_DIR/scripts/uninstall.sh" "$HOME/.local/bin/mihomo-uninstall"
        chmod +x "$HOME/.local/bin/mihomo-uninstall"
    fi

    # 安装 auto-update 脚本
    if [[ -f "$SCRIPT_DIR/scripts/mihomo-auto-update" ]]; then
        cp "$SCRIPT_DIR/scripts/mihomo-auto-update" "$HOME/.local/bin/mihomo-auto-update"
        chmod +x "$HOME/.local/bin/mihomo-auto-update"
    fi

    log_info "脚本已安装到 ~/.local/bin/"
}

# ===== 4. 生成配置 =====

install_config() {
    log_title "生成配置文件"

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/providers"
    mkdir -p "$CONFIG_DIR/backups"

    if [[ -f "$CONFIG_DIR/config.yaml" ]]; then
        log_info "配置文件已存在"
        echo "   路径: $CONFIG_DIR/config.yaml"
        if ! confirm "是否用默认配置覆盖？" "n"; then
            echo "   保留现有配置"
            return 0
        fi
        backup_file "$CONFIG_DIR/config.yaml"
    fi

    # 检测端口
    local http_port=$(find_available_port 7890)
    local socks_port=$(find_available_port 7891)
    local api_port=$(find_available_port 9090)

    # 生成 API 密钥
    local api_secret=$(openssl rand -hex 16)

    # 检测 TUN 设备
    local tun_device=$(detect_tun_device)

    # 生成配置文件
    log_step "生成配置: HTTP=$http_port, SOCKS=$socks_port, API=$api_port"

    sed -e "s/{HTTP_PORT}/$http_port/g" \
        -e "s/{SOCKS_PORT}/$socks_port/g" \
        -e "s/{API_PORT}/$api_port/g" \
        -e "s/{API_SECRET}/$api_secret/g" \
        -e "s|{CONFIG_DIR}|$CONFIG_DIR|g" \
        -e "s/{TUN_ENABLE}/false/g" \
        -e "s/{TUN_DEVICE}/$tun_device/g" \
        -e "s/{TUN_GATEWAY}/10.0.0.1/g" \
        "$SCRIPT_DIR/templates/config.yaml" > "$CONFIG_DIR/config.yaml"

    log_info "配置文件已创建: $CONFIG_DIR/config.yaml"
    echo "   HTTP 端口: $http_port"
    echo "   SOCKS 端口: $socks_port"
    echo "   API 端口: $api_port"
    echo "   API 密钥: $api_secret"
    echo ""

    # 复制 geoip 数据
    if [[ -f "$SCRIPT_DIR/config/geoip.metadb" ]] && [[ ! -f "$CONFIG_DIR/geoip.metadb" ]]; then
        cp "$SCRIPT_DIR/config/geoip.metadb" "$CONFIG_DIR/geoip.metadb"
    fi

    # 复制 geosite 数据
    if [[ -f "$SCRIPT_DIR/config/geosite.dat" ]] && [[ ! -f "$CONFIG_DIR/geosite.dat" ]]; then
        cp "$SCRIPT_DIR/config/geosite.dat" "$CONFIG_DIR/geosite.dat"
    fi
}

# ===== 5. 安装 systemd 服务 =====

install_services() {
    log_title "配置 systemd 服务"

    local user=$(detect_current_user)

    # 检测 TUN 设备和网关
    local tun_device=$(detect_tun_device)
    local tun_gateway="10.0.0.1"

    # 准备服务模板
    local bin_dir="$HOME/.local/bin"

    # 安装普通模式服务
    echo "普通模式 (mihomo.service):"
    if [[ -f "$SCRIPT_DIR/templates/mihomo.service" ]]; then
        local target="/etc/systemd/system/mihomo.service"

        if [[ -f "$target" ]]; then
            if confirm "是否覆盖更新 mihomo 服务？" "n"; then
                backup_file "$target"
                sed -e "s/{USER}/$user/g" \
                    -e "s|{HOME}|$HOME|g" \
                    -e "s|{BIN_DIR}|$bin_dir|g" \
                    -e "s|{CONFIG_DIR}|$CONFIG_DIR|g" \
                    "$SCRIPT_DIR/templates/mihomo.service" | sudo tee "$target" > /dev/null
                sudo systemctl daemon-reload
                log_info "mihomo 服务已更新"
            else
                echo "   保留现有 mihomo 服务"
            fi
        else
            sed -e "s/{USER}/$user/g" \
                -e "s|{HOME}|$HOME|g" \
                -e "s|{BIN_DIR}|$bin_dir|g" \
                -e "s|{CONFIG_DIR}|$CONFIG_DIR|g" \
                "$SCRIPT_DIR/templates/mihomo.service" | sudo tee "$target" > /dev/null
            sudo systemctl daemon-reload
            log_info "mihomo 服务已创建"
        fi
    fi

    echo ""

    # 安装 TUN 模式服务
    echo "TUN 模式 (mihomo-tun.service):"
    if [[ -f "$SCRIPT_DIR/templates/mihomo-tun.service" ]]; then
        local target="/etc/systemd/system/mihomo-tun.service"

        if [[ -f "$target" ]]; then
            if confirm "是否覆盖更新 mihomo-tun 服务？" "n"; then
                backup_file "$target"
                sed -e "s/{USER}/$user/g" \
                    -e "s|{HOME}|$HOME|g" \
                    -e "s|{BIN_DIR}|$bin_dir|g" \
                    -e "s|{CONFIG_DIR}|$CONFIG_DIR|g" \
                    -e "s/{TUN_DEVICE}/$tun_device/g" \
                    -e "s/{TUN_GATEWAY}/$tun_gateway/g" \
                    "$SCRIPT_DIR/templates/mihomo-tun.service" | sudo tee "$target" > /dev/null
                sudo systemctl daemon-reload
                log_info "mihomo-tun 服务已更新"
            else
                echo "   保留现有 mihomo-tun 服务"
            fi
        else
            sed -e "s/{USER}/$user/g" \
                -e "s|{HOME}|$HOME|g" \
                -e "s|{BIN_DIR}|$bin_dir|g" \
                -e "s|{CONFIG_DIR}|$CONFIG_DIR|g" \
                -e "s/{TUN_DEVICE}/$tun_device/g" \
                -e "s/{TUN_GATEWAY}/$tun_gateway/g" \
                "$SCRIPT_DIR/templates/mihomo-tun.service" | sudo tee "$target" > /dev/null
            sudo systemctl daemon-reload
            log_info "mihomo-tun 服务已创建"
        fi
    fi

    echo ""
    echo "   运行 mihomo 打开管理菜单，选择 '安装/更新服务' 设置开机自启"
}

# ===== 6. 环境变量配置 =====

setup_env() {
    log_title "环境变量配置"

    if grep -q 'set-proxy-env' "$HOME/.bashrc" 2>/dev/null; then
        log_info "代理环境变量已配置"
        return 0
    fi

    echo "把以下内容追加到 ~/.bashrc："
    echo ""
    echo "   source ~/.local/bin/set-proxy-env"
    echo ""
    echo "或者直接执行:"
    echo "   cat bashrc-snippet.sh >> ~/.bashrc"
    echo ""

    if confirm "是否自动追加到 ~/.bashrc？"; then
        cat "$SCRIPT_DIR/bashrc-snippet.sh" >> "$HOME/.bashrc"
        log_info "已追加到 ~/.bashrc"
        echo "   执行 'source ~/.bashrc' 立即生效"
    fi
}

# ===== 主流程 =====

main() {
    show_system_info
    check_required_deps

    echo ""
    echo -e "${WHITE}安装配置:${NC}"
    echo "  mihomo:  $MIHOMO_BIN"
    echo "  面板:    $CONFIG_DIR/dashboard/"
    echo "  配置:    $CONFIG_DIR/config.yaml"
    echo "  脚本:    ~/.local/bin/"
    echo ""
    echo -e "${YELLOW}如果网络不通，可手动下载放到上述路径，安装脚本会自动检测${NC}"
    echo ""

    if ! confirm "开始安装？"; then
        echo "已取消"
        exit 0
    fi

    echo ""
    install_mihomo
    echo ""
    install_dashboard
    echo ""
    install_scripts
    echo ""
    install_config
    echo ""
    install_services
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
    echo "  test-all-proxy                综合测试"
    echo ""
    echo -e "${WHITE}服务管理:${NC}"
    echo "  mihomo                        打开管理菜单，选择'安装/更新服务'"
    echo "  sudo systemctl start mihomo  启动普通模式服务"
    echo "  sudo systemctl start mihomo-tun  启动 TUN 模式服务"
    echo ""
}

main "$@"
