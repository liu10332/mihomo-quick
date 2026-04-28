# mihomo-quick v1.1.0 发布说明

> 发布日期：2026-04-29
> 版本：1.1.0
> 状态：稳定版

## 🚀 新特性 (v1.1.0)

本版本参照 mihomo-proxy-export 项目的生产配置，对代理组架构、代理规则、订阅管理、Web 面板等方面进行了全面升级。

### 三层代理组架构
- **新增 fallback 智能切换组**：节点不可用时自动切换到备用节点
- **新增 select 手动选择组**：用户可手动切换特定节点
- **优化 url-test 自动选择组**：tolerance 调整为 200ms，更精准选择最快节点
- 三层架构：url-test（自动）→ fallback（智能）→ select（手动）

### AI API 直连规则
- 新增大模型 API 直连规则（不走代理，确保低延迟）：
  - Anthropic (claude)
  - OpenAI (gpt)
  - 火山引擎 (volces)
  - 智谱 AI (bigmodel)
  - OpenRouter
  - dataeyes.ai
  - xiaomimimo.com
- 新增 `googleapis.com` 走代理规则（Gemini API 需要代理访问）
- 新增完整本地网络直连规则（IP-CIDR）
- 新增 GEOIP CN 直连规则

### MetaCubeXD Web 面板
- **安装脚本自动下载 MetaCubeXD**：安装时自动获取最新版本
- 支持 GitHub 镜像加速（ghfast.top / gh-proxy.com）
- 面板地址：`http://127.0.0.1:9090/ui`
- 配置生成自动添加 `external-ui` 字段

### 环境变量管理脚本
- **新增 `scripts/proxy-env.sh`**：一键管理代理环境变量
  - `on/start`：启用代理环境变量
  - `off/stop`：禁用代理环境变量
  - `status`：查看当前状态
  - `test`：测试代理连接
  - `npm-on/npm-off`：管理 npm 代理
- 排除域名：大模型 API + 国内网站 + 本地网络

### 综合代理测试脚本
- **新增 `scripts/test-all-proxy.sh`**：全面测试代理功能
  - 环境检查：mihomo 进程、端口监听、环境变量
  - 直连测试：Anthropic、火山引擎、智谱 AI
  - 代理测试：httpbin、Cloudflare
  - 外网测试：Google、GitHub、DuckDuckGo
  - 国内测试：百度、腾讯
  - 代理 IP 信息获取

### npm 代理自动管理
- 启动服务时自动配置 npm 代理（`npm config set proxy`）
- 停止服务时自动清理 npm 代理（`npm config delete proxy`）
- 解决 npm 不认 HTTP_PROXY 环境变量的问题

### 订阅管理增强
- **订阅自动加入代理组**：添加新订阅时自动插入到所有代理组的 `use` 列表
- **代理链下载**：支持通过已有代理组下载新订阅（适用于订阅站被墙）
- **订阅配置完善**：自动添加 `override.skip-cert-verify` 和 `User-Agent`
- 防止重复添加同名订阅
- 添加订阅时显示节点数量

### 规则模板升级
- 更新 `templates/rules.yaml.template`：完整的 AI API 直连 + 国内网站 + 本地网络规则
- 更新 `lib/template.sh`：`add_subscription_to_config` 和 `add_rules_to_config` 同步升级
- 更新 `lib/config_wizard.sh`：配置向导生成完整三层代理组和规则

---

## 🐛 Bug 修复 (v1.0.1)

本版本修复了 v1.0.0 中的多项严重缺陷，涵盖安装流程、服务管理、模式切换、订阅管理等核心功能。

### 安装流程
- **修复 `install.sh` 配置生成时变量缺失**：`CONFIGS_DIR`、`API_PORT`、`TUN_*` 等变量未传递给配置向导
- **修复 mihomo 下载无镜像 fallback**：GitHub 直连被墙时自动使用 ghfast.top / gh-proxy.com 镜像
- **修复安装前无备份**：重复安装时自动备份已有配置

### 服务管理
- **修复 systemd 服务名不一致**：统一为 `mihomo-quick.service`
- **修复服务文件硬编码 TUN**：根据代理模式自动生成服务配置
- **修复代理端口硬编码**：systemd 服务中的代理端口改用变量

### 模式切换
- **修复模式切换丢失配置**：保留原有的 proxy-providers、proxy-groups 和 rules
- **修复模式切换不更新服务文件**：切换后自动重建 systemd 服务

### 订阅管理
- **修复 proxy-groups 引用 provider 方式**：从 `proxies:` 改为 `use:` 字段
- **修复 `update` 命令不走代理**：自动检测代理可用性，可用时通过代理拉取订阅

---

## v1.0.0 原始发布说明

> 发布日期：2026-04-21

### 🚀 主要特性

#### 1. 多代理模式支持
- **TUN模式**: 透明代理，性能最佳
- **系统代理**: HTTP/SOCKS5，兼容性最好
- **TAP模式**: 二层代理，功能最强
- **混合模式**: 灵活组合，适应性强

#### 2. 智能订阅管理
- **多格式支持**: YAML、JSON、原始格式
- **多订阅源**: 支持多个订阅源管理
- **自动更新**: 定时自动更新订阅
- **代理感知更新**: 代理可用时自动走代理更新订阅

#### 3. 节点健康检查
- **延迟测试**: TCP/HTTP/代理延迟测试
- **可用性检查**: 多维度可用性检查

#### 4. 配置管理
- **模板系统**: 丰富的配置模板
- **配置向导**: 交互式配置生成
- **备份恢复**: 配置自动备份恢复

#### 5. 服务管理
- **systemd 集成**: 完整的 systemd 支持
- **自适应配置**: 根据代理模式自动调整服务文件
- **日志管理**: 完整的日志管理

## 📦 安装方式

```bash
# 一键安装
curl -fsSL https://raw.githubusercontent.com/liu10332/mihomo-quick/main/install.sh | bash

# 手动安装
git clone https://github.com/liu10332/mihomo-quick.git
cd mihomo-quick
./install.sh

# 带订阅安装
./install.sh -s "https://your-subscription-url" -m tun
```

## 🎯 使用方法

```bash
# 服务管理
mihomo-quick start|stop|restart|status|logs

# 配置向导
mihomo-quick config

# 订阅管理
mihomo-quick sub list|add
mihomo-quick update    # 更新订阅（自动走代理）
mihomo-quick test      # 测试代理连通性

# 模式切换
mihomo-quick mode tun|system|tap|mixed

# Web 面板
mihomo-quick dashboard

# 环境变量管理
source scripts/proxy-env.sh on|off

# 综合测试
bash scripts/test-all-proxy.sh
```

## 📁 项目结构

```
mihomo-quick/
├── mihomo-quick.sh          # 主入口脚本
├── install.sh               # 安装脚本（含 MetaCubeXD）
├── uninstall.sh             # 卸载脚本
├── lib/                     # 功能模块库
│   ├── config_wizard.sh    # 配置向导（三层代理组）
│   ├── subscription.sh     # 订阅管理（代理链）
│   ├── service.sh          # 服务管理（npm 代理）
│   ├── template.sh         # 模板处理
│   └── ...
├── scripts/                 # 辅助脚本
│   ├── proxy-env.sh        # 环境变量管理
│   └── test-all-proxy.sh   # 综合测试
├── templates/               # 配置模板
└── README.md
```

## 🔍 系统要求

- Linux 操作系统 (Ubuntu 18.04+, CentOS 7+, Debian 9+)
- Bash 4.0+
- curl, tar, systemctl
- root 权限（用于 TUN 模式）

## 📄 许可证

本项目采用 MIT 许可证

## 🙏 致谢

- [mihomo](https://github.com/MetaCubeX/mihomo) - 代理内核
- [MetaCubeXD](https://github.com/MetaCubeX/metacubexd) - Web 管理面板

---

**最后更新**: 2026-04-29
**版本**: 1.1.0
