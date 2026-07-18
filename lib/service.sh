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

SERVICE_FILE_MIHOMO="${SCRIPT_LIB_DIR}/../systemd/mihomo.service"
SERVICE_FILE_TUN="${SCRIPT_LIB_DIR}/../systemd/mihomo-tun.service"

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

    # 变量替换: /root -> $HOME, 确保路径一致
    sudo sed "s|/root|$HOME|g" "$service_file" | sudo tee "$target" > /dev/null
    sudo systemctl daemon-reload
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
