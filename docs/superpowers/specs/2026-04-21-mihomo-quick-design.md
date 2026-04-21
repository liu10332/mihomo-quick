# mihomo-quick 设计文档

> 创建日期：2026-04-21
> 状态：已批准
> 版本：1.0.0

## 1. 概述

### 1.1 项目目标
mihomo-quick 是一个轻量级的 mihomo 快速部署工具，旨在简化 mihomo 代理的安装、配置和管理过程。支持多代理模式、智能订阅管理、交互式配置生成等功能。

### 1.2 核心价值
- **轻量级**：单目录、少依赖、快速部署
- **易用性**：交互式向导、开箱即用
- **灵活性**：多模式支持、多订阅源、黑白名单
- **稳定性**：故障转移、健康检查、自动恢复

### 1.3 目标用户
- 个人用户：快速部署自己的代理配置
- 技术爱好者：分享配置和订阅
- 小团队：统一代理管理

## 2. 背景

### 2.1 问题陈述
现有的 mihomo 部署存在以下问题：
1. 配置复杂：需要手动编写 YAML 配置文件
2. 订阅管理不便：多订阅源管理困难
3. 模式切换麻烦：不同代理模式需要不同配置
4. 缺乏统一工具：没有标准化的管理工具

### 2.2 现有方案分析
| 方案 | 优点 | 缺点 |
|------|------|------|
| 手动配置 | 灵活、完全控制 | 复杂、易出错 |
| 第三方客户端 | 功能完整 | 闭源、资源占用大 |
| Docker部署 | 隔离性好 | 资源开销大 |

## 3. 设计决策

### 3.1 架构决策
**决策1：单脚本+模块化库**
- **选择**：主脚本 + lib/ 模块化库
- **理由**：平衡轻量和可维护性
- **替代方案**：单文件脚本（太臃肿）、完整CLI工具（太复杂）

**决策2：bash实现**
- **选择**：纯bash脚本
- **理由**：无额外依赖、跨平台兼容
- **替代方案**：Python（需要环境）、Go（需要编译）

**决策3：模板化配置**
- **选择**：YAML模板 + 变量替换
- **理由**：灵活、易维护
- **替代方案**：硬编码配置（不灵活）、动态生成（复杂）

### 3.2 功能决策
**决策4：混合模式支持**
- **选择**：TUN/System/TAP/Mixed 四种模式
- **理由**：满足不同场景需求
- **实现**：通过配置模板切换

**决策5：智能订阅管理**
- **选择**：多源订阅 + 健康检查 + 故障转移
- **理由**：提高可用性
- **实现**：proxy-providers + proxy-groups

**决策6：交互式配置**
- **选择**：向导式配置生成
- **理由**：降低使用门槛
- **实现**：bash read + 配置模板

## 4. 架构设计

### 4.1 系统架构
```
┌─────────────────────────────────────┐
│           mihomo-quick.sh           │
│            (主入口脚本)              │
├─────────────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │
│  │config│ │subsc │ │servic│ │utils │ │
│  │  .sh │ │  .sh │ │  .sh │ │  .sh │ │
│  └──────┘ └──────┘ └──────┘ └──────┘ │
│           (功能模块库)               │
├─────────────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐         │
│  │templ │ │dashb │ │logs  │         │
│  │ates/ │ │oard/ │ │      │         │
│  └──────┘ └──────┘ └──────┘         │
│           (资源文件)                 │
└─────────────────────────────────────┘
```

### 4.2 目录结构
```
mihomo-quick/
├── mihomo-quick.sh              # 主入口脚本
├── install.sh                   # 安装脚本
├── uninstall.sh                 # 卸载脚本
├── lib/                         # 功能模块库
│   ├── config.sh               # 配置管理
│   ├── subscription.sh         # 订阅管理
│   ├── service.sh              # 服务管理
│   ├── mode.sh                 # 模式管理
│   └── utils.sh                # 工具函数
├── templates/                   # 配置模板
│   ├── base.yaml.template      # 基础配置
│   ├── tun.yaml.template       # TUN模式配置
│   ├── system.yaml.template    # 系统代理配置
│   ├── tap.yaml.template       # TAP模式配置
│   ├── providers.yaml.template # 订阅模板
│   ├── rules.yaml.template     # 规则模板
│   └── blacklist.yaml.template # 黑名单模板
├── dashboard/                   # Web面板
│   └── index.html              # 面板入口
├── configs/                     # 配置文件目录
│   ├── config.yaml             # 当前配置
│   ├── providers.yaml          # 订阅配置
│   └── rules.yaml              # 规则配置
├── backups/                     # 备份目录
├── logs/                        # 日志目录
└── README.md                    # 使用说明
```

### 4.3 核心组件

#### 4.3.1 主入口脚本 (mihomo-quick.sh)
```bash
#!/bin/bash
# 主菜单
show_menu() {
    echo "mihomo-quick 管理工具"
    echo "1. 安装/卸载"
    echo "2. 模式管理"
    echo "3. 订阅管理"
    echo "4. 配置管理"
    echo "5. 服务管理"
    echo "6. Web面板"
    echo "0. 退出"
}

# 主循环
while true; do
    show_menu
    read -p "请选择: " choice
    case $choice in
        1) source lib/install.sh ;;
        2) source lib/mode.sh ;;
        3) source lib/subscription.sh ;;
        4) source lib/config.sh ;;
        5) source lib/service.sh ;;
        6) source lib/dashboard.sh ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
done
```

#### 4.3.2 配置管理模块 (lib/config.sh)
```bash
# 交互式配置生成
config_wizard() {
    echo "配置向导"
    
    # 选择代理模式
    echo "选择代理模式:"
    echo "1. TUN模式（透明代理）"
    echo "2. 系统代理（HTTP/SOCKS5）"
    echo "3. TAP模式（二层代理）"
    echo "4. 混合模式"
    read -p "请选择 [1-4]: " mode_choice
    
    # 配置订阅
    echo "配置订阅源"
    read -p "订阅URL: " sub_url
    read -p "订阅名称: " sub_name
    
    # 配置规则
    echo "配置规则模式:"
    echo "1. 白名单模式（只有列表中的走代理）"
    echo "2. 黑名单模式（列表中的走直连）"
    read -p "请选择 [1-2]: " rule_mode
    
    # 生成配置
    generate_config $mode_choice $sub_url $sub_name $rule_mode
}
```

#### 4.3.3 订阅管理模块 (lib/subscription.sh)
```bash
# 添加订阅
subscription_add() {
    local name=$1
    local url=$2
    
    # 下载订阅
    curl -s -o "/tmp/sub_$name" "$url"
    
    # 解析订阅
    parse_subscription "/tmp/sub_$name"
    
    # 添加到配置
    add_provider_to_config "$name" "$url"
}

# 订阅健康检查
subscription_health_check() {
    local provider=$1
    
    # 测试节点
    for node in $(get_nodes_from_provider $provider); do
        test_node_latency $node
    done
    
    # 标记无效节点
    mark_unhealthy_nodes
}
```

## 5. 详细设计

### 5.1 代理模式设计

#### 5.1.1 TUN模式
```yaml
tun:
  enable: true
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true
  device: tun0
  mtu: 9000
  strict-route: true
  gateway: 10.0.0.1
```

#### 5.1.2 系统代理模式
```yaml
mixed-port: 7890
socks-port: 7891
allow-lan: true
bind-address: '*'
```

#### 5.1.3 TAP模式
```yaml
tap:
  enable: true
  device: tap0
  mtu: 1500
```

#### 5.1.4 混合模式
```yaml
mixed-port: 7890
socks-port: 7891
tun:
  enable: true
  stack: system
  device: tun0
```

### 5.2 订阅管理设计

#### 5.2.1 订阅源配置
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
    filter: ".*(美国|日本|香港).*"  # 节点筛选
    exclude: ".*测试.*"  # 排除节点
```

#### 5.2.2 节点分组
```yaml
proxy-groups:
  - name: "🇺🇸 美国节点"
    type: select
    use:
      - provider-a
    filter: ".*美国.*"
    
  - name: "🇯🇵 日本节点"
    type: select
    use:
      - provider-a
    filter: ".*日本.*"
```

#### 5.2.3 故障转移
```yaml
proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - 🎯 全球直连
      - 🇺🇸 美国节点
      - 🇯🇵 日本节点
      
  - name: "♻️ 自动选择"
    type: url-test
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    proxies:
      - 🇺🇸 美国节点
      - 🇯🇵 日本节点
```

### 5.3 黑白名单设计

#### 5.3.1 白名单模式
```yaml
rules:
  # 国外网站走代理
  - DOMAIN-SUFFIX,google.com,🚀 节点选择
  - DOMAIN-SUFFIX,youtube.com,🚀 节点选择
  - DOMAIN-SUFFIX,github.com,🚀 节点选择
  
  # 国内网站直连
  - GEOIP,CN,🎯 全球直连
  - DOMAIN-SUFFIX,baidu.com,🎯 全球直连
  - DOMAIN-SUFFIX,qq.com,🎯 全球直连
  
  # 默认规则
  - MATCH,🎯 全球直连
```

#### 5.3.2 黑名单模式
```yaml
rules:
  # 黑名单（这些走直连）
  - DOMAIN-SUFFIX,baidu.com,🎯 全球直连
  - DOMAIN-SUFFIX,qq.com,🎯 全球直连
  - DOMAIN-SUFFIX,taobao.com,🎯 全球直连
  - DOMAIN-SUFFIX,jd.com,🎯 全球直连
  - GEOIP,CN,🎯 全球直连
  
  # 其他走代理
  - MATCH,🚀 节点选择
```

### 5.4 交互式配置设计

#### 5.4.1 配置向导流程
```
1. 欢迎界面
   - 显示工具介绍
   - 检查系统环境

2. 代理模式选择
   - TUN模式（推荐）
   - 系统代理
   - TAP模式
   - 混合模式

3. 订阅配置
   - 添加订阅源
   - 设置更新间隔
   - 配置节点筛选

4. 规则配置
   - 白名单/黑名单模式
   - 自定义规则
   - 广告拦截

5. 高级配置
   - DNS设置
   - 性能优化
   - 日志配置

6. 生成配置
   - 显示配置摘要
   - 确认生成
   - 测试配置
```

#### 5.4.2 配置模板变量
```bash
# 模板变量
{HTTP_PORT}           # HTTP代理端口
{SOCKS_PORT}          # SOCKS5代理端口
{TUN_DEVICE}          # TUN设备名
{TUN_IP}              # TUN设备IP
{MODE}                # 代理模式
{SUB_URL}             # 订阅URL
{SUB_NAME}            # 订阅名称
{RULE_MODE}           # 规则模式
{BLACKLIST}           # 黑名单规则
{WHITELIST}           # 白名单规则
```

## 6. 实施计划

### 6.1 里程碑划分

#### M001: 基础架构（1-2天）
- **S01**: 项目初始化和目录结构
- **S02**: 主入口脚本和菜单系统
- **S03**: 基础工具函数库

#### M002: 配置管理（2-3天）
- **S01**: 配置模板系统
- **S02**: 交互式配置向导
- **S03**: 配置导入导出

#### M003: 订阅管理（3-4天）
- **S01**: 订阅解析和存储
- **S02**: 节点健康检查
- **S03**: 故障转移配置
- **S04**: 节点筛选和分组

#### M004: 服务管理（2-3天）
- **S01**: systemd服务集成
- **S02**: 服务启停管理
- **S03**: 日志管理

#### M005: Web面板和发布（2-3天）
- **S01**: Web面板集成
- **S02**: 安装卸载脚本
- **S03**: 文档和README
- **S04**: GitHub发布

### 6.2 详细任务分解

#### M001-S01: 项目初始化
1. 创建目录结构
2. 编写README.md
3. 初始化git仓库

#### M001-S02: 主入口脚本
1. 设计菜单系统
2. 实现参数解析
3. 添加帮助信息

#### M001-S03: 工具函数库
1. 日志函数
2. 颜色输出
3. 错误处理
4. 系统检查

### 6.3 技术栈
- **语言**：Bash 4.0+
- **依赖**：curl, jq, tar, systemctl
- **配置**：YAML模板
- **服务**：systemd
- **面板**：mihomo-dashboard

## 7. 风险和缓解措施

### 7.1 技术风险
| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| Bash兼容性问题 | 中 | 中 | 使用POSIX兼容语法，测试多平台 |
| 订阅格式变化 | 低 | 高 | 支持多种订阅格式，优雅降级 |
| 系统权限问题 | 中 | 中 | 清晰的权限提示，sudo处理 |

### 7.2 功能风险
| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 配置生成错误 | 中 | 高 | 配置验证，测试模式 |
| 订阅更新失败 | 中 | 中 | 重试机制，手动更新选项 |
| 服务启动失败 | 低 | 高 | 详细日志，故障排查指南 |

## 8. 验收标准

### 8.1 功能验收
1. ✅ 支持四种代理模式（TUN/System/TAP/Mixed）
2. ✅ 支持多订阅源管理
3. ✅ 支持节点健康检查和故障转移
4. ✅ 支持黑白名单配置
5. ✅ 支持交互式配置生成
6. ✅ 集成Web面板
7. ✅ 支持systemd服务管理

### 8.2 性能验收
1. ✅ 安装时间 < 1分钟
2. ✅ 配置生成时间 < 10秒
3. ✅ 订阅更新时间 < 30秒
4. ✅ 内存占用 < 50MB
5. ✅ CPU占用 < 5%

### 8.3 质量验收
1. ✅ 代码可读性好
2. ✅ 错误处理完善
3. ✅ 日志记录完整
4. ✅ 文档齐全

## 9. 附录

### 9.1 参考资料
- [mihomo官方文档](https://wiki.metacubex.one/)
- [Clash配置文档](https://github.com/Dreamacro/clash/wiki/Configuration)
- [mihomo-dashboard](https://github.com/MetaCubeX/mihomo-dashboard)

### 9.2 术语表
- **mihomo**: 代理内核，Clash.Meta的分支
- **TUN**: 虚拟网络接口，透明代理模式
- **订阅**: 代理节点列表的URL
- **健康检查**: 测试节点可用性
- **故障转移**: 主节点失败时切换到备用节点

### 9.3 变更记录
| 版本 | 日期 | 变更内容 |
|------|------|----------|
| 1.0.0 | 2026-04-21 | 初始设计文档 |
