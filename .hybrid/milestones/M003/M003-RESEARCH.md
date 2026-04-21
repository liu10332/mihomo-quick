# M003 技术研究

## 订阅解析和存储

### 1. 订阅格式
- YAML格式: 标准mihomo配置
- JSON格式: 兼容其他客户端
- 原始格式: base64编码
- 链接格式: 订阅链接

### 2. 节点信息提取
```bash
# 提取节点信息
extract_nodes() {
    local subscription_file=$1
    
    # 提取proxies部分
    grep -A 1000 "^proxies:" "$subscription_file" |         grep -B 1000 "^[a-zA-Z]" |         grep -v "^proxies:" > nodes.yaml
    
    # 解析节点信息
    while IFS= read -r line; do
        if [[ "$line" =~ name: ]]; then
            node_name=$(echo "$line" | cut -d: -f2 | tr -d ' ')
        elif [[ "$line" =~ server: ]]; then
            node_server=$(echo "$line" | cut -d: -f2 | tr -d ' ')
        elif [[ "$line" =~ port: ]]; then
            node_port=$(echo "$line" | cut -d: -f2 | tr -d ' ')
        fi
    done < nodes.yaml
}
```

### 3. 订阅存储
```
~/.config/mihomo/
├── subscriptions/
│   ├── provider-a.yaml
│   ├── provider-b.yaml
│   └── providers.json
├── nodes/
│   ├── all-nodes.yaml
│   ├── healthy-nodes.yaml
│   └── nodes-status.json
└── config.yaml
```

## 节点健康检查

### 1. 延迟测试
```bash
# 测试节点延迟
test_node_latency() {
    local node=$1
    local timeout=$    2
    
    # TCP连接测试
    if timeout $timeout bash -c "echo > /dev/tcp/$node_server/$node_port" 2>/dev/null; then
        echo "延迟: $(($(date +%s%N) - start_time))ns"
    else
        echo "不可达"
    fi
}
```

### 2. 可用性检查
- HTTP状态检查
- TCP连接检查
- 代理功能检查

### 3. 速度测试
- 下载速度测试
- 上传速度测试
- 延迟抖动测试

## 故障转移配置

### 1. 主备模式
```yaml
proxy-groups:
  - name: "主备组"
    type: select
    proxies:
      - 主节点
      - 备节点1
      - 备节点2
```

### 2. 自动故障转移
```yaml
proxy-groups:
  - name: "自动转移"
    type: url-test
    url: http://cp.cloudflare.com/generate_204
    interval: 300
    tolerance: 50
    lazy: true
    proxies:
      - 节点1
      - 节点2
      - 节点3
```

## 节点筛选和分组

### 1. 筛选规则
- 按国家/地区筛选
- 按延迟筛选
- 按速度筛选
- 按协议筛选

### 2. 分组管理
- 按用途分组
- 按性能分组
- 按协议分组
- 按地区分组

## 参考项目
1. [clash订阅转换](https://github.com/tindy2013/subconverter)
2. [clash节点管理](https://github.com/haishanh/yacd)
3. [订阅健康检查](https://github.com/JeziL/Clash.Meta)
