# mihomo-quick

轻量级 mihomo (Clash.Meta) 快速部署工具。

## 安装

```bash
git clone https://github.com/liu10332/mihomo-quick.git
cd mihomo-quick
./install.sh
```

安装脚本会自动：
- 下载 mihomo 二进制（已安装时对比版本，支持增量更新）
- 安装 MetaCubeXD Web 面板（已安装时可选择更新）
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
| `mihomo-update` | 检查更新内核/面板/GeoIP |
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
└── geoip.metadb          # GeoIP 数据

~/.local/bin/
├── mihomo                # 管理菜单入口
├── mihomo-core           # mihomo 二进制
├── mihomo-start/stop/... # 管理脚本
└── set-proxy-env         # 代理环境变量
```

## 卸载

```bash
mihomo-uninstall
```
