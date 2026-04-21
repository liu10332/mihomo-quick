# mihomo-quick

轻量级mihomo快速部署工具，支持多代理模式、智能订阅管理、交互式配置生成。

## 功能特点

- 🚀 **快速部署**: 一键安装，开箱即用
- 🔄 **多模式支持**: TUN/System/TAP/Mixed 四种代理模式
- 📡 **智能订阅**: 多源订阅、自动更新、故障转移
- ⚙️ **交互配置**: 向导式配置生成，黑白名单管理
- 🌐 **Web面板**: 集成mihomo-dashboard，Web界面管理
- 🛡️ **稳定可靠**: 健康检查、故障转移、自动恢复

## 系统要求

- Linux操作系统 (Ubuntu 18.04+, CentOS 7+, Debian 9+)
- Bash 4.0+
- curl, jq, tar, systemctl
- root权限（用于TUN模式）

## 快速安装

### 方式1：一键安装
```bash
curl -fsSL https://raw.githubusercontent.com/your-username/mihomo-quick/main/install.sh | bash
```

### 方式2：手动安装
```bash
git clone https://github.com/your-username/mihomo-quick.git
cd mihomo-quick
./install.sh
```

### 方式3：自定义安装
```bash
./install.sh -d /opt/mihomo-quick -m tun -p 8080
```

## 使用方法

### 启动管理菜单
```bash
mihomo-quick
```

### 命令行使用
```bash
# 服务管理
mihomo-quick start    # 启动服务
mihomo-quick stop     # 停止服务
mihomo-quick restart  # 重启服务
mihomo-quick status   # 查看状态

# 配置管理
mihomo-quick config   # 配置向导
mihomo-quick export   # 导出配置
mihomo-quick import   # 导入配置

# 订阅管理
mihomo-quick sub      # 订阅管理
mihomo-quick update   # 更新订阅
mihomo-quick test     # 测试节点

# 模式管理
mihomo-quick mode     # 切换代理模式
mihomo-quick tun      # 切换到TUN模式
mihomo-quick system   # 切换到系统代理模式

# Web面板
mihomo-quick dashboard # 打开Web面板
```

## 配置说明

### 基本配置
```yaml
# 代理端口
mixed-port: 7890
socks-port: 7891

# TUN模式配置
tun:
  enable: true
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  device: tun0
  mtu: 9000

# DNS配置
dns:
  enable: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
```

### 订阅配置
```yaml
proxy-providers:
  provider-a:
    type: http
    url: "your-subscription-url"
    interval: 3600
    health-check:
      enable: true
      interval: 300
      url: http://cp.cloudflare.com/generate_204
```

### 规则配置
```yaml
rules:
  # 白名单模式
  - DOMAIN-SUFFIX,google.com,🚀 节点选择
  - DOMAIN-SUFFIX,youtube.com,🚀 节点选择
  - GEOIP,CN,🎯 全球直连
  - MATCH,🎯 全球直连

  # 黑名单模式
  - DOMAIN-SUFFIX,baidu.com,🎯 全球直连
  - DOMAIN-SUFFIX,qq.com,🎯 全球直连
  - MATCH,🚀 节点选择
```

## 目录结构

```
mihomo-quick/
├── mihomo-quick.sh          # 主入口脚本
├── install.sh               # 安装脚本
├── uninstall.sh             # 卸载脚本
├── lib/                     # 功能模块库
│   ├── config.sh           # 配置管理
│   ├── subscription.sh     # 订阅管理
│   ├── service.sh          # 服务管理
│   └── utils.sh            # 工具函数
├── templates/               # 配置模板
│   ├── base.yaml.template
│   ├── tun.yaml.template
│   └── providers.yaml.template
├── configs/                 # 配置文件
├── dashboard/               # Web面板
├── logs/                    # 日志文件
├── backups/                 # 备份文件
└── README.md                # 使用说明
```

## 高级功能

### 节点健康检查
```bash
# 测试所有节点
mihomo-quick test

# 测试指定节点
mihomo-quick test --node "美国节点"

# 自动排除无效节点
mihomo-quick test --auto-disable
```

### 故障转移配置
```yaml
proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - 🎯 全球直连
      - provider-a  # 优先使用
      - provider-b  # 故障时切换

  - name: "♻️ 自动选择"
    type: url-test
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    proxies:
      - provider-a
      - provider-b
```

### 黑白名单管理
```bash
# 添加白名单
mihomo-quick whitelist add google.com

# 添加黑名单
mihomo-quick blacklist add baidu.com

# 查看列表
mihomo-quick list

# 导入导出
mihomo-quick export-list
mihomo-quick import-list
```

## 故障排查

### 服务无法启动
```bash
# 查看日志
mihomo-quick logs

# 检查配置
mihomo-quick check

# 测试配置
mihomo-quick test-config
```

### 订阅更新失败
```bash
# 手动更新
mihomo-quick update --force

# 测试订阅
mihomo-quick test-sub

# 查看订阅状态
mihomo-quick sub-status
```

### 节点连接失败
```bash
# 测试节点
mihomo-quick test --node "节点名称"

# 排除节点
mihomo-quick disable --node "节点名称"

# 重新启用
mihomo-quick enable --node "节点名称"
```

## 贡献指南

欢迎提交Issue和Pull Request！

1. Fork本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 致谢

- [mihomo](https://github.com/MetaCubeX/mihomo) - 优秀的代理内核
- [mihomo-dashboard](https://github.com/MetaCubeX/mihomo-dashboard) - Web管理面板
- 所有贡献者和用户

## 联系方式

- GitHub: https://github.com/your-username/mihomo-quick
- Issues: https://github.com/your-username/mihomo-quick/issues

---

**最后更新**: 2026-04-21
**版本**: 1.0.0
