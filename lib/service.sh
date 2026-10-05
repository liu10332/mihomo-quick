#!/bin/bash
# service.sh - mihomo-quick 服务管理函数库
# 管理 systemd 服务和手动进程

[[ -n "${_SERVICE_SH_LOADED:-}" ]] && return 0
_SERVICE_SH_LOADED=1

# 引入依赖
SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_LIB_DIR/common.sh"
[[ -f "$SCRIPT_LIB_DIR/detect.sh" ]] && source "$SCRIPT_LIB_DIR/detect.sh"

# ===== 常量 =====

MIHOMO_BIN="${HOME}/.local/bin/mihomo-core"
CONFIG_DIR="${HOME}/.config/mihomo"
CACHE_DIR="${HOME}/.cache/mihomo"
PID_FILE="${CACHE_DIR}/mihomo.pid"
LOG_FILE="${CACHE_DIR}/mihomo.log"

SERVICE_NAME_MIHOMO="mihomo"
SERVICE_NAME_TUN="mihomo-tun"
SYSTEMD_DIR="/etc/systemd/system"

# 服务模板路径: 兼容安装布局(~/.mihomo-quick/systemd)与仓库布局(systemd/ 或 templates/)
SERVICE_FILE_MIHOMO=""
SERVICE_FILE_TUN=""
for _svc_tpl_dir in "$SCRIPT_LIB_DIR/../systemd" "$SCRIPT_LIB_DIR/../templates"; do
    if [[ -f "${_svc_tpl_dir}/mihomo.service" ]]; then
        SERVICE_FILE_MIHOMO="${_svc_tpl_dir}/mihomo.service"
        SERVICE_FILE_TUN="${_svc_tpl_dir}/mihomo-tun.service"
        break
    fi
done
if [[ -z "$SERVICE_FILE_MIHOMO" ]]; then
    SERVICE_FILE_MIHOMO="${SCRIPT_LIB_DIR}/../systemd/mihomo.service"
    SERVICE_FILE_TUN="${SCRIPT_LIB_DIR}/../systemd/mihomo-tun.service"
fi

# ===== 服务模板渲染与自检 =====

# assert_service_unit_safe FILE MODE
# 渲染结果自检：坏 unit 不如不装。MODE = normal | tun
# 背景：TUN 模板曾带 User={USER} + `ip tuntap` 预处理 + *_PROXY 环境变量，
# 跑 setup-service.sh tun 会装出一个起不来的服务（TUNSETIFF 需要 root，
# `-` 前缀把 ip 命令的失败藏起来，代理环境变量让启动前的下载连不上还没起来的 7890）。
assert_service_unit_safe() {
    local file="$1" mode="${2:-normal}" content

    if [[ ! -f "$file" ]]; then
        log_error "服务文件不存在: $file"
        return 1
    fi

    # 注释行不参与检查（注释里可能字面提到 User= / ip tuntap）
    content=$(grep -vE '^[[:space:]]*[#;]' "$file" 2>/dev/null || true)

    if [[ "$mode" == "tun" ]]; then
        if printf '%s\n' "$content" | grep -qE '^[[:space:]]*(User|Group)='; then
            log_error "拒绝安装: TUN 模式不能指定 User=/Group=（TUNSETIFF 与 auto-route 需要 root，普通用户报 Operation not permitted）"
            return 1
        fi
        if printf '%s\n' "$content" | grep -qE '^Exec(StartPre|StopPost)=.*(ip[[:space:]]+(tuntap|addr|link))'; then
            log_error "拒绝安装: TUN 模板不要预建/清理网卡（设备由 mihomo 自己创建，带 '-' 的 ip 命令只会掩盖失败）"
            return 1
        fi
        if printf '%s\n' "$content" | grep -qiE '^Environment=.*_PROXY='; then
            log_error "拒绝安装: TUN 模板不能设置 *_PROXY（启动前的下载会去连还没启动的代理端口）"
            return 1
        fi
    fi

    local leftover
    leftover=$(printf '%s\n' "$content" | grep -o '{[A-Z_]*}' 2>/dev/null | sort -u | tr '\n' ' ' || true)
    if [[ -n "${leftover// /}" ]]; then
        log_error "拒绝安装: 模板仍有未替换占位符: $leftover"
        return 1
    fi

    return 0
}

# write_service_unit TEMPLATE TARGET MODE USER BIN_DIR [TUN_DEVICE] [TUN_GATEWAY]
# 渲染模板 → 自检 → 写入 TARGET → daemon-reload。自检不过则不写入，返回 1。
write_service_unit() {
    local template="$1" target="$2" mode="$3" unit_user="$4" bin_dir="$5"
    local tun_device="${6:-}" tun_gateway="${7:-}"
    local rendered rc

    if [[ ! -f "$template" ]]; then
        log_error "服务模板不存在: $template"
        return 1
    fi

    rendered=$(mktemp) || return 1

    sed -e "s/{USER}/$unit_user/g" \
        -e "s|{HOME}|$HOME|g" \
        -e "s|{BIN_DIR}|$bin_dir|g" \
        -e "s|{CONFIG_DIR}|$CONFIG_DIR|g" \
        -e "s/{TUN_DEVICE}/$tun_device/g" \
        -e "s/{TUN_GATEWAY}/$tun_gateway/g" \
        -e "s|/root|$HOME|g" \
        "$template" > "$rendered"

    if ! assert_service_unit_safe "$rendered" "$mode"; then
        rm -f "$rendered"
        log_error "已中止，未写入 $target"
        return 1
    fi

    sudo tee "$target" < "$rendered" > /dev/null
    rc=$?
    rm -f "$rendered"
    if [[ $rc -ne 0 ]]; then
        log_error "写入失败: $target"
        return 1
    fi

    sudo systemctl daemon-reload
    return 0
}

# ===== systemd 状态查询 =====

# get_service_status [服务名]
# 输出: "running" | "stopped" | "not-installed"
# 默认同时检查 mihomo 和 mihomo-tun
get_service_status() {
    local name="${1:-}"

    if [[ -n "$name" ]]; then
        _check_one_service_status "$name"
        return
    fi

    # 无参数时返回当前活动服务的状态
    if systemctl is-active --quiet "$SERVICE_NAME_TUN" 2>/dev/null; then
        echo "running"
    elif systemctl is-active --quiet "$SERVICE_NAME_MIHOMO" 2>/dev/null; then
        echo "running"
    else
        # 检查是否手动运行
        if [[ -f "$PID_FILE" ]]; then
            local pid
            pid=$(cat "$PID_FILE" 2>/dev/null)
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                echo "running"
                return
            fi
        fi
        echo "stopped"
    fi
}

_check_one_service_status() {
    local name="$1"

    if ! systemctl list-unit-files "${name}.service" &>/dev/null; then
        echo "not-installed"
        return
    fi

    if systemctl is-active --quiet "$name" 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

# get_active_service
# 输出当前正在运行的服务名: "mihomo" | "mihomo-tun" | "manual" | ""
get_active_service() {
    if systemctl is-active --quiet "$SERVICE_NAME_TUN" 2>/dev/null; then
        echo "$SERVICE_NAME_TUN"
    elif systemctl is-active --quiet "$SERVICE_NAME_MIHOMO" 2>/dev/null; then
        echo "$SERVICE_NAME_MIHOMO"
    elif [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "manual"
        fi
    fi
}

# ===== systemd 服务安装 =====

# install_service [模式: normal|tun]
# 从模板安装 systemd 服务并替换路径变量
install_service() {
    local mode="${1:-normal}"
    local service_name service_file target

    if [[ "$mode" == "tun" ]]; then
        service_name="$SERVICE_NAME_TUN"
        service_file="$SERVICE_FILE_TUN"
    else
        service_name="$SERVICE_NAME_MIHOMO"
        service_file="$SERVICE_FILE_MIHOMO"
    fi

    target="${SYSTEMD_DIR}/${service_name}.service"

    if [[ ! -f "$service_file" ]]; then
        log_error "服务模板不存在: $service_file"
        return 1
    fi

    mkdir -p "$CACHE_DIR"

    # 检查 systemd 是否可用
    if ! command -v systemctl &>/dev/null; then
        log_error "systemctl 不可用，当前系统可能未使用 systemd"
        return 1
    fi

    # 备份已有服务
    if [[ -f "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        sudo cp "$target" "$backup"
        log_info "已备份: $backup"
    fi

    # 变量替换: 填充模板占位符(与 install.sh 保持一致)，并兼容旧模板的 /root 硬编码
    # 渲染 → 自检（坏 unit 直接拒绝）→ 写入 → daemon-reload 都在 write_service_unit 里
    local svc_user svc_tun_device svc_bin_dir
    svc_user=$(detect_current_user)
    svc_tun_device=$(detect_tun_device)
    svc_bin_dir="$HOME/.local/bin"

    if ! write_service_unit "$service_file" "$target" "$mode" "$svc_user" "$svc_bin_dir" \
            "$svc_tun_device" "10.0.0.1"; then
        return 1
    fi
    log_info "服务已安装: $target"

    # 启用开机自启
    sudo systemctl enable "$service_name" 2>/dev/null
    log_info "已设置开机自启"

    return 0
}

# ===== systemd 服务控制 =====

# start_service [服务名]
# 启动 systemd 服务，默认自动检测当前模式
start_service() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        # 自动检测：优先启动当前已安装的
        if systemctl list-unit-files "${SERVICE_NAME_TUN}.service" &>/dev/null; then
            name="$SERVICE_NAME_TUN"
        else
            name="$SERVICE_NAME_MIHOMO"
        fi
    fi

    # 检查是否已安装
    if ! systemctl list-unit-files "${name}.service" &>/dev/null; then
        log_error "服务未安装: ${name}"
        return 1
    fi

    # 检查是否已运行
    if systemctl is-active --quiet "$name" 2>/dev/null; then
        log_warn "${name} 服务已在运行"
        return 0
    fi

    sudo systemctl start "$name"
    sleep 1

    if systemctl is-active --quiet "$name" 2>/dev/null; then
        log_info "${name} 服务已启动"
        return 0
    else
        log_error "${name} 服务启动失败"
        return 1
    fi
}

# stop_service [服务名]
# 停止 systemd 服务，默认停止所有相关服务
stop_service() {
    local name="${1:-}"

    if [[ -n "$name" ]]; then
        _stop_one_service "$name"
        return
    fi

    # 停止所有可能的 mihomo 服务
    local stopped=0
    for svc in "$SERVICE_NAME_TUN" "$SERVICE_NAME_MIHOMO"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            sudo systemctl stop "$svc"
            log_info "${svc} 服务已停止"
            stopped=1
        fi
    done

    # 也停止手动进程
    if [[ -f "$PID_FILE" ]]; then
        stop_manual
        stopped=1
    fi

    if [[ $stopped -eq 0 ]]; then
        log_warn "没有正在运行的 mihomo 服务"
    fi

    return 0
}

_stop_one_service() {
    local name="$1"

    if ! systemctl list-unit-files "${name}.service" &>/dev/null; then
        log_warn "服务未安装: ${name}"
        return 0
    fi

    if ! systemctl is-active --quiet "$name" 2>/dev/null; then
        log_warn "${name} 服务未在运行"
        return 0
    fi

    sudo systemctl stop "$name"
    log_info "${name} 服务已停止"
    return 0
}

# restart_service [服务名]
# 重启 systemd 服务，默认自动检测当前活动服务
restart_service() {
    local name="${1:-}"

    if [[ -z "$name" ]]; then
        name=$(get_active_service)
        if [[ -z "$name" || "$name" == "manual" ]]; then
            # 没有 systemd 服务在运行，尝试启动
            start_service
            return
        fi
    fi

    if ! systemctl is-active --quiet "$name" 2>/dev/null; then
        log_warn "${name} 服务未在运行，尝试启动..."
        start_service "$name"
        return
    fi

    sudo systemctl restart "$name"
    sleep 1

    if systemctl is-active --quiet "$name" 2>/dev/null; then
        log_info "${name} 服务已重启"
        return 0
    else
        log_error "${name} 服务重启失败"
        return 1
    fi
}

# ===== 手动进程管理 =====

# start_manual
# 使用 nohup 启动 mihomo 进程
start_manual() {
    # 检查二进制
    if [[ ! -x "$MIHOMO_BIN" ]]; then
        log_error "mihomo 未安装: $MIHOMO_BIN"
        return 1
    fi

    # 检查配置
    if [[ ! -f "${CONFIG_DIR}/config.yaml" ]]; then
        log_error "配置文件不存在: ${CONFIG_DIR}/config.yaml"
        return 1
    fi

    mkdir -p "$CACHE_DIR"

    # 检查是否已运行
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_warn "mihomo 已在运行 (PID: $pid)"
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi

    # 检查是否有 systemd 服务在运行
    local active
    active=$(get_active_service)
    if [[ "$active" == "$SERVICE_NAME_MIHOMO" || "$active" == "$SERVICE_NAME_TUN" ]]; then
        log_warn "mihomo systemd 服务正在运行 ($active)"
        log_warn "请先停止: mihomo-stop"
        return 1
    fi

    # 启动进程
    nohup "$MIHOMO_BIN" -d "$CONFIG_DIR" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 2

    if kill -0 "$pid" 2>/dev/null; then
        log_info "mihomo 已启动 (PID: $pid)"
        return 0
    else
        log_error "mihomo 启动失败，查看日志: $LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
}

# stop_manual
# 停止手动启动的 mihomo 进程
stop_manual() {
    if [[ ! -f "$PID_FILE" ]]; then
        log_warn "未找到 PID 文件，mihomo 可能未以手动模式运行"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)

    if [[ -z "$pid" ]]; then
        rm -f "$PID_FILE"
        log_warn "PID 文件为空，已清理"
        return 0
    fi

    if ! kill -0 "$pid" 2>/dev/null; then
        log_warn "mihomo 进程 (PID: $pid) 已不存在"
        rm -f "$PID_FILE"
        return 0
    fi

    log_step "正在停止 mihomo (PID: $pid)..."
    kill "$pid"
    sleep 1

    # 等待进程退出，最多 5 秒
    local wait=0
    while kill -0 "$pid" 2>/dev/null && [[ $wait -lt 5 ]]; do
        sleep 1
        wait=$((wait + 1))
    done

    # 仍存活则强制终止
    if kill -0 "$pid" 2>/dev/null; then
        log_warn "进程未响应，强制终止..."
        kill -9 "$pid" 2>/dev/null
        sleep 1
    fi

    rm -f "$PID_FILE"
    log_info "mihomo 已停止"
    return 0
}
