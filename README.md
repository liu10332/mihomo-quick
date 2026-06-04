# mihomo-quick

轻量级 mihomo (Clash.Meta) 快速部署工具。

## 特性

- ✅ **离线安装**：预打包 GeoIP/GeoSite 数据库，无需网络即可完成安装
- ✅ **智能分流**：内置 `GEOSITE,cn,DIRECT` 规则，精准识别国内流量
- ✅ **自动更新**：每次启动 mihomo 时自动检查并更新 GeoIP/GeoSite（7 天一次）
- ✅ **一键部署**：自动下载 mihomo、安装面板、配置服务

## 安装

```bash
git clone https://github.com/liu10332/mihomo-quick.git
cd mihomo-quick
./install.sh
```

安装脚本会自动：
- 下载 mihomo 二进制（已安装时对比版本，支持增量更新）
- 安装 MetaCubeXD Web 面板（已安装时可选择更新）
- **复制 GeoIP/GeoSite 数据库**（离线可用）
- 创建 systemd 服务
- 安装管理脚本到 `~/.local/bin/`
- 配置代理环境变量

## 快速开始

```bash
# 1. 加载代理环境
source ~/.bashrc

# 2. 打开管理菜单
mihomo

# 3. 在菜单中选择「安装/更新服务」设置开机自启

# 4. 在菜单中选择「添加订阅」
```

## 管理菜单

安装完成后直接运行 `mihomo` 打开交互式管理菜单：

```
╔══════════════════════════════════════════════════════════════╗
║                  mihomo-quick 管理菜单                      ║
╚══════════════════════════════════════════════════════════════╝

  服务管理
   1) 🚀 启动服务 (普通模式)
   2) 🚀 启动服务 (TUN 模式)
   3) 🛑 停止服务
   4) 🔄 重启服务
   5) 📊 查看状态

  配置管理
   6) 📦 添加订阅
   7) 📜 管理规则
   8) ✅ 校验配置
   9) ⏪ 配置回滚
  10) 📝 编辑配置

  维护
  11) 📋 查看日志
  12) 🔄 检查更新 (内核/面板/GeoIP)
  13) 🔧 安装/更新服务 (开机自启)
  14) 🧪 代理测试

  其他
  15) 🗑️  卸载
   0) 退出
```

## 命令速查

除管理菜单外，所有功能也可通过独立命令使用：

| 命令 | 说明 |
|------|------|
| `mihomo` | 打开管理菜单（推荐） |
| `mihomo-update` | 检查更新内核/面板/GeoIP/GeoSite |
| `mihomo-update geosite` | 单独更新 GeoSite 数据库 |
| `mihomo-auto-update` | 手动触发 GeoIP/GeoSite 更新 |
| `mihomo-auto-update --force` | 强制更新（忽略 7 天时间限制） |
| `mihomo-add-sub` | 交互式添加订阅（支持主/备/手动优先级） |
| `mihomo-rules` | 查看/添加/删除代理规则 |
| `mihomo-check` | 校验配置文件 |
| `mihomo-rollback` | 配置备份与回滚 |
| `mihomo-logs` | 查看日志 |
| `mihomo-uninstall` | 卸载 |
| `proxy-start` | 启动 mihomo |
| `proxy-stop` | 停止 mihomo |
| `proxy-restart` | 重启 mihomo |
| `proxy-status` | 查看运行状态 |
| `proxy-test` | 综合代理测试 |
| `proxy-env on/off/status` | 管理代理环境变量 |

## 服务管理

```bash
./setup-service.sh            # 普通模式 (HTTP/SOCKS5)
./setup-service.sh tun        # TUN 模式（透明代理）
```

或在管理菜单中选择「安装/更新服务」。

## 配置文件

所有配置集中在 `~/.config/mihomo/config.yaml`，可直接编辑：

```yaml
# 订阅
proxy-providers:
  我的订阅:
    type: http
    url: "https://..."
    interval: 3600
    path: ./providers/我的订阅.yaml

# 代理组
proxy-groups:
- name: ⭐ 主订阅
  type: url-test
  use: [我的订阅]

# 规则
rules:
- DOMAIN-SUFFIX,google.com,🔄 故障转移
- GEOIP,CN,DIRECT
- MATCH,🔄 故障转移
```

修改后运行 `mihomo-check` 校验，再 `proxy-restart` 生效。

## 目录结构

```
~/.config/mihomo/
├── config.yaml           # 主配置
├── providers/            # 订阅缓存
├── backups/              # 配置备份
├── dashboard/            # MetaCubeXD 面板
├── geoip.metadb          # GeoIP 数据（自动更新）
├── geosite.dat           # GeoSite 数据（自动更新）
└── cache.db              # DNS 缓存

~/.local/bin/
├── mihomo                # 管理菜单入口
├── mihomo-core           # mihomo 二进制
├── mihomo-start/stop/... # 管理脚本
├── mihomo-auto-update    # GeoIP/GeoSite 自动更新脚本
└── set-proxy-env         # 代理环境变量

~/.cache/mihomo/
├── auto-update.log       # 自动更新日志
└── last-update.stamp     # 上次更新时间戳
```

## 卸载

```bash
mihomo-uninstall
```

## 自动更新机制

mihomo-quick 内置 GeoIP/GeoSite 数据库自动更新功能：

- **触发时机**：每次启动或重启 mihomo 服务时
- **更新频率**：7 天检查一次（避免频繁下载）
- **更新内容**：`geoip.metadb`（IP 地理位置）和 `geosite.dat`（域名分类）

### 工作原理

```
mihomo 启动
    ↓
ExecStartPre: mihomo-auto-update
    ↓
检查距上次更新是否超过 7 天
    ↓
├─ 不足 7 天 → 跳过，直接启动
└─ 超过 7 天 → 下载更新 → 启动
```

### 手动更新

```bash
# 完整更新（交互式）
mihomo-auto-update

# 强制更新（忽略 7 天限制）
mihomo-auto-update --force

# 查看更新日志
cat ~/.cache/mihomo/auto-update.log

# 查看上次更新时间
date -d @$(cat ~/.cache/mihomo/last-update.stamp)
```

### 离线安装

项目预打包了 GeoIP/GeoSite 数据库，即使没有网络也能完成安装：

- `config/geoip.metadb`（约 9MB）
- `config/geosite.dat`（约 4MB）

安装时会自动复制到 `~/.config/mihomo/` 目录。

## 更新日志

### v1.1.0 (2026-06-05)

- ✨ 新增 `GEOSITE,cn,DIRECT` 规则，精准分流国内流量
- ✨ 预打包 GeoIP/GeoSite 数据库，支持离线安装
- ✨ 启动时自动检查更新 GeoIP/GeoSite（7 天一次）
- ✨ `mihomo-update` 支持单独更新 geosite
- 🔧 优化默认配置，完善 DNS 设置

### v1.0.0

- 初始版本
- 支持 mihomo 内核安装与更新
- 支持 MetaCubeXD 面板安装
- 支持订阅管理
- 支持规则管理
- 支持 systemd 服务管理
```
