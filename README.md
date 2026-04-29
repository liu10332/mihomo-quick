# mihomo-quick

轻量级 mihomo (Clash.Meta) 快速部署工具。

## 安装

```bash
git clone https://github.com/liu10332/mihomo-quick.git
cd mihomo-quick
./install.sh
```

安装脚本会自动：
- 下载 mihomo 二进制
- 安装 MetaCubeXD Web 面板
- 创建 systemd 服务
- 安装管理脚本到 `~/.local/bin/`

## 快速开始

```bash
# 1. 加载代理环境
source ~/.bashrc

# 2. 启动服务
sudo systemctl start mihomo

# 3. 添加订阅
mihomo-add-sub

# 4. 测试代理
proxy-test
```

## 命令速查

| 命令 | 说明 |
|------|------|
| `proxy-start` | 启动 mihomo |
| `proxy-stop` | 停止 mihomo |
| `proxy-restart` | 重启 mihomo |
| `proxy-status` | 查看运行状态 |
| `proxy-test` | 综合代理测试 |
| `mihomo-add-sub` | 交互式添加订阅（支持主/备/手动优先级） |
| `mihomo-rules` | 查看/添加/删除代理规则 |
| `mihomo-check` | 校验配置文件 |
| `mihomo-rollback` | 配置备份与回滚 |
| `mihomo-logs` | 查看日志 |
| `mihomo-uninstall` | 卸载 |
| `proxy-env on/off/status` | 管理代理环境变量 |

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

## 订阅优先级

`mihomo-add-sub` 支持三种角色：
- ⭐ **主订阅** — 优先使用，自动选最快节点
- 🔄 **备用订阅** — 主订阅挂了自动切换
- 📱 **仅手动选择** — 不参与自动切换

## 规则管理

```bash
mihomo-rules              # 交互菜单
mihomo-rules list         # 查看规则
mihomo-rules add          # 添加规则
mihomo-rules rm           # 删除规则
mihomo-rules sync         # 从 OpenClaw 同步模型域名（可选）
mihomo-rules edit         # 直接编辑 config.yaml
```

## 目录结构

```
~/.config/mihomo/
├── config.yaml           # 主配置
├── providers/            # 订阅缓存
├── backups/              # 配置备份
├── dashboard/            # MetaCubeXD 面板
└── geoip.metadb          # GeoIP 数据

~/.local/bin/
├── mihomo                # mihomo 二进制
├── mihomo-start/stop/... # 管理脚本
└── set-proxy-env         # 代理环境变量
```

## 卸载

```bash
mihomo-uninstall
```
