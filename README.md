# mihomo-quick

轻量级 mihomo (Clash.Meta) 通用 Linux 快速部署工具。

## 特性

- ✅ **通用支持**: 适配 Ubuntu/Debian, CentOS/RHEL, Arch Linux
- ✅ **自动检测**: TUN 设备、可用端口、系统架构、发行版
- ✅ **智能分流**: 内置 `GEOSITE,cn,DIRECT` 规则，精准识别国内流量
- ✅ **订阅管理**: 支持添加/更新/删除/刷新订阅，自动过滤无效节点
- ✅ **故障转移**: 多订阅自动切换，主订阅故障时自动切换到备用
- ✅ **安全默认**: API 绑定 localhost，自动生成随机密钥
- ✅ **离线安装**: 预打包 GeoIP/GeoSite 数据库
- ✅ **一键部署**: 自动下载 mihomo、安装面板、配置服务

## 系统要求

- Linux (Ubuntu 18+, CentOS 7+, Arch Linux)
- x86_64 / aarch64 / armv7 架构
- 依赖: curl, python3 + PyYAML, tar, gzip

## 安装

```bash
git clone https://github.com/liu10332/mihomo-quick.git
cd mihomo-quick
./install.sh
```

安装脚本会自动：
- 下载 mihomo 二进制
- 安装 MetaCubeXD Web 面板
- 复制 GeoIP/GeoSite 数据库
- 创建 systemd 服务（支持开机自启）
- 安装管理脚本到 `~/.local/bin/`

## 快速开始

```bash
# 1. 打开管理菜单
mihomo

# 2. 在菜单中选择「添加订阅」
# 3. 在菜单中选择「安装/更新服务」设置开机自启
```

## 管理菜单

```bash
mihomo
```

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

## 订阅管理

使用 `mihomo-sub` 命令管理订阅：

```bash
mihomo-sub              # 交互式菜单
mihomo-sub add          # 添加订阅
mihomo-sub update       # 更新订阅
mihomo-sub remove       # 删除订阅
mihomo-sub list         # 列出订阅
mihomo-sub refresh      # 刷新所有订阅
mihomo-sub filter       # 过滤无效节点
```

### 订阅角色

- **主订阅** ⭐ - 自动选择最快节点，故障时切换到备用
- **备用订阅** 🔄 - 主订阅故障时自动切换
- **手动选择** 📱 - 仅在手动选择时使用

### 节点过滤

系统会自动过滤以下类型的无效节点：
- 官网信息（官网、Website）
- 流量信息（剩余流量、套餐到期）
- 群组信息（TG群、Telegram、频道）

**注意**：临时失效的真实节点不会被删除，系统会持续监控并在恢复后自动使用。

### 故障转移

每个订阅会创建独立的 url-test 组，故障转移组会按顺序尝试：

```
📡 主订阅 (url-test) → 📡 备用订阅 (url-test) → DIRECT
```

## 命令速查

| 命令 | 说明 |
|------|------|
| `mihomo` | 打开管理菜单（推荐） |
| `mihomo-sub` | 订阅管理 |
| `mihomo-update` | 检查更新内核/面板/GeoIP/GeoSite |
| `mihomo-rules` | 查看/添加/删除代理规则 |
| `mihomo-check` | 校验配置文件 |
| `mihomo-rollback` | 配置备份与回滚 |
| `mihomo-logs` | 查看日志 |
| `mihomo-uninstall` | 卸载 |
| `test-all-proxy` | 综合代理测试 |

## 服务管理

```bash
./setup-service.sh            # 普通模式 (HTTP/SOCKS5)
./setup-service.sh tun        # TUN 模式（透明代理）
```

或在管理菜单中选择「安装/更新服务」。

### systemd 服务

```bash
sudo systemctl start mihomo      # 启动
sudo systemctl stop mihomo       # 停止
sudo systemctl restart mihomo    # 重启
sudo systemctl status mihomo     # 状态
sudo systemctl enable mihomo     # 开机自启
```

## 配置文件

配置文件位于 `~/.config/mihomo/config.yaml`：

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
- name: 📡 我的订阅
  type: url-test
  use: [我的订阅]

# 规则
rules:
- GEOSITE,cn,DIRECT
- GEOIP,CN,DIRECT
- MATCH,🔄 故障转移
```

修改后运行 `mihomo-check` 校验，再重启服务生效。

## 目录结构

```
~/.config/mihomo/
├── config.yaml           # 主配置
├── providers/            # 订阅缓存
├── backups/              # 配置备份
├── dashboard/            # MetaCubeXD 面板
├── geoip.metadb          # GeoIP 数据
└── geosite.dat           # GeoSite 数据

~/.local/bin/
├── mihomo                # 管理菜单
├── mihomo-sub            # 订阅管理
├── mihomo-core           # mihomo 二进制
└── ...

~/.mihomo-quick/lib/      # 函数库
├── common.sh             # 公共函数
├── detect.sh             # 系统检测
├── network.sh            # 网络工具
├── service.sh            # 服务管理
└── filter.sh             # 节点过滤
```

## 自动检测

安装脚本会自动检测：

- **架构**: x86_64, aarch64, armv7
- **发行版**: Ubuntu, Debian, CentOS, RHEL, Arch
- **TUN 设备**: 自动检测可用设备名
- **端口**: 自动检测可用端口避免冲突
- **防火墙**: 自动配置 ufw/firewalld/iptables

## 安全特性

- **API 绑定**: 默认仅绑定 127.0.0.1
- **随机密钥**: 自动生成随机 API 密钥
- **非 root 支持**: 支持以普通用户运行服务

## Web 面板

访问地址：`http://127.0.0.1:9090/ui?token=<密钥>`

密钥可在配置文件中查看：
```bash
grep "secret:" ~/.config/mihomo/config.yaml
```

## 卸载

```bash
mihomo-uninstall
```

## 更新日志

### v2.0.0 (2026-07-18)

- ✨ **通用化重构**: 支持任意 Linux 发行版
- ✨ **订阅管理**: 支持添加/更新/删除/刷新订阅
- ✨ **节点过滤**: 自动过滤官网、流量、群组等无效节点
- ✨ **故障转移修复**: 正确的多订阅故障转移链
- ✨ **代理链选择**: 自动检测可用代理组
- 🔧 **Python heredoc 修复**: 使用环境变量避免特殊字符问题
- 🔧 **Unicode 支持**: 修复代理组名称中的 emoji 显示问题
- 🔧 **路径变量化**: 支持自定义安装目录
- 🔧 **错误处理**: 网络失败时不再中断安装

### v1.1.0 (2026-06-05)

- ✨ 新增 `GEOSITE,cn,DIRECT` 规则
- ✨ 预打包 GeoIP/GeoSite 数据库
- ✨ 启动时自动检查更新 GeoIP/GeoSite
- 🔧 优化默认配置

### v1.0.0

- 初始版本
- 支持 mihomo 内核安装与更新
- 支持 MetaCubeXD 面板安装
- 支持 systemd 服务管理
```
