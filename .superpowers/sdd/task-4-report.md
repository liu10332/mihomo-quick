# Task 4: lib/service.sh - Service Management Library

## Status: DONE

## What was created

`lib/service.sh` - 服务管理函数库，管理 systemd 服务和手动进程。

## Functions implemented

| Function | Description |
|----------|-------------|
| `get_service_status [name]` | 返回 `running` / `stopped` / `not-installed`，支持单服务或全局检查 |
| `get_active_service` | 返回当前活动服务名 (`mihomo` / `mihomo-tun` / `manual` / 空) |
| `install_service [mode]` | 从 systemd 模板安装服务，变量替换 `/root` -> `$HOME` |
| `start_service [name]` | 启动 systemd 服务，自动检测模式 |
| `stop_service [name]` | 停止服务，无参数时停止所有相关服务+手动进程 |
| `restart_service [name]` | 重启服务，自动检测当前活动服务 |
| `start_manual` | 使用 nohup 启动 mihomo 进程 |
| `stop_manual` | 停止手动进程，带超时强制终止 |

## Key design decisions

- **Conditional detect.sh sourcing**: `detect.sh` 不确定是否已存在，使用 `[[ -f ]]` 条件加载
- **Idempotent loading**: 使用 `_SERVICE_SH_LOADED` guard 防止重复加载
- **Consistent with existing patterns**: PID 文件路径 (`$CACHE_DIR/mihomo.pid`)、日志路径 (`$CACHE_DIR/mihomo.log`) 与 `mihomo-start`/`mihomo-stop` 一致
- **Service templates**: 使用 `sed "s|/root|$HOME|g"` 替换路径，与 `setup-service.sh` 和 `install.sh` 保持一致
- **Conflict detection**: `start_manual` 检查是否有 systemd 服务在运行，防止冲突

## Test results

- `bash -n lib/service.sh`: syntax OK

## Files touched

- `lib/service.sh` (created)
