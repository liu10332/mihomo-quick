# M004 技术研究

## systemd服务集成

### 1. 服务文件格式
```ini
[Unit]
Description=Mihomo Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/path/to/mihomo -d /path/to/config
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 2. 服务管理命令
```bash
# 启动服务
systemctl start mihomo-quick

# 停止服务
systemctl stop mihomo-quick

# 重启服务
systemctl restart mihomo-quick

# 查看状态
systemctl status mihomo-quick

# 启用自启动
systemctl enable mihomo-quick

# 禁用自启动
systemctl disable mihomo-quick
```

## 日志管理

### 1. journalctl命令
```bash
# 查看服务日志
journalctl -u mihomo-quick

# 实时查看日志
journalctl -u mihomo-quick -f

# 查看最近日志
journalctl -u mihomo-quick -n 100

# 按时间过滤
journalctl -u mihomo-quick --since "2026-04-21"
```

### 2. 日志级别
- ERROR: 错误信息
- WARNING: 警告信息
- INFO: 一般信息
- DEBUG: 调试信息

## 参考项目
1. [systemd服务管理](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
2. [journalctl日志管理](https://www.freedesktop.org/software/systemd/man/journalctl.html)
