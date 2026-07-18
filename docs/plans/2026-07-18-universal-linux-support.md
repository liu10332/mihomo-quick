# mihomo-quick 通用化改造实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 mihomo-quick 改造为可在任意 Linux 发行版上安装使用的通用代理部署工具

**Architecture:** 提取公共函数库，实现系统自动检测，变量化配置路径，支持多发行版适配

**Tech Stack:** Bash, Python3 (YAML处理), systemd

## Global Constraints

- 支持 Ubuntu/Debian, CentOS/RHEL/Fedora, Arch Linux
- 支持 x86_64, aarch64, armv7 架构
- 依赖: curl, python3, tar, gzip (安装前检查)
- TUN 设备名称自动检测
- 端口自动检测避免冲突
- 服务支持非 root 用户运行

---

## 文件结构

```
mihomo-quick/
├── install.sh                    # 主安装脚本 (重构)
├── uninstall.sh                  # 卸载脚本 (从 scripts/ 移出)
├── lib/
│   ├── common.sh                 # 公共函数 (颜色、日志、错误处理)
│   ├── detect.sh                 # 系统检测 (发行版、架构、TUN设备)
│   ├── network.sh                # 网络工具 (端口检测、防火墙)
│   └── service.sh                # 服务管理 (systemd 操作)
├── templates/
│   ├── config.yaml               # 配置模板 (变量替换)
│   ├── mihomo.service            # systemd 模板
│   └── mihomo-tun.service        # TUN 服务模板
├── scripts/
│   ├── mihomo-menu               # 管理菜单 (重构)
│   ├── mihomo-add-sub            # 订阅管理 (重构)
│   ├── mihomo-rules              # 规则管理 (重构)
│   ├── mihomo-check              # 配置校验
│   ├── mihomo-update             # 更新工具
│   ├── mihomo-start              # 启动脚本
│   ├── mihomo-stop               # 停止脚本
│   ├── mihomo-rollback           # 回滚工具
│   ├── mihomo-logs               # 日志查看
│   ├── test-all-proxy            # 代理测试
│   └── set-proxy-env             # 环境变量
├── config/
│   ├── geoip.metadb              # GeoIP 数据
│   └── geosite.dat               # GeoSite 数据
└── systemd/                      # (废弃，使用 templates/)
```

---

### Task 1: 创建公共函数库 lib/common.sh

**Files:**
- Create: `lib/common.sh`

**Interfaces:**
- Produces: 颜色变量, 日志函数, 错误处理函数

- [ ] **Step 1: 创建 lib/common.sh**

```bash
#!/bin/bash
# lib/common.sh - mihomo-quick 公共函数库

# ===== 颜色定义 =====
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' CYAN='' WHITE='' BLUE='' NC=''
fi

# ===== 日志函数 =====
log_info()  { echo -e "${GREEN}✅ $1${NC}"; }
log_warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step()  { echo -e "${CYAN}━━━ $1 ━━━${NC}"; }
log_title() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    $1"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ===== 错误处理 =====
die() {
    log_error "$1"
    exit "${2:-1}"
}

# ===== 确认函数 =====
confirm() {
    local prompt="${1:-确认？}"
    local default="${2:-Y}"
    
    if [[ "$default" =~ ^[Yy]$ ]]; then
        read -p "$prompt [Y/n]: " yn || true
        [[ "$yn" =~ ^[Nn]$ ]] && return 1 || return 0
    else
        read -p "$prompt [y/N]: " yn || true
        [[ "$yn" =~ ^[Yy]$ ]] && return 0 || return 1
    fi
}

# ===== 备份函数 =====
backup_file() {
    local file="$1"
    local backup_dir="${2:-$(dirname "$file")}"
    
    if [ -f "$file" ]; then
        mkdir -p "$backup_dir"
        local backup="$file.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        echo "$backup"
    fi
}

# ===== 进度显示 =====
show_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local pct=$((current * 100 / total))
    echo -ne "\r  [$pct%] $desc"
    [ "$current" -eq "$total" ] && echo ""
}
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n lib/common.sh
echo "Exit code: $?"
```

- [ ] **Step 3: 提交**

```bash
git add lib/common.sh
git commit -m "feat: add common function library"
```

---

### Task 2: 创建系统检测库 lib/detect.sh

**Files:**
- Create: `lib/detect.sh`

**Interfaces:**
- Produces: `detect_arch()`, `detect_distro()`, `detect_tun_device()`, `check_dependencies()`

- [ ] **Step 1: 创建 lib/detect.sh**

```bash
#!/bin/bash
# lib/detect.sh - 系统检测函数

# 获取脚本所在目录
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/common.sh"

# ===== 架构检测 =====
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)      echo "amd64" ;;
        aarch64)     echo "arm64" ;;
        armv7l|armv7) echo "armv7" ;;
        i686|i386)   echo "386" ;;
        *)           echo "$arch" ;;
    esac
}

# ===== 发行版检测 =====
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# 获取发行版名称（用于显示）
detect_distro_name() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    else
        uname -o
    fi
}

# ===== TUN 设备检测 =====
detect_tun_device() {
    # 1. 优先使用已存在的 TUN 设备
    local existing=$(ip link show type tun 2>/dev/null | grep -oP '^\d+: \K[^:]+' | head -1)
    if [ -n "$existing" ]; then
        echo "$existing"
        return 0
    fi
    
    # 2. 检查 /dev/net/tun 是否可用
    if [ ! -c /dev/net/tun ]; then
        log_warn "TUN 设备不可用 (/dev/net/tun 不存在)"
        return 1
    fi
    
    # 3. 尝试常见的 TUN 设备名
    for dev in tun0 utun tun-wsl meta; do
        if [ ! -d "/sys/class/net/$dev" ]; then
            echo "$dev"
            return 0
        fi
    done
    
    # 4. 默认使用 tun0
    echo "tun0"
    return 0
}

# ===== 端口检测 =====
find_available_port() {
    local preferred=$1
    local port=$preferred
    
    while [ $port -lt 65535 ]; do
        if ! ss -tln 2>/dev/null | grep -q ":$port " && \
           ! ss -uln 2>/dev/null | grep -q ":$port "; then
            echo "$port"
            return 0
        fi
        ((port++))
    done
    
    log_error "无法找到可用端口 (从 $preferred 开始)"
    return 1
}

# 检查端口是否被占用
check_port_available() {
    local port=$1
    if ss -tln 2>/dev/null | grep -q ":$port " || ss -uln 2>/dev/null | grep -q ":$port "; then
        return 1
    fi
    return 0
}

# ===== 依赖检查 =====
check_dependencies() {
    local deps=("$@")
    local missing=()
    local optional=()
    
    for dep in "${deps[@]}"; do
        case "$dep" in
            curl|wget|tar|gzip|gunzip)
                command -v "$dep" &>/dev/null || missing+=("$dep")
                ;;
            python3|python)
                command -v python3 &>/dev/null || command -v python &>/dev/null || missing+=("python3")
                ;;
            ss|netstat)
                command -v ss &>/dev/null || command -v netstat &>/dev/null || optional+=("$dep")
                ;;
            *)
                command -v "$dep" &>/dev/null || missing+=("$dep")
                ;;
        esac
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少必需依赖: ${missing[*]}"
        echo ""
        echo "请根据你的发行版安装:"
        echo ""
        
        local distro=$(detect_distro)
        case "$distro" in
            ubuntu|debian)
                echo "  sudo apt update && sudo apt install -y ${missing[*]}"
                ;;
            centos|rhel|fedora|rocky|alma)
                echo "  sudo yum install -y ${missing[*]}"
                ;;
            arch|manjaro)
                echo "  sudo pacman -S ${missing[*]}"
                ;;
            *)
                echo "  请安装: ${missing[*]}"
                ;;
        esac
        return 1
    fi
    
    if [ ${#optional[@]} -gt 0 ]; then
        log_warn "缺少可选依赖: ${optional[*]} (部分功能可能受限)"
    fi
    
    return 0
}

# ===== 用户检测 =====
detect_current_user() {
    echo "$(whoami)"
}

is_root() {
    [ "$(id -u)" -eq 0 ]
}

# 获取建议的服务用户
get_service_user() {
    if is_root; then
        # 如果是 root，建议使用普通用户
        local login_user=$(logname 2>/dev/null || echo "$SUDO_USER")
        if [ -n "$login_user" ] && [ "$login_user" != "root" ]; then
            echo "$login_user"
        else
            echo "root"
        fi
    else
        echo "$(whoami)"
    fi
}
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n lib/detect.sh
echo "Exit code: $?"
```

- [ ] **Step 3: 测试函数**

```bash
source lib/detect.sh
echo "架构: $(detect_arch)"
echo "发行版: $(detect_distro)"
echo "TUN设备: $(detect_tun_device)"
echo "HTTP端口: $(find_available_port 7890)"
echo "服务用户: $(get_service_user)"
```

- [ ] **Step 4: 提交**

```bash
git add lib/detect.sh
git commit -m "feat: add system detection library"
```

---

### Task 3: 创建网络工具库 lib/network.sh

**Files:**
- Create: `lib/network.sh`

**Interfaces:**
- Produces: `configure_firewall()`, `download_with_mirrors()`, `get_latest_release()`

- [ ] **Step 1: 创建 lib/network.sh**

```bash
#!/bin/bash
# lib/network.sh - 网络工具函数

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/detect.sh"

# ===== GitHub 镜像源 =====
GITHUB_MIRRORS=(
    "https://ghfast.top"
    "https://gh-proxy.com"
    "https://mirror.ghproxy.com"
    ""
)

# ===== 下载函数（支持镜像） =====
download_with_mirrors() {
    local url="$1"
    local output="$2"
    local desc="${3:-文件}"
    local timeout="${4:-120}"
    
    for mirror in "${GITHUB_MIRRORS[@]}"; do
        local full="${mirror:+$mirror/}$url"
        log_info "尝试: ${full:0:70}..."
        if curl -sL --connect-timeout 10 --max-time "$timeout" -o "$output" "$full" && [ -s "$output" ]; then
            return 0
        fi
    done
    
    log_error "$desc 下载失败"
    return 1
}

# ===== GitHub API 获取最新版本 =====
get_latest_release() {
    local repo="$1"
    local tag=$(curl -s --connect-timeout 5 \
        "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$tag" ]; then
        # 尝试镜像
        for mirror in "${GITHUB_MIRRORS[@]}"; do
            tag=$(curl -s --connect-timeout 5 \
                "${mirror:+$mirror/}https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
                | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
            [ -n "$tag" ] && break
        done
    fi
    
    echo "$tag"
}

# ===== 防火墙配置 =====
configure_firewall() {
    local port=$1
    local protocol="${2:-tcp}"
    local distro=$(detect_distro)
    
    log_step "配置防火墙"
    
    case "$distro" in
        ubuntu|debian)
            if command -v ufw &>/dev/null; then
                ufw allow "$port/$protocol" 2>/dev/null
                log_info "ufw: 已允许 $port/$protocol"
            elif command -v iptables &>/dev/null; then
                iptables -A INPUT -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null
                log_info "iptables: 已允许 $port/$protocol"
            fi
            ;;
        centos|rhel|fedora|rocky|alma)
            if command -v firewall-cmd &>/dev/null; then
                firewall-cmd --permanent --add-port="$port/$protocol" 2>/dev/null
                firewall-cmd --reload 2>/dev/null
                log_info "firewalld: 已允许 $port/$protocol"
            elif command -v iptables &>/dev/null; then
                iptables -A INPUT -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null
                log_info "iptables: 已允许 $port/$protocol"
            fi
            ;;
        arch)
            if command -v iptables &>/dev/null; then
                iptables -A INPUT -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null
                log_info "iptables: 已允许 $port/$protocol"
            fi
            ;;
        *)
            log_warn "未知发行版，请手动配置防火墙开放 $port/$protocol"
            ;;
    esac
}

# ===== SELinux 配置 =====
configure_selinux() {
    if command -v getenforce &>/dev/null; then
        local status=$(getenforce 2>/dev/null)
        if [ "$status" = "Enforcing" ]; then
            log_step "配置 SELinux"
            # 允许 mihomo 网络连接
            setsebool -P mihomo_can_network_connect 1 2>/dev/null || true
            # 允许使用 TUN 设备
            chcon -t tun_device_t /dev/net/tun 2>/dev/null || true
            log_info "SELinux: 已配置"
        fi
    fi
}

# ===== DNS 解析测试 =====
test_dns_resolve() {
    local domain=$1
    if host "$domain" &>/dev/null || nslookup "$domain" &>/dev/null; then
        return 0
    fi
    return 1
}

# ===== 网络连通性测试 =====
test_network() {
    local url="${1:-https://www.baidu.com}"
    local timeout="${2:-5}"
    
    if curl -s --connect-timeout "$timeout" -o /dev/null "$url" 2>/dev/null; then
        return 0
    fi
    return 1
}
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n lib/network.sh
echo "Exit code: $?"
```

- [ ] **Step 3: 提交**

```bash
git add lib/network.sh
git commit -m "feat: add network utility library"
```

---

### Task 4: 创建服务管理库 lib/service.sh

**Files:**
- Create: `lib/service.sh`

**Interfaces:**
- Produces: `install_service()`, `start_service()`, `stop_service()`, `restart_service()`, `get_service_status()`

- [ ] **Step 1: 创建 lib/service.sh**

```bash
#!/bin/bash
# lib/service.sh - systemd 服务管理

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/detect.sh"

# ===== 服务状态检测 =====
get_service_status() {
    local service=$1
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "running"
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo "stopped"
    else
        echo "not-installed"
    fi
}

# 获取运行中的服务名
get_active_service() {
    if systemctl is-active --quiet mihomo-tun 2>/dev/null; then
        echo "mihomo-tun"
    elif systemctl is-active --quiet mihomo 2>/dev/null; then
        echo "mihomo"
    else
        # 检查手动启动的进程
        local pid_file="$HOME/.cache/mihomo/mihomo.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                echo "manual"
            fi
        fi
    fi
}

# ===== 服务安装 =====
install_service() {
    local service_name="$1"  # mihomo 或 mihomo-tun
    local service_user="${2:-$(get_service_user)}"
    local install_dir="${3:-$HOME/.local/bin}"
    local config_dir="${4:-$HOME/.config/mihomo}"
    local template_dir="${5:-$LIB_DIR/../templates}"
    
    local template="$template_dir/${service_name}.service"
    local target="/etc/systemd/system/${service_name}.service"
    
    if [ ! -f "$template" ]; then
        log_error "服务模板不存在: $template"
        return 1
    fi
    
    log_step "安装 $service_name 服务"
    
    # 备份现有服务
    if [ -f "$target" ]; then
        backup_file "$target" "/tmp"
    fi
    
    # 替换模板变量并安装
    sed \
        -e "s|{USER}|$service_user|g" \
        -e "s|{HOME}|$(eval echo ~$service_user)|g" \
        -e "s|{BIN_DIR}|$install_dir|g" \
        -e "s|{CONFIG_DIR}|$config_dir|g" \
        "$template" | sudo tee "$target" > /dev/null
    
    sudo systemctl daemon-reload
    
    # 启用开机自启
    sudo systemctl enable "$service_name" 2>/dev/null
    
    log_info "$service_name 服务已安装"
}

# ===== 服务操作 =====
start_service() {
    local service=$1
    
    case $(get_service_status "$service") in
        running)
            log_warn "$service 已在运行"
            return 0
            ;;
        stopped)
            sudo systemctl start "$service"
            ;;
        not-installed)
            log_error "$service 未安装"
            return 1
            ;;
    esac
    
    sleep 1
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        log_info "$service 已启动"
        return 0
    else
        log_error "$service 启动失败"
        journalctl -u "$service" -n 10 --no-pager
        return 1
    fi
}

stop_service() {
    local service=$1
    
    case $(get_service_status "$service") in
        running)
            sudo systemctl stop "$service"
            log_info "$service 已停止"
            ;;
        stopped|not-installed)
            log_warn "$service 未运行"
            ;;
    esac
}

restart_service() {
    local service=$1
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        sudo systemctl restart "$service"
        log_info "$service 已重启"
    else
        start_service "$service"
    fi
}

# ===== 手动进程管理 =====
start_manual() {
    local bin_path="$1"
    local config_dir="$2"
    local cache_dir="$HOME/.cache/mihomo"
    local log_file="$cache_dir/mihomo.log"
    local pid_file="$cache_dir/mihomo.pid"
    
    mkdir -p "$cache_dir"
    
    # 检查是否已运行
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_warn "mihomo 已在运行 (PID: $pid)"
            return 0
        fi
        rm -f "$pid_file"
    fi
    
    # 启动
    nohup "$bin_path" -d "$config_dir" > "$log_file" 2>&1 &
    local pid=$!
    echo $pid > "$pid_file"
    
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        log_info "mihomo 已启动 (PID: $pid)"
        return 0
    else
        log_error "mihomo 启动失败"
        rm -f "$pid_file"
        return 1
    fi
}

stop_manual() {
    local pid_file="$HOME/.cache/mihomo/mihomo.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid"
            fi
            log_info "mihomo 已停止"
        fi
        rm -f "$pid_file"
    fi
}
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n lib/service.sh
echo "Exit code: $?"
```

- [ ] **Step 3: 提交**

```bash
git add lib/service.sh
git commit -m "feat: add service management library"
```

---

### Task 5: 创建服务模板 templates/

**Files:**
- Create: `templates/mihomo.service`
- Create: `templates/mihomo-tun.service`
- Create: `templates/config.yaml`

- [ ] **Step 1: 创建 templates/mihomo.service**

```ini
[Unit]
Description=Mihomo (Clash.Meta) Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User={USER}
Group={USER}
Environment=HOME={HOME}
ExecStartPre=/bin/mkdir -p {HOME}/.cache/mihomo
ExecStartPre=-{BIN_DIR}/mihomo-auto-update --silent
ExecStart={BIN_DIR}/mihomo-core -d {CONFIG_DIR}
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

StandardOutput=journal
StandardError=journal
SyslogIdentifier=mihomo

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 2: 创建 templates/mihomo-tun.service**

```ini
[Unit]
Description=Mihomo (Clash.Meta) Proxy Service with TUN
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User={USER}
Group={USER}
Environment=HOME={HOME}

# TUN 设备会在 mihomo 启动时自动创建
ExecStartPre=/bin/mkdir -p {HOME}/.cache/mihomo
ExecStartPre=-{BIN_DIR}/mihomo-auto-update --silent
ExecStart={BIN_DIR}/mihomo-core -d {CONFIG_DIR}
ExecReload=/bin/kill -HUP $MAINPID

Restart=always
RestartSec=5
TimeoutStopSec=30
TimeoutStartSec=30
SuccessExitStatus=0 143
KillMode=control-group
LimitNOFILE=65535

StandardOutput=journal
StandardError=journal
SyslogIdentifier=mihomo

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 3: 创建 templates/config.yaml**

```yaml
# mihomo-quick 配置文件
# 此文件由安装脚本生成，可通过 mihomo-menu 管理

# ===== 基础设置 =====
mixed-port: {HTTP_PORT}
socks-port: {SOCKS_PORT}
allow-lan: true
bind-address: '*'
mode: rule
log-level: info
external-controller: 127.0.0.1:{API_PORT}
secret: '{API_SECRET}'
external-ui: {CONFIG_DIR}/dashboard

# ===== DNS 设置 =====
dns:
  enable: true
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '*.lan'
    - localhost.ptlogin2.qq.com
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
    - tls://dns.alidns.com
    - tls://dot.pub

# ===== TUN 模式 =====
tun:
  enable: {TUN_ENABLE}
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true
  device: {TUN_DEVICE}
  mtu: 9000
  strict-route: true
  gateway: {TUN_GATEWAY}

# ===== GeoX 数据 =====
geox-url:
  geoip: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"
  geosite: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
  mmdb: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb"

# ===== 订阅配置 =====
proxy-providers: {}

# ===== 代理组 =====
proxy-groups: []

# ===== 规则 =====
rules:
  - DOMAIN-SUFFIX,anthropic.com,DIRECT
  - DOMAIN-SUFFIX,bigmodel.cn,DIRECT
  - DOMAIN-SUFFIX,dataeyes.ai,DIRECT
  - DOMAIN-SUFFIX,openai.com,DIRECT
  - DOMAIN-SUFFIX,openrouter.ai,DIRECT
  - DOMAIN-SUFFIX,volcengine.com,DIRECT
  - DOMAIN-SUFFIX,volces.com,DIRECT
  - DOMAIN-SUFFIX,xiaomimimo.com,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - GEOSITE,cn,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,DIRECT
```

- [ ] **Step 4: 验证模板语法**

```bash
bash -n templates/mihomo.service
bash -n templates/mihomo-tun.service
python3 -c "import yaml; yaml.safe_load(open('templates/config.yaml').read().replace('{HTTP_PORT}','7890').replace('{SOCKS_PORT}','7891').replace('{API_PORT}','9090').replace('{API_SECRET}','').replace('{CONFIG_DIR}','/root/.config/mihomo').replace('{TUN_ENABLE}','false').replace('{TUN_DEVICE}','tun0').replace('{TUN_GATEWAY}','10.0.0.1'))"
echo "Exit code: $?"
```

- [ ] **Step 5: 提交**

```bash
git add templates/
git commit -m "feat: add service and config templates"
```

---

### Task 6: 重构 install.sh 主安装脚本

**Files:**
- Modify: `install.sh`

**Interfaces:**
- Consumes: lib/common.sh, lib/detect.sh, lib/network.sh, lib/service.sh
- Produces: 完整的安装流程

- [ ] **Step 1: 重写 install.sh**

```bash
#!/bin/bash
# install.sh - mihomo-quick 通用安装脚本
set -e

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 加载函数库
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/service.sh"

# ===== 配置变量 =====
DEFAULT_INSTALL_DIR="$HOME/.local/bin"
DEFAULT_CONFIG_DIR="$HOME/.config/mihomo"
MIHOMO_BIN="$DEFAULT_INSTALL_DIR/mihomo-core"

# ===== 显示系统信息 =====
show_system_info() {
    log_title "mihomo-quick 安装程序"
    
    echo -e "${WHITE}系统信息:${NC}"
    echo "  发行版: $(detect_distro_name)"
    echo "  架构:   $(detect_arch)"
    echo "  用户:   $(whoami)"
    echo ""
    
    echo -e "${WHITE}安装配置:${NC}"
    echo "  mihomo:  $MIHOMO_BIN"
    echo "  配置:    $DEFAULT_CONFIG_DIR/"
    echo "  脚本:    $DEFAULT_INSTALL_DIR/"
    echo ""
}

# ===== 1. 检查依赖 =====
install_deps() {
    log_step "检查依赖"
    check_dependencies curl python3 tar gzip || die "请先安装缺少的依赖"
    log_info "依赖检查通过"
}

# ===== 2. 安装 mihomo =====
install_mihomo() {
    log_step "安装 mihomo"
    
    mkdir -p "$(dirname "$MIHOMO_BIN")"
    
    local current=""
    if [ -x "$MIHOMO_BIN" ]; then
        current=$("$MIHOMO_BIN" -v 2>/dev/null | grep -oP 'v[\d.]+' | head -1 || echo "")
    fi
    
    local latest=$(get_latest_release "MetaCubeX/mihomo")
    local arch=$(detect_arch)
    
    if [ -n "$current" ]; then
        echo "  当前版本: $current"
        echo "  最新版本: ${latest:-未知}"
        
        if [ -n "$latest" ] && [ "$current" = "$latest" ]; then
            log_info "已是最新版本"
            return 0
        fi
        
        if ! confirm "是否更新到 $latest？" "Y"; then
            return 0
        fi
    fi
    
    if [ -z "$latest" ]; then
        log_error "获取最新版本失败"
        echo ""
        echo "请手动下载 mihomo:"
        echo "  1. 访问: https://github.com/MetaCubeX/mihomo/releases"
        echo "  2. 下载: mihomo-linux-${arch}-<版本>.gz"
        echo "  3. 解压并放到: $MIHOMO_BIN"
        echo ""
        
        if ! confirm "已完成手动下载？" "N"; then
            return 1
        fi
        
        if [ ! -x "$MIHOMO_BIN" ]; then
            log_error "未找到 mihomo: $MIHOMO_BIN"
            return 1
        fi
        return 0
    fi
    
    echo "  下载 mihomo $latest ($arch)..."
    local url="https://github.com/MetaCubeX/mihomo/releases/download/$latest/mihomo-linux-${arch}-${latest}.gz"
    local temp="/tmp/mihomo.gz"
    
    if ! download_with_mirrors "$url" "$temp" "mihomo"; then
        return 1
    fi
    
    # 备份旧版本
    backup_file "$MIHOMO_BIN" "/tmp" > /dev/null 2>&1 || true
    
    gunzip -c "$temp" > "$MIHOMO_BIN"
    chmod +x "$MIHOMO_BIN"
    rm -f "$temp"
    
    log_info "mihomo 已安装: $MIHOMO_BIN"
    "$MIHOMO_BIN" -v 2>/dev/null || true
}

# ===== 3. 安装 Dashboard =====
install_dashboard() {
    log_step "安装 MetaCubeXD 面板"
    
    local dash_dir="$DEFAULT_CONFIG_DIR/dashboard"
    mkdir -p "$dash_dir"
    
    if [ -f "$dash_dir/index.html" ]; then
        log_info "面板已安装"
        if ! confirm "是否更新面板？" "N"; then
            return 0
        fi
    fi
    
    local latest=$(get_latest_release "MetaCubeX/metacubexd")
    if [ -z "$latest" ]; then
        log_warn "获取面板版本失败，跳过"
        return 0
    fi
    
    echo "  下载 MetaCubeXD $latest..."
    local url="https://github.com/MetaCubeX/metacubexd/releases/download/$latest/compressed-dist.tgz"
    local temp="/tmp/metacubexd.tgz"
    
    if ! download_with_mirrors "$url" "$temp" "Dashboard"; then
        return 1
    fi
    
    # 备份旧面板
    backup_file "$dash_dir/index.html" "/tmp" > /dev/null 2>&1 || true
    
    if tar -xzf "$temp" -C "$dash_dir" 2>/dev/null; then
        rm -f "$temp"
        log_info "MetaCubeXD 已安装"
    else
        rm -f "$temp"
        log_error "面板解压失败"
        return 1
    fi
}

# ===== 4. 安装脚本 =====
install_scripts() {
    log_step "安装管理脚本"
    
    mkdir -p "$DEFAULT_INSTALL_DIR"
    
    local scripts=(
        scripts/mihomo-menu       mihomo
        scripts/mihomo-start      mihomo-start
        scripts/mihomo-stop       mihomo-stop
        scripts/mihomo-check      mihomo-check
        scripts/mihomo-rollback   mihomo-rollback
        scripts/mihomo-logs       mihomo-logs
        scripts/mihomo-add-sub    mihomo-add-sub
        scripts/mihomo-rules      mihomo-rules
        scripts/mihomo-update     mihomo-update
        scripts/mihomo-auto-update mihomo-auto-update
        scripts/set-proxy-env     set-proxy-env
        scripts/proxy-env         proxy-env
        scripts/test-all-proxy    test-all-proxy
    )
    
    local installed=0
    for ((i=0; i<${#scripts[@]}; i+=2)); do
        local src="${scripts[$i]}"
        local name="${scripts[$i+1]}"
        
        if [ -f "$SCRIPT_DIR/$src" ]; then
            cp "$SCRIPT_DIR/$src" "$DEFAULT_INSTALL_DIR/$name"
            chmod +x "$DEFAULT_INSTALL_DIR/$name"
            ((installed++))
        fi
    done
    
    # 复制卸载脚本
    if [ -f "$SCRIPT_DIR/uninstall.sh" ]; then
        cp "$SCRIPT_DIR/uninstall.sh" "$DEFAULT_INSTALL_DIR/mihomo-uninstall"
        chmod +x "$DEFAULT_INSTALL_DIR/mihomo-uninstall"
    fi
    
    log_info "已安装 $installed 个脚本到 $DEFAULT_INSTALL_DIR/"
}

# ===== 5. 创建配置 =====
install_config() {
    log_step "创建配置"
    
    mkdir -p "$DEFAULT_CONFIG_DIR"
    mkdir -p "$DEFAULT_CONFIG_DIR/providers"
    mkdir -p "$DEFAULT_CONFIG_DIR/backups"
    
    if [ -f "$DEFAULT_CONFIG_DIR/config.yaml" ]; then
        log_info "配置文件已存在"
        if confirm "是否用默认配置覆盖？" "N"; then
            backup_file "$DEFAULT_CONFIG_DIR/config.yaml" "$DEFAULT_CONFIG_DIR/backups"
            generate_config
        fi
    else
        generate_config
    fi
    
    # 复制 geoip/geosite 数据
    for f in geoip.metadb geosite.dat; do
        if [ -f "$SCRIPT_DIR/config/$f" ] && [ ! -f "$DEFAULT_CONFIG_DIR/$f" ]; then
            cp "$SCRIPT_DIR/config/$f" "$DEFAULT_CONFIG_DIR/$f"
        fi
    done
    
    log_info "配置已创建: $DEFAULT_CONFIG_DIR/config.yaml"
}

# 生成配置文件
generate_config() {
    local http_port=$(find_available_port 7890)
    local socks_port=$(find_available_port 7891)
    local api_port=$(find_available_port 9090)
    local api_secret=$(openssl rand -hex 16 2>/dev/null || echo "")
    local tun_device=$(detect_tun_device 2>/dev/null || echo "tun0")
    local tun_enable="false"
    local tun_gateway="10.0.0.1"
    
    # 检查是否启用 TUN
    if [ -c /dev/net/tun ]; then
        if confirm "是否启用 TUN 模式（透明代理）？" "N"; then
            tun_enable="true"
        fi
    fi
    
    sed \
        -e "s|{HTTP_PORT}|$http_port|g" \
        -e "s|{SOCKS_PORT}|$socks_port|g" \
        -e "s|{API_PORT}|$api_port|g" \
        -e "s|{API_SECRET}|$api_secret|g" \
        -e "s|{CONFIG_DIR}|$DEFAULT_CONFIG_DIR|g" \
        -e "s|{TUN_ENABLE}|$tun_enable|g" \
        -e "s|{TUN_DEVICE}|$tun_device|g" \
        -e "s|{TUN_GATEWAY}|$tun_gateway|g" \
        "$SCRIPT_DIR/templates/config.yaml" > "$DEFAULT_CONFIG_DIR/config.yaml"
    
    echo "  端口: HTTP=$http_port, SOCKS5=$socks_port, API=$api_port"
    [ -n "$api_secret" ] && echo "  API密钥: $api_secret"
}

# ===== 6. 安装 systemd 服务 =====
install_systemd() {
    log_step "配置 systemd 服务"
    
    if ! command -v systemctl &>/dev/null; then
        log_warn "systemctl 不可用，跳过服务安装"
        return 0
    fi
    
    local service_user=$(get_service_user)
    
    echo -e "${WHITE}普通模式 (mihomo.service):${NC}"
    install_service "mihomo" "$service_user" "$DEFAULT_INSTALL_DIR" "$DEFAULT_CONFIG_DIR" "$SCRIPT_DIR/templates"
    
    echo ""
    echo -e "${WHITE}TUN 模式 (mihomo-tun.service):${NC}"
    install_service "mihomo-tun" "$service_user" "$DEFAULT_INSTALL_DIR" "$DEFAULT_CONFIG_DIR" "$SCRIPT_DIR/templates"
}

# ===== 7. 配置环境变量 =====
setup_env() {
    log_step "配置环境变量"
    
    if grep -q 'set-proxy-env' "$HOME/.bashrc" 2>/dev/null; then
        log_info "代理环境变量已配置"
        return 0
    fi
    
    echo ""
    echo "  需要将以下内容添加到 ~/.bashrc:"
    echo ""
    echo "    source ~/.local/bin/set-proxy-env"
    echo ""
    
    if confirm "是否自动添加？" "Y"; then
        cat "$SCRIPT_DIR/bashrc-snippet.sh" >> "$HOME/.bashrc"
        log_info "已添加到 ~/.bashrc"
        echo "  执行 'source ~/.bashrc' 立即生效"
    fi
}

# ===== 主流程 =====
show_system_info

if ! confirm "开始安装？" "Y"; then
    echo "已取消"
    exit 0
fi

echo ""
install_deps
install_mihomo
install_dashboard
install_scripts
install_config
install_systemd
setup_env

echo ""
log_title "安装完成"
echo ""
echo -e "${WHITE}快速开始:${NC}"
echo "  1. source ~/.bashrc           # 加载代理环境"
echo "  2. mihomo                     # 打开管理菜单"
echo ""
echo -e "${WHITE}命令速查:${NC}"
echo "  mihomo                        打开管理菜单"
echo "  mihomo-update                 检查更新"
echo "  mihomo-add-sub                添加订阅"
echo "  mihomo-check                  校验配置"
echo ""
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n install.sh
echo "Exit code: $?"
```

- [ ] **Step 3: 提交**

```bash
git add install.sh lib/ templates/
git commit -m "refactor: universal install script with auto-detection"
```

---

### Task 7: 重构 scripts/ 管理脚本

**Files:**
- Modify: `scripts/mihomo-menu`
- Modify: `scripts/mihomo-add-sub`
- Modify: `scripts/mihomo-rules`

**说明:** 由于这些脚本较大，这里只展示关键改动点

- [ ] **Step 1: 更新 mihomo-menu 添加库引用**

在每个脚本开头添加:
```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/detect.sh"
source "$LIB_DIR/service.sh"
```

- [ ] **Step 2: 更新 mihomo-add-sub 的 YAML 处理**

将内嵌的 Python 代码提取为独立函数，添加错误处理:
```python
#!/usr/bin/env python3
"""mihomo-add-sub helper - 订阅管理辅助脚本"""
import yaml
import sys
import os

def add_provider(config_file, name, url, interval, role, proxy_chain=None):
    # ... 实现
    pass

if __name__ == "__main__":
    # 命令行接口
    pass
```

- [ ] **Step 3: 更新 mihomo-rules 移除 OpenClaw 硬编码**

移除 `OPENCLAW_CONFIG` 相关代码，改为可配置:
```bash
# 可选：从外部配置同步域名
if [ -n "${1:-}" ] && [ -f "$1" ]; then
    sync_from_config "$1"
fi
```

- [ ] **Step 4: 提交**

```bash
git add scripts/
git commit -m "refactor: update scripts to use common libraries"
```

---

### Task 8: 重构 setup-service.sh

**Files:**
- Modify: `setup-service.sh`

- [ ] **Step 1: 简化 setup-service.sh**

```bash
#!/bin/bash
# setup-service.sh - 快捷服务安装
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/service.sh"

SERVICE_MODE="${1:-normal}"

log_title "mihomo systemd 服务安装"

if ! command -v systemctl &>/dev/null; then
    die "systemctl 不可用"
fi

# 选择模式
if [ "$SERVICE_MODE" = "tun" ]; then
    SERVICE_NAME="mihomo-tun"
    echo -e "${YELLOW}模式: TUN (透明代理)${NC}"
else
    SERVICE_NAME="mihomo"
    echo -e "模式: 普通 (HTTP/SOCKS5)"
fi

# 检查 mihomo
MIHOMO_BIN="$HOME/.local/bin/mihomo-core"
if [ ! -x "$MIHOMO_BIN" ]; then
    die "mihomo 未安装: $MIHOMO_BIN"
fi

# 安装服务
SERVICE_USER=$(get_service_user)
install_service "$SERVICE_NAME" "$SERVICE_USER" "$HOME/.local/bin" "$HOME/.config/mihomo" "$SCRIPT_DIR/templates"

# 询问是否启动
if confirm "是否立即启动服务？" "Y"; then
    start_service "$SERVICE_NAME"
fi

echo ""
echo -e "${CYAN}常用命令:${NC}"
echo "  systemctl start $SERVICE_NAME"
echo "  systemctl stop $SERVICE_NAME"
echo "  systemctl status $SERVICE_NAME"
```

- [ ] **Step 2: 验证脚本语法**

```bash
bash -n setup-service.sh
echo "Exit code: $?"
```

- [ ] **Step 3: 提交**

```bash
git add setup-service.sh
git commit -m "refactor: simplify setup-service with common libraries"
```

---

### Task 9: 更新 .gitignore 和清理

**Files:**
- Modify: `.gitignore`
- Delete: `systemd/` (已迁移到 templates/)

- [ ] **Step 1: 更新 .gitignore**

```gitignore
# 系统文件
.DS_Store
*.swp
*.swo
*~

# 运行时文件
*.pid
*.log

# 备份文件
*.bak.*
*.bak

# 临时文件
/tmp/
```

- [ ] **Step 2: 移除旧的 systemd 目录**

```bash
git rm -r systemd/
```

- [ ] **Step 3: 提交**

```bash
git add .gitignore
git commit -m "chore: cleanup and update gitignore"
```

---

### Task 10: 更新 README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 更新 README 添加通用化说明**

```markdown
# mihomo-quick

轻量级 mihomo (Clash.Meta) 通用部署工具，支持任意 Linux 发行版。

## 特性

- ✅ **通用支持**: 适配 Ubuntu/Debian, CentOS/RHEL, Arch Linux
- ✅ **自动检测**: TUN 设备、可用端口、系统架构
- ✅ **安全默认**: API 绑定 localhost，随机密钥
- ✅ **离线安装**: 预打包 GeoIP/GeoSite 数据库
- ✅ **一键部署**: 自动下载、配置、安装服务

## 系统要求

- Linux (Ubuntu 18+, CentOS 7+, Arch Linux)
- x86_64 / aarch64 / armv7 架构
- 依赖: curl, python3, tar, gzip

## 安装

\```bash
git clone https://github.com/liu10332/mihomo-quick.git
cd mihomo-quick
./install.sh
\```

## 自动检测

安装脚本会自动检测并配置:

| 项目 | 说明 |
|------|------|
| 架构 | x86_64, aarch64, armv7 |
| 发行版 | Ubuntu, Debian, CentOS, RHEL, Arch |
| TUN 设备 | 自动检测可用设备名 |
| 端口 | 自动检测可用端口避免冲突 |
| 防火墙 | 自动配置 ufw/firewalld/iptables |

## 安全特性

- API 默认绑定 `127.0.0.1` 而非 `0.0.0.0`
- 自动生成随机 API 密钥
- 支持非 root 用户运行服务
```

- [ ] **Step 2: 提交**

```bash
git add README.md
git commit -m "docs: update README for universal support"
```

---

## 执行顺序

1. Task 1-4: 创建函数库 (可并行)
2. Task 5: 创建模板
3. Task 6: 重构 install.sh
4. Task 7-8: 重构管理脚本
5. Task 9-10: 清理和文档

## 验证方法

```bash
# 1. 语法检查
find lib/ scripts/ -name "*.sh" -exec bash -n {} \;

# 2. 功能测试
./install.sh  # 在测试环境运行

# 3. 服务测试
sudo systemctl start mihomo
curl -x http://127.0.0.1:7890 https://www.google.com
```
