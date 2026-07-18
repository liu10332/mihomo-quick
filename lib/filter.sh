#!/bin/bash
# filter.sh - 节点过滤库
# 从订阅提供商的 YAML 文件中过滤无效非代理条目
# 注意：不会移除暂时失败的真实节点，只过滤明显无效的条目

# 防止重复加载
[[ -n "${_FILTER_SH_LOADED:-}" ]] && return 0
_FILTER_SH_LOADED=1

# 引入公共函数
_FILTER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_FILTER_LIB_DIR}/common.sh"

# ===== 无效节点模式 =====
# 官网信息
INVALID_NODE_PATTERNS=(
    # 官网
    "官网"
    "www\..*\.com"
    "Website"
    "Official"
    # 流量信息
    "剩余流量"
    "套餐到期"
    "距离下次重置"
    "流量"
    "Expire"
    "Traffic"
    # Telegram 群组
    "TG群"
    "Telegram"
    "电报"
    "t\.me"
    "Channel"
    "Group"
    # 订阅信息
    "订阅"
    "Subscribe"
    "续费"
    "Renew"
    # 其他
    "群组"
    "频道"
    "更新地址"
    "官网地址"
)

# ===== should_filter_node() =====
# 输入：节点名称（字符串）
# 返回：0 表示应该过滤，1 表示应该保留
should_filter_node() {
    local node_name="$1"

    if [[ -z "$node_name" ]]; then
        return 1
    fi

    for pattern in "${INVALID_NODE_PATTERNS[@]}"; do
        if echo "$node_name" | grep -qE "$pattern" 2>/dev/null; then
            return 0
        fi
    done

    return 1
}

# ===== get_node_type() =====
# 输入：节点名称
# 返回：人类可读的类型描述
get_node_type() {
    local node_name="$1"

    if [[ -z "$node_name" ]]; then
        echo "未知"
        return
    fi

    # 官网信息
    if echo "$node_name" | grep -qE "官网|www\..*\.com|Website|Official" 2>/dev/null; then
        echo "官网信息"
        return
    fi

    # 流量/套餐信息
    if echo "$node_name" | grep -qE "剩余流量|套餐到期|距离下次重置|流量|Expire|Traffic" 2>/dev/null; then
        echo "套餐信息"
        return
    fi

    # 群组/频道
    if echo "$node_name" | grep -qE "TG群|Telegram|电报|t\.me|Channel|Group|群组|频道" 2>/dev/null; then
        echo "群组/频道"
        return
    fi

    # 订阅信息
    if echo "$node_name" | grep -qE "订阅|Subscribe|续费|Renew" 2>/dev/null; then
        echo "订阅信息"
        return
    fi

    # 更新地址
    if echo "$node_name" | grep -qE "更新地址|官网地址" 2>/dev/null; then
        echo "更新地址"
        return
    fi

    echo "未知"
}

# ===== filter_invalid_nodes() =====
# 输入：提供商 YAML 文件路径
# 功能：读取 YAML，过滤节点，写回文件
# 输出：打印被过滤的节点名称
filter_invalid_nodes() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        log_error "文件不存在: $yaml_file"
        return 1
    fi

    # 使用 Python3 处理 YAML
    python3 - "$yaml_file" << 'PYTHON_SCRIPT'
import sys
import yaml
from pathlib import Path

def should_filter(node_name):
    """判断节点是否应该被过滤"""
    patterns = [
        r'官网', r'www\..*\.com', r'Website', r'Official',
        r'剩余流量', r'套餐到期', r'距离下次重置', r'流量', r'Expire', r'Traffic',
        r'TG群', r'Telegram', r'电报', r't\.me', r'Channel', r'Group',
        r'订阅', r'Subscribe', r'续费', r'Renew',
        r'群组', r'频道', r'更新地址', r'官网地址'
    ]
    
    import re
    for pattern in patterns:
        if re.search(pattern, node_name, re.IGNORECASE):
            return True
    return False

def main():
    if len(sys.argv) < 2:
        print("用法: python3 filter_nodes.py <yaml_file>", file=sys.stderr)
        sys.exit(1)
    
    yaml_file = sys.argv[1]
    
    try:
        with open(yaml_file, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
    except Exception as e:
        print(f"读取文件失败: {e}", file=sys.stderr)
        sys.exit(1)
    
    if not data or 'proxies' not in data:
        print("未找到 proxies 字段", file=sys.stderr)
        sys.exit(1)
    
    original_count = len(data['proxies'])
    filtered_nodes = []
    
    # 过滤无效节点
    valid_proxies = []
    for proxy in data['proxies']:
        name = proxy.get('name', '')
        if should_filter(name):
            filtered_nodes.append(name)
        else:
            valid_proxies.append(proxy)
    
    # 更新数据
    data['proxies'] = valid_proxies
    
    # 写回文件
    try:
        with open(yaml_file, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, allow_unicode=True, default_flow_style=False, sort_keys=False)
    except Exception as e:
        print(f"写入文件失败: {e}", file=sys.stderr)
        sys.exit(1)
    
    # 输出结果
    print(f"原始节点数: {original_count}")
    print(f"过滤后节点数: {len(valid_proxies)}")
    print(f"移除节点数: {len(filtered_nodes)}")
    
    if filtered_nodes:
        print("\n已过滤的节点:")
        for node in filtered_nodes:
            print(f"  - {node}")

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

    return $?
}

# ===== get_node_stats() =====
# 输入：提供商 YAML 文件路径
# 功能：打印节点数量和类型分布
get_node_stats() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        log_error "文件不存在: $yaml_file"
        return 1
    fi

    # 使用 Python3 处理 YAML
    python3 - "$yaml_file" << 'PYTHON_SCRIPT'
import sys
import re
from collections import defaultdict
from pathlib import Path

def get_node_type(node_name):
    """获取节点类型描述"""
    if re.search(r'官网|www\..*\.com|Website|Official', node_name, re.IGNORECASE):
        return "官网信息"
    elif re.search(r'剩余流量|套餐到期|距离下次重置|流量|Expire|Traffic', node_name, re.IGNORECASE):
        return "套餐信息"
    elif re.search(r'TG群|Telegram|电报|t\.me|Channel|Group|群组|频道', node_name, re.IGNORECASE):
        return "群组/频道"
    elif re.search(r'订阅|Subscribe|续费|Renew', node_name, re.IGNORECASE):
        return "订阅信息"
    elif re.search(r'更新地址|官网地址', node_name, re.IGNORECASE):
        return "更新地址"
    else:
        return "有效节点"

def main():
    if len(sys.argv) < 2:
        print("用法: python3 node_stats.py <yaml_file>", file=sys.stderr)
        sys.exit(1)
    
    yaml_file = sys.argv[1]
    
    try:
        import yaml
        with open(yaml_file, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
    except ImportError:
        print("需要安装 pyyaml: pip install pyyaml", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"读取文件失败: {e}", file=sys.stderr)
        sys.exit(1)
    
    if not data or 'proxies' not in data:
        print("未找到 proxies 字段", file=sys.stderr)
        sys.exit(1)
    
    proxies = data['proxies']
    total = len(proxies)
    
    # 统计类型分布
    type_counts = defaultdict(int)
    for proxy in proxies:
        name = proxy.get('name', '')
        node_type = get_node_type(name)
        type_counts[node_type] += 1
    
    # 输出统计
    print(f"节点总数: {total}")
    print("\n类型分布:")
    
    for node_type, count in sorted(type_counts.items(), key=lambda x: x[1], reverse=True):
        percentage = (count / total * 100) if total > 0 else 0
        print(f"  {node_type}: {count} ({percentage:.1f}%)")

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

    return $?
}

# ===== 测试函数 =====
# 用于验证过滤逻辑
test_filter_logic() {
    log_step "测试过滤逻辑..."

    # 测试 should_filter_node
    echo "测试 should_filter_node:"
    test_cases=(
        "官网"
        "剩余流量: 10GB"
        "套餐到期: 2024-12-31"
        "TG群: @test_group"
        "订阅信息"
        "香港 IPLC 01"  # 不应该被过滤
        "日本 BGP 02"   # 不应该被过滤
    )

    for test_case in "${test_cases[@]}"; do
        if should_filter_node "$test_case"; then
            echo "  ✓ 过滤: '$test_case'"
        else
            echo "  ✓ 保留: '$test_case'"
        fi
    done

    echo ""
    echo "测试 get_node_type:"
    for test_case in "${test_cases[@]}"; do
        node_type=$(get_node_type "$test_case")
        echo "  '$test_case' -> $node_type"
    done
}

# 主函数（当直接执行时运行测试）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_filter_logic
fi
