# T01 节点延迟测试 任务计划

## 任务目标
实现节点延迟测试功能，包括TCP连接测试、HTTP延迟测试和代理延迟测试。

## 步骤分解

### 步骤1: TCP连接测试
```bash
test_tcp_latency() {
    local node_server=$1
    local node_port=$2
    local timeout=$3
    
    log_info "测试TCP延迟: $node_server:$node_port"
    
    # TCP连接测试
    local start_time=$(date +%s%N)
    
    if timeout $timeout bash -c "echo > /dev/tcp/$node_server/$node_port" 2>/dev/null; then
        local end_time=$(date +%s%N)
        local latency=$(( (end_time - start_time) / 1000000 ))
        
        echo "延迟: ${latency}ms"
        return 0
    else
        echo "不可达"
        return 1
    fi
}
```

### 步骤2: HTTP延迟测试
```bash
test_http_latency() {
    local node_server=$1
    local node_port=$2
    local timeout=$3
    
    log_info "测试HTTP延迟: $node_server:$node_port"
    
    # HTTP请求测试
    local start_time=$(date +%s%N)
    
    if curl -s --connect-timeout $timeout "http://$node_server:$node_port" > /dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local latency=$(( (end_time - start_time) / 1000000 ))
        
        echo "延迟: ${latency}ms"
        return 0
    else
        echo "不可达"
        return 1
    fi
}
```

### 步骤3: 代理延迟测试
```bash
test_proxy_latency() {
    local node_server=$1
    local node_port=$2
    local proxy_type=$3
    local timeout=$4
    
    log_info "测试代理延迟: $node_server:$node_port ($proxy_type)"
    
    # 代理连接测试
    local start_time=$(date +%s%N)
    
    if [[ "$proxy_type" == "socks5" ]]; then
        if curl -s --connect-timeout $timeout --socks5 "$node_server:$node_port" "https://httpbin.org/ip" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local latency=$(( (end_time - start_time) / 1000000 ))
            
            echo "延迟: ${latency}ms"
            return 0
        else
            echo "不可达"
            return 1
        fi
    else
        if curl -s --connect-timeout $timeout --proxy "http://$node_server:$node_port" "https://httpbin.org/ip" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local latency=$(( (end_time - start_time) / 1000000 ))
            
            echo "延迟: ${latency}ms"
            return 0
        else
            echo "不可达"
            return 1
        fi
    fi
}
```

### 步骤4: 批量延迟测试
```bash
test_nodes_latency_batch() {
    local nodes_file=$1
    local test_type=$2
    local timeout=$3
    
    log_info "批量测试节点延迟..."
    
    echo ""
    echo -e "${WHITE}延迟测试报告:${NC}"
    echo ""
    
    local total=0
    local success=0
    local failed=0
    
    # 读取节点文件
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]* ]]; then
            local node_name=$(echo "$line" | cut -d: -f2 | tr -d ' ')
            
            # 提取server和port
            local node_server=$(grep -A 10 "name: $node_name" "$nodes_file" | grep "server:" | head -1 | cut -d: -f2 | tr -d ' ')
            local node_port=$(grep -A 10 "name: $node_name" "$nodes_file" | grep "port:" | head -1 | cut -d: -f2 | tr -d ' ')
            
            if [[ -n "$node_server" && -n "$node_port" ]]; then
                ((total++))
                
                echo -n "  $node_name: "
                
                case $test_type in
                    tcp)
                        if test_tcp_latency "$node_server" "$node_port" "$timeout" > /dev/null; then
                            echo -e "${GREEN}✓${NC} $(test_tcp_latency "$node_server" "$node_port" "$timeout")"
                            ((success++))
                        else
                            echo -e "${RED}✗ 不可达${NC}"
                            ((failed++))
                        fi
                        ;;
                    http)
                        if test_http_latency "$node_server" "$node_port" "$timeout" > /dev/null; then
                            echo -e "${GREEN}✓${NC} $(test_http_latency "$node_server" "$node_port" "$timeout")"
                            ((success++))
                        else
                            echo -e "${RED}✗ 不可达${NC}"
                            ((failed++))
                        fi
                        ;;
                    proxy)
                        if test_proxy_latency "$node_server" "$node_port" "socks5" "$timeout" > /dev/null; then
                            echo -e "${GREEN}✓${NC} $(test_proxy_latency "$node_server" "$node_port" "socks5" "$timeout")"
                            ((success++))
                        else
                            echo -e "${RED}✗ 不可达${NC}"
                            ((failed++))
                        fi
                        ;;
                esac
            fi
        fi
    done < "$nodes_file"
    
    echo ""
    echo -e "${WHITE}测试统计:${NC}"
    echo "  总节点: $total"
    echo -e "  成功: ${GREEN}$success${NC}"
    echo -e "  失败: ${RED}$failed${NC}"
    echo ""
}
```

### 步骤5: 延迟统计分析
```bash
analyze_latency_stats() {
    local test_results=$1
    
    log_info "分析延迟统计..."
    
    echo ""
    echo -e "${WHITE}延迟统计分析:${NC}"
    echo ""
    
    # 提取延迟数据
    local latencies=()
    while IFS= read -r line; do
        if [[ "$line" =~ 延迟:[[:space:]]*([0-9]+)ms ]]; then
            latencies+=("${BASH_REMATCH[1]}")
        fi
    done <<< "$test_results"
    
    if [[ ${#latencies[@]} -eq 0 ]]; then
        echo "  没有延迟数据"
        return 1
    fi
    
    # 计算统计信息
    local sum=0
    local min=${latencies[0]}
    local max=${latencies[0]}
    
    for latency in "${latencies[@]}"; do
        sum=$((sum + latency))
        
        if [[ $latency -lt $min ]]; then
            min=$latency
        fi
        
        if [[ $latency -gt $max ]]; then
            max=$latency
        fi
    done
    
    local avg=$((sum / {#latencies[@]}))
    
    echo "  平均延迟: ${avg}ms"
    echo "  最小延迟: ${min}ms"
    echo "  最大延迟: ${max}ms"
    echo "  测试次数: {#latencies[@]}"
    echo ""
}
```

## 验收标准
1. 测试准确
2. 统计完整
3. 分析详细

## 预计时间
2小时

## 创建日期
2026-04-21 14:09:06
