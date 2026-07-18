# 订阅管理和代理组逻辑修复计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复订阅管理功能、节点过滤、故障转移逻辑，实现完整的订阅生命周期管理

**Architecture:** 重写 mihomo-add-sub 脚本，添加节点过滤库，修复代理组生成逻辑

**Tech Stack:** Bash, Python3 (YAML处理)

## Global Constraints

- 保持与现有 lib/ 库的兼容性
- 不删除临时失效的真实节点，只过滤明确无效的条目
- 故障转移逻辑：每个订阅创建独立的 url-test 组
- 支持订阅的完整生命周期：添加/更新/删除/刷新

---

## 文件结构

```
mihomo-quick/
├── lib/
│   ├── common.sh           # (已有)
│   ├── detect.sh           # (已有)
│   ├── network.sh          # (已有)
│   ├── service.sh          # (已有)
│   └── filter.sh           # 新增：节点过滤库
├── scripts/
│   ├── mihomo-sub          # 重写：订阅管理主脚本
│   └── ... (其他脚本不变)
└── templates/
    └── config.yaml         # (已有)
```

---

### Task 1: 创建节点过滤库 lib/filter.sh

**Files:**
- Create: `lib/filter.sh`

**Interfaces:**
- Produces: `filter_invalid_nodes()`, `get_node_type()`, `should_filter_node()`

- [ ] **Step 1: 创建 lib/filter.sh**

```bash
#!/bin/bash
# lib/filter.sh - 节点过滤库
# 过滤明确无效的非代理条目，不删除临时失效的真实节点

# 加载依赖
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/common.sh"

# ===== 过滤规则 =====

# 无效节点的正则模式（不区分大小写）
INVALID_NODE_PATTERNS=(
    # 官网信息
    '官网'
    'www\..+\.com'
    'Website'
    'Official'
    
    # 流量/套餐信息
    '剩余流量'
    '套餐到期'
    '距离下次重置'
    '流量'
    'Expire'
    'Traffic'
    'Bandwidth'
    'Data'
    
    # TG群组/频道
    'TG群'
    'Telegram'
    '电报'
    't\.me'
    'Channel'
    'Group'
    
    # 订阅相关
    '订阅'
    'Subscribe'
    '续费'
    'Renew'
    
    # 其他非代理信息
    '群组'
    '频道'
    '更新地址'
    '官网地址'
)

# ===== 核心函数 =====

# 检查节点名称是否应该被过滤
# 参数: $1 - 节点名称
# 返回: 0=应该过滤, 1=保留
should_filter_node() {
    local name="$1"
    
    for pattern in "${INVALID_NODE_PATTERNS[@]}"; do
        if echo "$name" | grep -qiE "$pattern"; then
            return 0
        fi
    done
    
    return 1
}

# 获取节点类型（用于日志）
# 参数: $1 - 节点名称
get_node_type() {
    local name="$1"
    
    if echo "$name" | grep -qiE '官网|www\.|Website|Official'; then
        echo "官网信息"
    elif echo "$name" | grep -qiE '剩余流量|套餐到期|距离下次重置|Expire|Traffic'; then
        echo "套餐信息"
    elif echo "$name" | grep -qiE 'TG群|Telegram|电报|t\.me|Channel|Group'; then
        echo "群组/频道"
    elif echo "$name" | grep -qiE '订阅|Subscribe|续费|Renew'; then
        echo "订阅信息"
    else
        echo "未知"
    fi
}

# 过滤 provider 文件中的无效节点
# 参数: $1 - provider YAML 文件路径
# 返回: 过滤掉的节点数量
filter_invalid_nodes() {
    local provider_file="$1"
    
    if [[ ! -f "$provider_file" ]]; then
        log_error "Provider 文件不存在: $provider_file"
        return 1
    fi
    
    python3 << PYEOF || { log_error "Python 处理失败"; return 1; }
import re
import yaml
import sys

INVALID_PATTERNS = [
    r'官网', r'www\..+\.com', r'Website', r'Official',
    r'剩余流量', r'套餐到期', r'距离下次重置', r'流量', r'Expire', r'Traffic', r'Bandwidth', r'Data',
    r'TG群', r'Telegram', r'电报', r't\.me', r'Channel', r'Group',
    r'订阅', r'Subscribe', r'续费', r'Renew',
    r'群组', r'频道', r'更新地址', r'官网地址',
]

def should_filter(name):
    for pattern in INVALID_PATTERNS:
        if re.search(pattern, name, re.IGNORECASE):
            return True
    return False

provider_file = "$provider_file"

try:
    with open(provider_file) as f:
        data = yaml.safe_load(f)
    
    if not data or 'proxies' not in data:
        print("0")
        sys.exit(0)
    
    original_count = len(data['proxies'])
    filtered = []
    skipped = []
    
    for node in data['proxies']:
        name = node.get('name', '')
        if should_filter(name):
            skipped.append(name)
        else:
            filtered.append(node)
    
    data['proxies'] = filtered
    
    with open(provider_file, 'w') as f:
        yaml.dump(data, f, allow_unicode=True, sort_keys=False)
    
    removed_count = original_count - len(filtered)
    
    if removed_count > 0:
        print(f"已过滤 {removed_count} 个无效节点:")
        for name in skipped:
            print(f"  - {name}")
    else:
        print("没有需要过滤的节点")
        
except Exception as e:
    print(f"错误: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# 获取 provider 中的节点统计
# 参数: $1 - provider YAML 文件路径
get_node_stats() {
    local provider_file="$1"
    
    if [[ ! -f "$provider_file" ]]; then
        echo "文件不存在"
        return 1
    fi
    
    python3 << PYEOF
import yaml

try:
    with open("$provider_file") as f:
        data = yaml.safe_load(f)
    
    if not data or 'proxies' not in data:
        print("无节点")
        return
    
    nodes = data['proxies']
    total = len(nodes)
    
    # 按类型统计
    types = {}
    for node in nodes:
        node_type = node.get('type', 'unknown')
        types[node_type] = types.get(node_type, 0) + 1
    
    print(f"总节点数: {total}")
    print("节点类型:")
    for t, count in sorted(types.items()):
        print(f"  - {t}: {count}")
        
except Exception as e:
    print(f"错误: {e}")
PYEOF
}
```

- [ ] **Step 2: 验证语法**

```bash
bash -n lib/filter.sh
echo "Exit code: $?"
```

- [ ] **Step 3: 测试过滤功能**

```bash
source lib/filter.sh

# 测试 should_filter_node
echo "测试过滤规则:"
should_filter_node "剩余流量：77.2 GB" && echo "✓ 过滤: 剩余流量"
should_filter_node "官网: www.example.com" && echo "✓ 过滤: 官网"
should_filter_node "TG群组" && echo "✓ 过滤: TG群组"
should_filter_node "香港1|BGP优化" && echo "过滤" || echo "✓ 保留: 香港1|BGP优化"
should_filter_node "日本-HY2-50" && echo "过滤" || echo "✓ 保留: 日本-HY2-50"
```

- [ ] **Step 4: 提交**

```bash
git add lib/filter.sh
git commit -m "feat: add node filtering library"
```

---

### Task 2: 重写订阅管理脚本 mihomo-sub

**Files:**
- Create: `scripts/mihomo-sub` (新主入口)
- Modify: `scripts/mihomo-add-sub` (保留兼容性)

**Interfaces:**
- Consumes: lib/common.sh, lib/filter.sh, lib/service.sh
- Produces: mihomo-sub 命令 (add/update/remove/list/refresh)

- [ ] **Step 1: 创建 scripts/mihomo-sub**

```bash
#!/bin/bash
# mihomo-sub - 订阅管理主脚本
# 用法: mihomo-sub [add|update|remove|list|refresh|health] [参数]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/detect.sh"
source "$SCRIPT_DIR/../lib/service.sh"
source "$SCRIPT_DIR/../lib/filter.sh"

CONFIG_DIR="${HOME}/.config/mihomo"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

# ===== 订阅操作函数 =====

# 列出所有订阅
cmd_list() {
    log_title "订阅列表"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    python3 << 'PYEOF'
import yaml

with open("'"$CONFIG_FILE"'") as f:
    cfg = yaml.safe_load(f) or {}

providers = cfg.get('proxy-providers', {})

if not providers:
    print("  暂无订阅")
else:
    print(f"  共 {len(providers)} 个订阅:\n")
    for name, prov in providers.items():
        url = prov.get('url', 'N/A')
        interval = prov.get('interval', 3600)
        health = prov.get('health-check', {}).get('enable', False)
        
        print(f"  📡 {name}")
        print(f"     URL: {url[:60]}...")
        print(f"     更新间隔: {interval}秒")
        print(f"     健康检查: {'✓' if health else '✗'}")
        print()
PYEOF
}

# 添加订阅
cmd_add() {
    log_title "添加订阅"
    
    # 显示现有订阅
    cmd_list
    
    # 获取订阅信息
    read -p "订阅名称: " sub_name
    [[ -z "$sub_name" ]] && { log_error "名称不能为空"; return 1; }
    
    # 检查是否已存在
    if python3 -c "
import yaml
with open('$CONFIG_FILE') as f:
    cfg = yaml.safe_load(f) or {}
exit(0 if '$sub_name' in cfg.get('proxy-providers', {}) else 1)
" 2>/dev/null; then
        log_error "订阅 [$sub_name] 已存在"
        echo "  使用 mihomo-sub update 更新，或 mihomo-sub remove 删除后重新添加"
        return 1
    fi
    
    read -p "订阅URL: " sub_url
    [[ -z "$sub_url" ]] && { log_error "URL 不能为空"; return 1; }
    
    read -p "更新间隔(秒) [3600]: " sub_interval
    sub_interval=${sub_interval:-3600}
    
    # 订阅角色
    echo ""
    echo -e "${WHITE}订阅角色:${NC}"
    echo "  1. ⭐ 主订阅（自动选最快节点）"
    echo "  2. 🔄 备用订阅（主挂了自动切换）"
    echo "  3. 📱 仅手动选择"
    read -p "请选择 [1-3]: " role_choice
    case $role_choice in
        1) role="primary" ;;
        2) role="backup" ;;
        3) role="manual" ;;
        *) role="primary" ;;
    esac
    
    # 代理链选择
    proxy_chain=$(select_proxy_chain)
    
    # 执行添加
    add_provider "$sub_name" "$sub_url" "$sub_interval" "$role" "$proxy_chain"
    
    # 过滤无效节点
    filter_provider_nodes "$sub_name"
    
    # 询问是否重启
    if confirm "是否重启生效？" "y"; then
        restart_service
    fi
}

# 更新订阅
cmd_update() {
    log_title "更新订阅"
    
    # 选择要更新的订阅
    local name=$(select_provider "更新")
    [[ -z "$name" ]] && return 1
    
    # 获取当前信息
    local current_url=$(python3 -c "
import yaml
with open('$CONFIG_FILE') as f:
    cfg = yaml.safe_load(f) or {}
print(cfg.get('proxy-providers', {}).get('$name', {}).get('url', ''))
" 2>/dev/null)
    
    echo ""
    echo -e "${WHITE}当前订阅 [$name]:${NC}"
    echo "  URL: $current_url"
    echo ""
    
    # 获取新信息
    read -p "新 URL (回车保持不变): " new_url
    [[ -z "$new_url" ]] && new_url="$current_url"
    
    read -p "新更新间隔(秒) (回车保持不变): " new_interval
    
    # 执行更新
    update_provider "$name" "$new_url" "$new_interval"
    
    # 过滤无效节点
    filter_provider_nodes "$name"
    
    if confirm "是否重启生效？" "y"; then
        restart_service
    fi
}

# 删除订阅
cmd_remove() {
    log_title "删除订阅"
    
    # 选择要删除的订阅
    local name=$(select_provider "删除")
    [[ -z "$name" ]] && return 1
    
    # 确认删除
    echo ""
    echo -e "${RED}警告: 将删除订阅 [$name] 及其相关配置${NC}"
    if ! confirm "确认删除？" "N"; then
        return 0
    fi
    
    # 执行删除
    remove_provider "$name"
    
    if confirm "是否重启生效？" "y"; then
        restart_service
    fi
}

# 刷新所有订阅
cmd_refresh() {
    log_title "刷新订阅"
    
    # 获取所有订阅名称
    local providers=$(python3 -c "
import yaml
with open('$CONFIG_FILE') as f:
    cfg = yaml.safe_load(f) or {}
for name in cfg.get('proxy-providers', {}):
    print(name)
" 2>/dev/null)
    
    if [[ -z "$providers" ]]; then
        log_warn "没有订阅需要刷新"
        return 0
    fi
    
    echo "$providers" | while read name; do
        [[ -z "$name" ]] && continue
        
        echo "  刷新: $name"
        filter_provider_nodes "$name"
    done
    
    echo ""
    log_info "刷新完成"
    
    if confirm "是否重启生效？" "y"; then
        restart_service
    fi
}

# ===== 辅助函数 =====

# 选择订阅
select_provider() {
    local action=$1
    
    local providers=$(python3 -c "
import yaml
with open('$CONFIG_FILE') as f:
    cfg = yaml.safe_load(f) or {}
for name in cfg.get('proxy-providers', {}):
    print(name)
" 2>/dev/null)
    
    if [[ -z "$providers" ]]; then
        log_warn "没有可操作的订阅"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}可${action}的订阅:${NC}"
    local arr=($providers)
    for i in "${!arr[@]}"; do
        echo "  $((i+1)). ${arr[$i]}"
    done
    
    echo ""
    read -p "选择 [1-${#arr[@]}]: " idx
    
    if [[ "$idx" =~ ^[0-9]+$ ]] && [[ $idx -ge 1 ]] && [[ $idx -le ${#arr[@]} ]]; then
        echo "${arr[$((idx-1))]}"
    else
        log_error "无效选择"
        return 1
    fi
}

# 选择代理链
select_proxy_chain() {
    echo ""
    echo -e "${WHITE}此订阅是否需要通过代理下载？${NC}"
    echo "  1. 直接下载（默认）"
    echo "  2. 通过已有代理组下载"
    read -p "请选择 [1]: " proxy_choice
    
    if [[ "$proxy_choice" != "2" ]]; then
        echo ""
        return
    fi
    
    # 自动检测可用代理组
    local groups=$(get_available_groups)
    
    if [[ -z "$groups" ]]; then
        log_warn "没有可用的代理组，将使用直连"
        echo ""
        return
    fi
    
    echo ""
    echo -e "${WHITE}可用代理组:${NC}"
    local arr=($groups)
    for i in "${!arr[@]}"; do
        echo "  $((i+1)). ${arr[$i]}"
    done
    
    echo ""
    read -p "选择代理组 [1-${#arr[@]}]: " idx
    
    if [[ "$idx" =~ ^[0-9]+$ ]] && [[ $idx -ge 1 ]] && [[ $idx -le ${#arr[@]} ]]; then
        echo "${arr[$((idx-1))]}"
    fi
}

# 获取可用代理组（排除手动选择组）
get_available_groups() {
    python3 << 'PYEOF'
import yaml

with open("'"$CONFIG_FILE"'") as f:
    cfg = yaml.safe_load(f) or {}

groups = cfg.get('proxy-groups', [])
for g in groups:
    name = g.get('name', '')
    gtype = g.get('type', '')
    # 只返回 url-test 和 fallback 类型，排除手动选择
    if gtype in ('url-test', 'fallback', 'load-balance'):
        if '手动' not in name and '手动' not in name:
            print(name)
PYEOF
}

# 添加订阅到配置
add_provider() {
    local name=$1
    local url=$2
    local interval=$3
    local role=$4
    local proxy_chain=$5
    
    backup_file "$CONFIG_FILE" "$CONFIG_DIR/backups" > /dev/null
    
    python3 << PYEOF || { log_error "Python 处理失败"; return 1; }
import yaml
import sys

config_file = "$CONFIG_FILE"
name = "$name"
url = "$url"
interval = int("$interval")
role = "$role"
proxy_chain = "$proxy_chain" or None

with open(config_file) as f:
    cfg = yaml.safe_load(f) or {}

# 确保必要字段存在
if 'proxy-providers' not in cfg or cfg['proxy-providers'] is None:
    cfg['proxy-providers'] = {}
if 'proxy-groups' not in cfg or cfg['proxy-groups'] is None:
    cfg['proxy-groups'] = []

# 添加 provider
provider = {
    'type': 'http',
    'url': url,
    'interval': interval,
    'path': f'./providers/{name}.yaml',
    'health-check': {
        'enable': True,
        'interval': 600,
        'url': 'http://cp.cloudflare.com/generate_204'
    },
    'override': {
        'skip-cert-verify': True
    }
}
if proxy_chain:
    provider['proxy'] = proxy_chain

cfg['proxy-providers'][name] = provider

# 根据角色设置代理组
if role == 'primary':
    # 主订阅：创建 url-test 组
    group_name = f'📡 {name}'
    
    # 检查是否已存在
    group_exists = any(g['name'] == group_name for g in cfg['proxy-groups'])
    
    if not group_exists:
        # 插入到开头
        cfg['proxy-groups'].insert(0, {
            'name': group_name,
            'type': 'url-test',
            'use': [name],
            'url': 'http://cp.cloudflare.com/generate_204',
            'interval': 300,
            'tolerance': 200,
            'lazy': True
        })
    
    # 确保故障转移组存在并包含此组
    ensure_fallback_group(cfg, group_name)
    
    # 确保手动选择组存在
    ensure_select_group(cfg, name, group_name)

elif role == 'backup':
    # 备用订阅：创建独立的 url-test 组
    group_name = f'📡 {name}'
    
    # 检查是否已存在
    group_exists = any(g['name'] == group_name for g in cfg['proxy-groups'])
    
    if not group_exists:
        # 查找主订阅组的位置，在其后插入
        primary_idx = 0
        for i, g in enumerate(cfg['proxy-groups']):
            if '主订阅' in g.get('name', '') or '⭐' in g.get('name', ''):
                primary_idx = i + 1
                break
        
        cfg['proxy-groups'].insert(primary_idx, {
            'name': group_name,
            'type': 'url-test',
            'use': [name],
            'url': 'http://cp.cloudflare.com/generate_204',
            'interval': 300,
            'tolerance': 200,
            'lazy': True
        })
    
    # 添加到故障转移组
    ensure_fallback_group(cfg, group_name)
    
    # 添加到手动选择组
    ensure_select_group(cfg, name, group_name)

elif role == 'manual':
    # 仅手动选择
    ensure_select_group(cfg, name, None)

# 写入配置
with open(config_file, 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

print(f"✅ 订阅 [{name}] 已添加")
PYEOF
}

# 确保故障转移组存在并包含指定组
ensure_fallback_group() {
    local cfg=$1
    local group_name=$2
    
    python3 << PYEOF
import yaml

config_file = "$CONFIG_FILE"
group_name = "$group_name"

with open(config_file) as f:
    cfg = yaml.safe_load(f) or {}

fallback_name = '🔄 故障转移'

# 查找故障转移组
fallback_group = None
for g in cfg.get('proxy-groups', []):
    if g['name'] == fallback_name:
        fallback_group = g
        break

if fallback_group:
    # 确保包含指定组
    if group_name not in fallback_group.get('proxies', []):
        fallback_group.setdefault('proxies', []).append(group_name)
else:
    # 创建故障转移组
    # 找到主订阅组
    primary_name = None
    for g in cfg.get('proxy-groups', []):
        if '⭐' in g.get('name', '') or '主订阅' in g.get('name', ''):
            primary_name = g['name']
            break
    
    proxies = []
    if primary_name:
        proxies.append(primary_name)
    proxies.append(group_name)
    proxies.append('DIRECT')
    
    # 插入到主订阅之后
    idx = 0
    for i, g in enumerate(cfg['proxy-groups']):
        if '⭐' in g.get('name', '') or '主订阅' in g.get('name', ''):
            idx = i + 1
            break
    
    cfg['proxy-groups'].insert(idx, {
        'name': fallback_name,
        'type': 'fallback',
        'proxies': proxies,
        'url': 'http://cp.cloudflare.com/generate_204',
        'interval': 300,
        'lazy': True
    })

with open(config_file, 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
PYEOF
}

# 确保手动选择组存在
ensure_select_group() {
    local cfg=$1
    local name=$2
    local group_name=$3
    
    python3 << PYEOF
import yaml

config_file = "$CONFIG_FILE"
name = "$name"
group_name = "$group_name"

with open(config_file) as f:
    cfg = yaml.safe_load(f) or {}

select_name = '📱 手动选择'

# 查找手动选择组
select_group = None
for g in cfg.get('proxy-groups', []):
    if g['name'] == select_name:
        select_group = g
        break

if select_group:
    # 添加到 use 列表
    if name not in select_group.get('use', []):
        select_group.setdefault('use', []).append(name)
    # 如果有 group_name，也添加到 proxies
    if group_name and group_name not in select_group.get('proxies', []):
        select_group.setdefault('proxies', []).insert(0, group_name)
else:
    # 创建手动选择组
    proxies = []
    if group_name:
        proxies.append(group_name)
    proxies.append('DIRECT')
    
    cfg['proxy-groups'].append({
        'name': select_name,
        'type': 'select',
        'use': [name],
        'proxies': proxies
    })

with open(config_file, 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
PYEOF
}

# 更新订阅
update_provider() {
    local name=$1
    local new_url=$2
    local new_interval=$3
    
    backup_file "$CONFIG_FILE" "$CONFIG_DIR/backups" > /dev/null
    
    python3 << PYEOF || { log_error "Python 处理失败"; return 1; }
import yaml

config_file = "$CONFIG_FILE"
name = "$name"
new_url = "$new_url"
new_interval = "$new_interval"

with open(config_file) as f:
    cfg = yaml.safe_load(f) or {}

if name not in cfg.get('proxy-providers', {}):
    print(f"❌ 订阅 [{name}] 不存在")
    exit(1)

provider = cfg['proxy-providers'][name]

if new_url:
    provider['url'] = new_url
    print(f"  URL 已更新")

if new_interval and new_interval.isdigit():
    provider['interval'] = int(new_interval)
    print(f"  更新间隔已设置为 {new_interval}秒")

with open(config_file, 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

print(f"✅ 订阅 [{name}] 已更新")
PYEOF
}

# 删除订阅
remove_provider() {
    local name=$1
    
    backup_file "$CONFIG_FILE" "$CONFIG_DIR/backups" > /dev/null
    
    python3 << PYEOF || { log_error "Python 处理失败"; return 1; }
import yaml

config_file = "$CONFIG_FILE"
name = "$name"

with open(config_file) as f:
    cfg = yaml.safe_load(f) or {}

if name not in cfg.get('proxy-providers', {}):
    print(f"❌ 订阅 [{name}] 不存在")
    exit(1)

# 删除 provider
del cfg['proxy-providers'][name]

# 删除相关代理组（从 use 列表中移除）
for g in cfg.get('proxy-groups', []):
    if 'use' in g and name in g['use']:
        g['use'].remove(name)

# 清理空的代理组
cfg['proxy-groups'] = [
    g for g in cfg.get('proxy-groups', [])
    if g.get('use') or g.get('proxies')
]

with open(config_file, 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

print(f"✅ 订阅 [{name}] 已删除")
PYEOF
    
    # 删除缓存文件
    rm -f "$CONFIG_DIR/providers/${name}.yaml"
}

# 过滤 provider 中的无效节点
filter_provider_nodes() {
    local name=$1
    local provider_file="$CONFIG_DIR/providers/${name}.yaml"
    
    if [[ ! -f "$provider_file" ]]; then
        echo "  缓存文件不存在，跳过过滤"
        return 0
    fi
    
    echo "  过滤无效节点..."
    filter_invalid_nodes "$provider_file"
}

# ===== 主菜单 =====

show_menu() {
    log_title "mihomo-sub 订阅管理"
    
    echo -e "  ${WHITE}订阅操作${NC}"
    echo "    1) 📡 添加订阅"
    echo "    2) 🔄 更新订阅"
    echo "    3) 🗑️  删除订阅"
    echo "    4) 📋 列出订阅"
    echo ""
    echo -e "  ${WHITE}维护操作${NC}"
    echo "    5) 🔃 刷新所有订阅"
    echo "    6) 🩺 过滤无效节点"
    echo ""
    echo -e "  ${WHITE}其他${NC}"
    echo "    0) 退出"
    echo ""
}

# ===== 主流程 =====

# 支持命令行参数
case "${1:-}" in
    list|ls)
        cmd_list
        ;;
    add)
        cmd_add
        ;;
    update|up)
        cmd_update
        ;;
    remove|rm|delete)
        cmd_remove
        ;;
    refresh)
        cmd_refresh
        ;;
    filter)
        log_title "过滤所有订阅的无效节点"
        cmd_list
        echo ""
        filter_provider_nodes_all
        ;;
    *)
        # 交互式菜单
        while true; do
            show_menu
            read -p "请选择 [0-6]: " choice
            echo ""
            
            case $choice in
                1) cmd_add ;;
                2) cmd_update ;;
                3) cmd_remove ;;
                4) cmd_list ;;
                5) cmd_refresh ;;
                6) 
                    log_title "过滤所有订阅的无效节点"
                    filter_provider_nodes_all
                    ;;
                0|q|Q)
                    echo -e "${GREEN}👋 再见${NC}"
                    exit 0
                    ;;
                *)
                    log_error "无效选择"
                    ;;
            esac
            
            echo ""
            read -p "按 Enter 返回菜单..." _
        done
        ;;
esac
```

- [ ] **Step 2: 创建符号链接保持兼容**

```bash
# 创建 mihomo-add-sub 符号链接到 mihomo-sub add
ln -sf mihomo-sub scripts/mihomo-add-sub
chmod +x scripts/mihomo-sub
```

- [ ] **Step 3: 验证语法**

```bash
bash -n scripts/mihomo-sub
echo "Exit code: $?"
```

- [ ] **Step 4: 提交**

```bash
git add scripts/mihomo-sub scripts/mihomo-add-sub
git commit -m "feat: rewrite subscription management with full lifecycle"
```

---

### Task 3: 更新 install.sh 集成新脚本

**Files:**
- Modify: `install.sh`

**Interfaces:**
- Consumes: scripts/mihomo-sub
- Produces: 更新后的安装脚本

- [ ] **Step 1: 更新 install.sh 中的脚本列表**

```bash
# 在 install_scripts() 函数中添加 mihomo-sub
local scripts=(
    scripts/mihomo-sub         mihomo-sub      # 新增
    scripts/mihomo-menu        mihomo
    scripts/mihomo-start       mihomo-start
    scripts/mihomo-stop        mihomo-stop
    # ... 其他脚本
)
```

- [ ] **Step 2: 保留旧脚本的兼容性**

```bash
# 在 install_scripts() 函数末尾添加兼容性链接
ln -sf mihomo-sub "$DEFAULT_INSTALL_DIR/mihomo-add-sub"
```

- [ ] **Step 3: 验证语法**

```bash
bash -n install.sh
echo "Exit code: $?"
```

- [ ] **Step 4: 提交**

```bash
git add install.sh
git commit -m "feat: integrate new subscription management"
```

---

### Task 4: 更新模板配置的默认代理组

**Files:**
- Modify: `templates/config.yaml`

**Interfaces:**
- Produces: 更合理的默认代理组结构

- [ ] **Step 1: 更新 templates/config.yaml**

```yaml
# 默认代理组模板（由 mihomo-sub 动态生成）
proxy-groups: []
# 实际结构示例:
# - name: 📡 主订阅
#   type: url-test
#   use: [primary-sub]
#   
# - name: 🔄 故障转移
#   type: fallback
#   proxies:
#     - 📡 主订阅
#     - DIRECT
#   
# - name: 📱 手动选择
#   type: select
#   proxies:
#     - 🔄 故障转移
#     - 📡 主订阅
#     - DIRECT
```

- [ ] **Step 2: 提交**

```bash
git add templates/config.yaml
git commit -m "docs: update default proxy groups template"
```

---

### Task 5: 更新 README 和帮助信息

**Files:**
- Modify: `README.md`

**Interfaces:**
- Produces: 更新后的文档

- [ ] **Step 1: 更新 README.md 添加订阅管理文档**

```markdown
## 订阅管理

使用 `mihomo-sub` 命令管理订阅：

\```bash
# 添加订阅
mihomo-sub add

# 更新订阅
mihomo-sub update

# 删除订阅
mihomo-sub remove

# 列出所有订阅
mihomo-sub list

# 刷新所有订阅（过滤无效节点）
mihomo-sub refresh

# 过滤无效节点
mihomo-sub filter
\```

### 订阅角色

- **主订阅** ⭐ - 自动选择最快节点，故障时切换到备用
- **备用订阅** 🔄 - 主订阅故障时自动切换
- **手动选择** 📱 - 仅在手动选择时使用

### 节点过滤

系统会自动过滤以下类型的无效节点：
- 官网信息
- 剩余流量/套餐到期
- Telegram 群组/频道
- 其他非代理条目

**注意**：临时失效的真实节点不会被删除，系统会持续监控并在恢复后自动使用。
\```

- [ ] **Step 2: 提交**

```bash
git add README.md
git commit -m "docs: add subscription management documentation"
```

---

## 执行顺序

1. Task 1: 创建节点过滤库 (lib/filter.sh)
2. Task 2: 重写订阅管理脚本 (scripts/mihomo-sub)
3. Task 3: 更新 install.sh
4. Task 4: 更新模板配置
5. Task 5: 更新文档

## 验证方法

```bash
# 1. 语法检查
bash -n lib/filter.sh
bash -n scripts/mihomo-sub

# 2. 功能测试
source lib/filter.sh
should_filter_node "剩余流量：77.2 GB"  # 应返回 0
should_filter_node "香港1|BGP优化"      # 应返回 1

# 3. 集成测试
./scripts/mihomo-sub list
```
