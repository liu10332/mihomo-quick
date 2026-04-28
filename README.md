# mihomo-quick

轻量级 mihomo 快速部署工具，支持多代理模式、智能订阅管理、三层代理组架构、MetaCubeXD Web 面板。

## 功能特点

- 🚀 **快速部署**: 一键安装，开箱即用，自动下载 MetaCubeXD Web 面板
- 🔄 **多模式支持**: TUN/System/TAP/Mixed 四种代理模式，切换时自动保留订阅和规则
- 📡 **智能订阅**: 多源订阅、自动更新（代理可用时自动走代理）、代理链下载
- ⭐ **订阅优先级**: 设置主订阅优先使用，备用订阅故障转移，自动切换
- 📋 **黑白名单**: 灵活的规则管理，支持走代理和排除代理的域名/IP
- ⚙️ **三层代理组**: url-test 自动选择 + fallback 智能切换 + select 手动选择
- 🌐 **Web面板**: 自动安装 MetaCubeXD，访问 `http://127.0.0.1:9090/ui`
- 🛡️ **AI API直连**: 大模型 API 自动直连（anthropic、openai、volces 等），不走代理
- 🔧 **环境变量管理**: proxy-env.sh 一键管理 http_proxy、npm 代理
- 📊 **综合测试**: test-all-proxy.sh 全面测试直连、代理、外网访问
- 🔌 **npm代理**: 启动/停止服务时自动配置/清理 npm 代理

## 系统要求

- Linux 操作系统 (Ubuntu 18.04+, CentOS 7+, Debian 9+)
- Bash 4.0+
- curl, tar, systemctl
- root 权限（用于 TUN 模式）

## 快速安装

### 方式 1：一键安装
```bash
curl -fsSL https://raw.githubusercontent.com/liu10332/mihomo-quick/main/install.sh | bash
```

### 方式 2：手动安装
```bash
git clone https://github.com/liu10332/mihomo-quick.git
cd mihomo-quick
./install.sh
```

### 方式 3：带订阅安装
```bash
./install.sh -s "https://your-subscription-url" -m tun
```

安装过程自动完成：
1. 下载 mihomo 内核（支持 GitHub 镜像加速）
2. 生成配置文件（三层代理组 + 完整规则）
3. 下载安装 MetaCubeXD Web 面板
4. 创建 systemd 服务

## 使用方法

### 命令行使用

#### 服务管理
```bash
mihomo-quick start      # 启动服务（自动配置 npm 代理）
mihomo-quick stop       # 停止服务（自动清理 npm 代理）
mihomo-quick restart    # 重启服务
mihomo-quick status     # 查看状态
mihomo-quick logs       # 查看日志
```

#### 订阅管理
```bash
mihomo-quick sub list   # 查看订阅列表
mihomo-quick sub add    # 添加订阅（支持代理链下载）
mihomo-quick update     # 更新订阅（自动检测代理）
mihomo-quick test       # 测试代理连通性
```

#### 模式切换
```bash
mihomo-quick mode tun       # TUN 模式（透明代理）
mihomo-quick mode system    # 系统代理模式
mihomo-quick mode mixed     # 混合模式
mihomo-quick mode tap       # TAP 模式
```

#### 规则管理（黑白名单）
```bash
mihomo-quick rules show                          # 查看当前规则
mihomo-quick rules add-proxy DOMAIN-SUFFIX,openai.com   # 添加走代理的规则
mihomo-quick rules add-direct DOMAIN-SUFFIX,baidu.com   # 添加排除代理的规则（直连）
mihomo-quick rules add-direct IP-CIDR,10.0.0.0/8       # 添加IP段直连
mihomo-quick rules del DOMAIN-SUFFIX,openai.com         # 删除规则
mihomo-quick rules list                          # 列出所有自定义规则
mihomo-quick rules mode whitelist                # 切换到白名单模式
mihomo-quick rules mode blacklist                # 切换到黑名单模式
mihomo-quick rules import rules.txt             # 导入规则文件
mihomo-quick rules export                        # 导出规则文件
```

#### 订阅优先级（故障转移）
```bash
mihomo-quick priority show               # 查看订阅优先级
mihomo-quick priority set provider-a     # 设置主订阅（优先使用）
mihomo-quick priority backup provider-b  # 添加备用订阅
mihomo-quick priority rm-backup provider-b  # 移除备用订阅
mihomo-quick priority apply              # 应用优先级配置
mihomo-quick priority test               # 测试故障转移
```

#### 环境变量代理
```bash
mihomo-quick proxy-env on        # 启用代理环境变量
mihomo-quick proxy-env off       # 禁用代理环境变量
mihomo-quick proxy-env status    # 查看当前状态
mihomo-quick proxy-env test      # 测试代理连接
mihomo-quick proxy-env config    # 配置代理参数
mihomo-quick proxy-env npm-on    # 启用 npm 代理
mihomo-quick proxy-env npm-off   # 禁用 npm 代理
```

#### 综合代理测试
```bash
mihomo-quick test-all            # 综合测试直连、代理、外网访问
```

#### Web 面板
```bash
mihomo-quick dashboard  # 显示面板地址
# 访问 http://127.0.0.1:9090/ui
```

### 环境变量管理

```bash
# 启用代理环境变量
source scripts/proxy-env.sh on

# 禁用代理环境变量
source scripts/proxy-env.sh off

# 查看当前状态
bash scripts/proxy-env.sh status

# 测试代理连接
bash scripts/proxy-env.sh test

# npm 代理管理
bash scripts/proxy-env.sh npm-on    # 启用 npm 代理
bash scripts/proxy-env.sh npm-off   # 禁用 npm 代理
```

### 综合测试

```bash
bash scripts/test-all-proxy.sh
```

测试项目：
- mihomo 进程和端口检查
- 大模型 API 直连（Anthropic、火山引擎、智谱 AI）
- 代理基本连接（httpbin、Cloudflare）
- 外网访问（Google、GitHub、DuckDuckGo）
- 国内网站直连（百度、腾讯）
- 代理 IP 信息

## 配置说明

### 三层代理组架构

```yaml
proxy-groups:
  # 第一层：自动选择（延迟最低的节点）
  - name: "🚀 节点选择"
    type: url-test
    use:
      - provider-a
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 200

  # 第二层：智能切换（节点不可用时自动切换）
  - name: "🔄 智能切换"
    type: fallback
    proxies:
      - "🚀 节点选择"
    url: http://cp.cloudflare.com/generate_204
    interval: 300

  # 第三层：手动选择（用户手动切换节点）
  - name: "📱 手动选择"
    type: select
    use:
      - provider-a
    proxies:
      - "🔄 智能切换"
      - "🚀 节点选择"
      - DIRECT
```

### 代理规则

```yaml
rules:
  # 大模型 API 直连（不走代理，确保低延迟）
  - DOMAIN-SUFFIX,anthropic.com,DIRECT
  - DOMAIN-SUFFIX,openai.com,DIRECT
  - DOMAIN-SUFFIX,volcengine.com,DIRECT
  - DOMAIN-SUFFIX,bigmodel.cn,DIRECT

  # Google API 走代理（Gemini 等需要代理）
  - DOMAIN-SUFFIX,googleapis.com,🔄 智能切换

  # 本地网络直连
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT

  # 中国 IP 直连
  - GEOIP,CN,DIRECT

  # 默认规则
  - MATCH,🔄 智能切换
```

### 订阅优先级与故障转移

支持设置主订阅优先使用，备用订阅故障自动切换：

```bash
# 设置主订阅（优先使用）
mihomo-quick priority set provider-a

# 添加备用订阅
mihomo-quick priority backup provider-b
mihomo-quick priority backup provider-c

# 应用配置（生成故障转移代理组）
mihomo-quick priority apply
```

应用后生成的代理组架构：
- ⭐ **主订阅节点** → url-test（主订阅自动选择最快节点）
- 🔄 **故障转移** → fallback（主订阅不可用时按顺序切换备用）
- 📱 **综合选择** → select（手动选择或使用自动）

### 黑白名单规则管理

灵活管理哪些域名/IP走代理、哪些排除代理：

```bash
# 添加走代理的规则
mihomo-quick rules add-proxy DOMAIN-SUFFIX,openai.com
mihomo-quick rules add-proxy DOMAIN-KEYWORD,google

# 添加排除代理的规则（直连）
mihomo-quick rules add-direct DOMAIN-SUFFIX,baidu.com
mihomo-quick rules add-direct IP-CIDR,10.0.0.0/8

# 切换规则模式
mihomo-quick rules mode whitelist  # 白名单模式（只有列表中的走代理）
mihomo-quick rules mode blacklist  # 黑名单模式（列表中的直连，其他走代理）

# 查看和管理规则
mihomo-quick rules list            # 列出自定义规则
mihomo-quick rules show            # 查看所有规则
mihomo-quick rules del <规则>      # 删除规则
```

### 订阅配置

```yaml
proxy-providers:
  provider-a:
    type: http
    url: "your-subscription-url"
    interval: 3600
    header:
      User-Agent:
        - "clash-verge/v2.2.3"
    health-check:
      enable: true
      interval: 600
      url: http://cp.cloudflare.com/generate_204
    override:
      skip-cert-verify: true
```

## 目录结构

```
mihomo-quick/
├── mihomo-quick.sh          # 主入口脚本
├── install.sh               # 安装脚本（含 MetaCubeXD 安装）
├── uninstall.sh             # 卸载脚本
├── lib/                     # 功能模块库
│   ├── config.sh           # 配置管理
│   ├── config_wizard.sh    # 配置向导（三层代理组 + 完整规则）
│   ├── subscription.sh     # 订阅管理（支持代理链）
│   ├── subscription_config.sh  # 订阅配置生成
│   ├── subscription_manager.sh # 订阅解析与存储
│   ├── subscription_priority.sh # 订阅优先级与故障转移
│   ├── service.sh          # 服务管理（npm 代理自动管理）
│   ├── mode.sh             # 模式切换
│   ├── rules.sh            # 规则管理（黑白名单）
│   ├── node_health.sh      # 节点健康检查
│   ├── template.sh         # 模板处理
│   └── utils.sh            # 工具函数
├── scripts/                 # 辅助脚本
│   ├── proxy-env.sh        # 环境变量管理
│   └── test-all-proxy.sh   # 综合代理测试
├── templates/               # 配置模板
│   ├── base.yaml.template
│   ├── rules.yaml.template # 完整规则模板
│   └── ...
└── README.md
```

## 安装目录

```
~/.mihomo-quick/             # 安装目录
├── mihomo                   # mihomo 内核二进制
├── mihomo-quick.sh          # CLI 入口
├── lib/                     # 功能模块
└── scripts/                 # 辅助脚本

~/.config/mihomo/            # 配置目录
├── config.yaml              # 主配置文件
├── dashboard/               # MetaCubeXD Web 面板
└── providers/               # 订阅节点缓存

/etc/systemd/system/
└── mihomo-quick.service     # systemd 服务文件

~/.local/bin/
└── mihomo-quick -> ~/.mihomo-quick/mihomo-quick.sh
```

## 特性说明

### 三层代理组架构
- **url-test**: 自动测试节点延迟，选择最快的节点
- **fallback**: 节点不可用时自动切换到备用节点
- **select**: 手动选择特定节点或使用自动选择

### AI API 直连
大模型 API 自动直连，不走代理，确保低延迟：
- Anthropic (claude)
- OpenAI (gpt)
- 火山引擎 (volces)
- 智谱 AI (bigmodel)
- OpenRouter

### MetaCubeXD Web 面板
- 安装时自动下载最新版 MetaCubeXD
- 访问地址：`http://127.0.0.1:9090/ui`
- 支持节点管理、规则管理、连接监控

### npm 代理自动管理
- 启动服务时自动配置 npm 代理
- 停止服务时自动清理 npm 代理
- 解决 npm 不认 HTTP_PROXY 环境变量的问题

### 代理链订阅下载
- 支持通过已有代理下载新订阅
- 适用于订阅站被墙的情况
- 自动检测可用代理组

## 故障排查

### 服务无法启动
```bash
mihomo-quick status    # 查看服务状态
mihomo-quick logs      # 查看日志
```

### 配置验证
```bash
~/.mihomo-quick/mihomo -d ~/.config/mihomo -t   # 测试配置文件
```

### 综合测试
```bash
bash scripts/test-all-proxy.sh   # 全面测试代理功能
```

### 环境变量检查
```bash
bash scripts/proxy-env.sh status  # 查看代理环境变量
```

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证

## 致谢

- [mihomo](https://github.com/MetaCubeX/mihomo) - 代理内核
- [MetaCubeXD](https://github.com/MetaCubeX/metacubexd) - Web 管理面板

---

**最后更新**: 2026-04-29
**版本**: 1.2.0
