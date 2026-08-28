#!/bin/bash
# network.sh - mihomo-quick 网络工具库
# 下载、镜像回退、防火墙、SELinux、DNS/网络测试

# 防止重复加载
[[ -n "${_NETWORK_SH_LOADED:-}" ]] && return 0
_NETWORK_SH_LOADED=1

# ===== 加载依赖 =====

SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_LIB_DIR/common.sh"
[[ -f "$SCRIPT_LIB_DIR/detect.sh" ]] && source "$SCRIPT_LIB_DIR/detect.sh"

# ===== GitHub 镜像站点 =====
# 仅保留实测可用的镜像（失效镜像会各消耗 10s+ 超时，拖慢下载）

GITHUB_MIRRORS=(
    "https://ghfast.top"
    "https://gh-proxy.com"
)

# ===== 下载函数 =====

# validate_download FILE URL
# 按文件类型校验下载完整性：gzip 类文件校验 gzip 流完整性，
# 防止连接被重置导致的截断文件被当作下载成功
validate_download() {
    local file="$1"
    local url="$2"

    [[ -s "$file" ]] || return 1

    case "$url" in
        *.gz|*.tgz)
            gzip -t "$file" 2>/dev/null
            ;;
        *)
            return 0
            ;;
    esac
}

# download_with_mirrors URL OUTPUT DESC
# 依次尝试镜像站点和直连，自动重试并校验完整性，返回 0 成功 / 1 失败
download_with_mirrors() {
    local url="$1"
    local output="$2"
    local desc="${3:-file}"

    # 构建下载源列表：镜像 + 直连
    local sources=()
    for mirror in "${GITHUB_MIRRORS[@]}"; do
        sources+=("${mirror}/${url}")
    done
    sources+=("$url")

    local source
    for source in "${sources[@]}"; do
        log_step "下载 $desc: ${source:0:80}..."
        # -f: HTTP 4xx/5xx 直接判定失败，不把错误页写入文件
        # --retry: 单源内自动重试，缓解偶发的连接重置/截断
        if curl -fL --connect-timeout 10 --max-time 600 \
            --retry 2 --retry-delay 1 \
            -o "$output" "$source" 2>/dev/null \
            && validate_download "$output" "$url"; then
            log_info "$desc 下载成功"
            return 0
        fi
        rm -f "$output"
    done

    log_error "$desc 下载失败（所有源均不可用）"
    return 1
}

# ===== GitHub Release =====

# get_latest_release REPO
# 获取 GitHub 仓库最新 release tag，如 MetaCubeX/mihomo
get_latest_release() {
    local repo="$1"

    # 尝试通过 API 获取
    local tag
    tag=$(curl -s --connect-timeout 5 --max-time 10 \
        "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    if [[ -n "$tag" ]]; then
        echo "$tag"
        return 0
    fi

    # 备选 1：通过 tags 接口
    tag=$(curl -s --connect-timeout 5 --max-time 10 \
        "https://api.github.com/repos/$repo/tags" 2>/dev/null \
        | grep '"name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

    if [[ -n "$tag" ]]; then
        echo "$tag"
        return 0
    fi

    # 备选 2：通过 releases/latest 重定向获取（api.github.com 不可达时仍可用）
    tag=$(curl -sIL -o /dev/null -w '%{url_effective}' --connect-timeout 5 --max-time 10 \
        "https://github.com/$repo/releases/latest" 2>/dev/null \
        | grep -o '/tag/[^?/]*' | cut -d/ -f3)

    [[ -n "$tag" ]] && echo "$tag"
}

# ===== 防火墙配置 =====

# configure_firewall PORT PROTO
# 自动检测防火墙工具并开放端口
# PROTO 默认 tcp
configure_firewall() {
    local port="$1"
    local proto="${2:-tcp}"

    if [[ -z "$port" ]]; then
        log_error "configure_firewall: 需要指定端口号"
        return 1
    fi

    log_step "配置防火墙 (端口 $port/$proto)..."

    # ufw
    if command -v ufw &>/dev/null; then
        if ufw status | grep -q "Status: active"; then
            ufw allow "$port/$proto" >/dev/null 2>&1
            log_info "ufw: 已允许 $port/$proto"
            return 0
        fi
        log_info "uffw 未启用，跳过"
        return 0
    fi

    # firewalld
    if command -v firewall-cmd &>/dev/null; then
        if systemctl is-active --quiet firewalld 2>/dev/null; then
            firewall-cmd --permanent --add-port="$port/$proto" >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            log_info "firewalld: 已允许 $port/$proto"
            return 0
        fi
        log_info "firewalld 未运行，跳过"
        return 0
    fi

    # iptables (仅提示，不自动操作)
    if command -v iptables &>/dev/null; then
        log_warn "检测到 iptables，建议手动添加规则:"
        log_warn "  sudo iptables -A INPUT -p $proto --dport $port -j ACCEPT"
        return 0
    fi

    log_warn "未检测到防火墙工具，无需配置"
    return 0
}

# ===== SELinux 配置 =====

# configure_selinux PORT
# 如果 SELinux 为 enforcing 状态，为指定端口添加策略
configure_selinux() {
    local port="$1"

    # 检查 SELinux 是否存在且为 enforcing
    if ! command -v getenforce &>/dev/null; then
        return 0
    fi

    local mode
    mode=$(getenforce 2>/dev/null)
    if [[ "$mode" != "Enforcing" ]]; then
        return 0
    fi

    log_step "SELinux 为 enforcing 模式，配置端口 $port..."

    # 检查端口类型是否已存在
    if semanage port -l 2>/dev/null | grep -q "$port"; then
        log_info "SELinux: 端口 $port 已有策略"
        return 0
    fi

    # 添加端口策略
    if command -v semanage &>/dev/null; then
        semanage port -a -t http_port_t -p tcp "$port" 2>/dev/null || \
        semanage port -m -t http_port_t -p tcp "$port" 2>/dev/null
        log_info "SELinux: 已为端口 $port 添加策略"
        return 0
    fi

    log_warn "SELinux enforcing 但 semanage 不可用，建议手动配置"
    log_warn "  sudo semanage port -a -t http_port_t -p tcp $port"
    return 0
}

# ===== DNS 测试 =====

# test_dns_resolve DOMAIN
# 测试 DNS 解析，返回 0 成功 / 1 失败
test_dns_resolve() {
    local domain="${1:-github.com}"

    log_step "测试 DNS 解析 ($domain)..."

    # 方法1: dig
    if command -v dig &>/dev/null; then
        if dig +short "$domain" 2>/dev/null | grep -q '[0-9]'; then
            log_info "DNS 解析成功: $domain"
            return 0
        fi
    fi

    # 方法2: nslookup
    if command -v nslookup &>/dev/null; then
        if nslookup "$domain" 2>/dev/null | grep -q 'Address:'; then
            log_info "DNS 解析成功: $domain"
            return 0
        fi
    fi

    # 方法3: getent
    if getent hosts "$domain" &>/dev/null; then
        log_info "DNS 解析成功: $domain"
        return 0
    fi

    log_error "DNS 解析失败: $domain"
    return 1
}

# ===== 网络连通性测试 =====

# test_network [HOST] [PORT]
# 测试网络连通性，HOST 默认 8.8.8.8，PORT 默认 53
test_network() {
    local host="${1:-8.8.8.8}"
    local port="${2:-53}"

    log_step "测试网络连通性 ($host:$port)..."

    # 方法1: 端口探测
    if command -v nc &>/dev/null; then
        if nc -z -w3 "$host" "$port" 2>/dev/null; then
            log_info "网络连通: $host:$port"
            return 0
        fi
    fi

    # 方法2: bash /dev/tcp
    if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
        log_info "网络连通: $host:$port"
        return 0
    fi

    # 方法3: curl 测试
    if command -v curl &>/dev/null; then
        if curl -s --connect-timeout 5 --max-time 10 -o /dev/null \
            "https://www.gstatic.com/generate_204" 2>/dev/null; then
            log_info "网络连通: HTTPS 正常"
            return 0
        fi
    fi

    log_error "网络不通: $host:$port"
    return 1
}
