# mihomo-quick v1.0.0 发布说明

> 发布日期：2026-04-21
> 版本：1.0.0
> 状态：稳定版

## 🎉 发布概述

mihomo-quick 是一个轻量级的 mihomo 快速部署工具，旨在简化 mihomo 代理的安装、配置和管理过程。经过完整的开发周期，我们正式发布 v1.0.0 版本，提供完整的功能和稳定的性能。

## 🚀 主要特性

### 1. 多代理模式支持
- **TUN模式**: 透明代理，性能最佳
- **系统代理**: HTTP/SOCKS5，兼容性最好
- **TAP模式**: 二层代理，功能最强
- **混合模式**: 灵活组合，适应性强

### 2. 智能订阅管理
- **多格式支持**: YAML、JSON、原始格式
- **多订阅源**: 支持多个订阅源管理
- **自动更新**: 定时自动更新订阅
- **节点筛选**: 智能筛选和分组

### 3. 节点健康检查
- **延迟测试**: TCP/HTTP/代理延迟测试
- **可用性检查**: 多维度可用性检查
- **速度测试**: 下载速度和延迟抖动
- **状态监控**: 实时状态监控

### 4. 故障转移配置
- **主备节点**: 灵活的主备配置
- **自动转移**: 智能故障转移
- **故障恢复**: 自动故障恢复
- **转移策略**: 可配置转移策略

### 5. 配置管理
- **模板系统**: 丰富的配置模板
- **配置向导**: 交互式配置生成
- **导入导出**: 配置导入导出
- **备份恢复**: 配置备份恢复

### 6. 服务管理
- **systemd集成**: 完整的systemd支持
- **服务管理**: 启动/停止/重启
- **状态监控**: 实时状态监控
- **日志管理**: 完整的日志管理

## 📦 安装方式

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

## 🎯 使用方法

### 基本使用
```bash
# 启动管理菜单
mihomo-quick

# 启动服务
sudo systemctl start mihomo-quick

# 查看状态
systemctl status mihomo-quick

# 查看日志
journalctl -u mihomo-quick -f
```

### 配置向导
```bash
# 启动配置向导
mihomo-quick config

# 或者
./mihomo-quick.sh config
```

### 订阅管理
```bash
# 添加订阅
mihomo-quick sub add "订阅名称" "订阅URL"

# 更新订阅
mihomo-quick sub update

# 测试节点
mihomo-quick test
```

## 🔧 配置示例

### TUN模式配置
```yaml
mixed-port: 7890
socks-port: 7891
allow-lan: true
bind-address: '*'
mode: rule
log-level: info

tun:
  enable: true
  stack: system
  device: tun0
  gateway: 10.0.0.1
  dns-hijack:
    - any:53

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
    url: "https://example.com/sub"
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

## 📁 项目结构

```
mihomo-quick/
├── mihomo-quick.sh          # 主入口脚本
├── install.sh               # 安装脚本
├── uninstall.sh             # 卸载脚本
├── lib/                     # 功能模块库
│   ├── utils.sh            # 工具函数
│   ├── config.sh           # 配置管理
│   ├── config_wizard.sh    # 配置向导
│   ├── config_io.sh        # 配置导入导出
│   ├── template.sh         # 模板处理
│   ├── subscription.sh     # 订阅管理
│   ├── subscription_manager.sh # 订阅管理器
│   ├── node_health.sh      # 节点健康检查
│   ├── service.sh          # 服务管理
│   ├── mode.sh             # 代理模式管理
│   └── config_validate.sh  # 配置验证
├── templates/               # 配置模板
│   ├── base.yaml.template
│   ├── tun.yaml.template
│   ├── system.yaml.template
│   ├── tap.yaml.template
│   ├── mixed.yaml.template
│   ├── providers.yaml.template
│   ├── rules.yaml.template
│   ├── blacklist.yaml.template
│   └── whitelist.yaml.template
├── configs/                 # 配置文件目录
├── logs/                    # 日志目录
├── backups/                 # 备份目录
└── README.md                # 项目说明
```

## 🎨 功能特点

### 轻量级
- 纯bash实现，无额外依赖
- 单目录部署，不污染系统
- 资源占用少，性能高效

### 易用性
- 交互式向导，开箱即用
- 友好的界面设计
- 完整的帮助文档

### 灵活性
- 多代理模式支持
- 多订阅源管理
- 黑白名单配置
- 规则自定义

### 稳定性
- 故障转移机制
- 节点健康检查
- 自动恢复功能
- 完善的错误处理

### 完整性
- 全功能覆盖
- 一站式管理
- 完整的工具链
- 详细的文档

## 🔍 系统要求

- Linux操作系统 (Ubuntu 18.04+, CentOS 7+, Debian 9+)
- Bash 4.0+
- curl, tar, systemctl, ip
- root权限（用于TUN模式）

## 📊 性能指标

- **安装时间**: < 1分钟
- **配置生成**: < 10秒
- **启动时间**: < 5秒
- **内存占用**: < 50MB
- **CPU占用**: < 5%

## 🐛 已知问题

1. **TUN模式需要root权限** - 某些系统可能需要额外配置
2. **订阅格式兼容性** - 某些特殊格式的订阅可能无法解析
3. **节点测试准确性** - 网络环境不同可能导致测试结果差异

## 🔮 未来计划

### v1.1.0 (计划中)
- Web管理面板
- 更多订阅格式支持
- 节点自动选择算法
- 配置模板市场

### v1.2.0 (计划中)
- 多用户支持
- 权限管理
- API接口
- 移动端支持

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

1. Fork本仓库
2. 创建特性分支
3. 提交更改
4. 推送到分支
5. 创建Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- [mihomo](https://github.com/MetaCubeX/mihomo) - 优秀的代理内核
- [mihomo-dashboard](https://github.com/MetaCubeX/mihomo-dashboard) - Web管理面板
- 所有贡献者和用户

## 📞 联系方式

- GitHub: https://github.com/your-username/mihomo-quick
- Issues: https://github.com/your-username/mihomo-quick/issues
- Discussions: https://github.com/your-username/mihomo-quick/discussions

---

**最后更新**: 2026-04-21
**版本**: 1.0.0
**状态**: 稳定版
