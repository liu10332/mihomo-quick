#!/bin/bash
#
# node_health.sh - 节点健康检查模块
# 提供节点延迟测试、可用性检查、速度测试和状态监控功能
#

# ============================================================================
# 节点健康检查目录
# ============================================================================

# 健康检查目录
HEALTH_CHECK_DIR="${CONFIGS_DIR}/health_check"

# 创建健康检查目录
create_health_check_dirs() {
    mkdir -p "$HEALTH_CHECK_DIR"
    mkdir -p "${HEALTH_CHECK_DIR}/results"
    mkdir -p "${HEALTH_CHECK_DIR}/reports"
    log_debug "健康检查目录创建完成"
}

# ============================================================================
# 节点延迟测试
# ============================================================================

# 测试TCP延迟
test_tcp_latency() {
    local node_server=$1
    local node_port=$2
    local timeout=${3:-5}
    
    log_debug "测试TCP延迟: $node_server:$node_port"
    
    # TCP连接测试
    local start_time=$(date +%s%N)
    
    if timeout $timeout bash -c "echo > /dev/tcp/$node_server/$node_port" 2>/dev/null; then
        local end_time=$(date +%s%N)
        local latency=$(( (end_time - start_time) / 1000000 ))
        
        echo "$latency"
        return 0
    else
        echo "-1"
        return 1
    fi
}

# 测试HTTP延迟
test_http_latency() {
    local node_server=$1
    local node_port=$2
    local timeout=${3:-5}
    
    log_debug "测试HTTP延迟: $node_server:$node_port"
    
    # HTTP请求测试
    local start_time=$(date +%s%N)
    
    if curl -s --connect-timeout $timeout "http://$node_server:$node_port" > /dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local latency=$(( (end_time - start_time) / 1000000 ))
        
        echo "$latency"
        return 0
    else
        echo "-1"
        return 1
    fi
}

# 测试代理延迟
test_proxy_latency() {
    local node_server=$1
    local node_port=$2
    local proxy_type=${3:-"socks5"}
    local timeout=${4:-5}
    
    log_debug "测试代理延迟: $node_server:$node_port ($proxy_type)"
    
    # 代理连接测试
    local start_time=$(date +%s%N)
    
    local test_url="https://httpbin.org/ip"
    
    if [[ "$proxy_type" == "socks5" ]]; then
        if curl -s --connect-timeout $timeout --socks5 "$node_server:$node_port" "$test_url" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local latency=$(( (end_time - start_time) / 1000000 ))
            
            echo "$latency"
            return 0
        else
            echo "-1"
            return 1
        fi
    else
        if curl -s --connect-timeout $timeout --proxy "http://$node_server:$node_port" "$test_url" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local latency=$(( (end_time - start_time) / 1000000 ))
            
            echo "$latency"
            return 0
        else
            echo "-1"
            return 1
        fi
    fi
}

# 测试节点延迟
test_node_latency() {
    local node_name=$1
    local node_server=$2
    local node_port=$3
    local test_type=${4:-"tcp"}
    local timeout=${5:-5}
    
    log_info "测试节点延迟: $node_name"
    
    local latency
    local status
    
    case $test_type in
        tcp)
            latency=$(test_tcp_latency "$node_server" "$node_port" "$timeout")
            ;;
        http)
            latency=$(test_http_latency "$node_server" "$node_port" "$timeout")
            ;;
        proxy)
            latency=$(test_proxy_latency "$node_server" "$node_port" "socks5" "$timeout")
            ;;
        *)
            log_error "不支持的测试类型: $test_type"
            return 1
            ;;
    esac
    
    if [[ "$latency" == "-1" ]]; then
        status="failed"
        echo "节点: $node_name"
        echo "状态: 不可达"
        echo "延迟: -1ms"
    else
        status="success"
        echo "节点: $node_name"
        echo "状态: 可达"
        echo "延迟: ${latency}ms"
    fi
    
    # 保存测试结果
    save_health_check_result "$node_name" "$node_server" "$node_port" "$test_type" "$latency" "$status"
    
    return 0
}

# 批量测试节点延迟
test_nodes_latency_batch() {
    local nodes_file=$1
    local test_type=${2:-"tcp"}
    local timeout=${3:-5}
    
    log_info "批量测试节点延迟..."
    
    if [[ ! -f "$nodes_file" ]]; then
        log_error "节点文件不存在: $nodes_file"
        return 1
    fi
    
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
                
                local latency
                case $test_type in
                    tcp)
                        latency=$(test_tcp_latency "$node_server" "$node_port" "$timeout")
                        ;;
                    http)
                        latency=$(test_http_latency "$node_server" "$node_port" "$timeout")
                        ;;
                    proxy)
                        latency=$(test_proxy_latency "$node_server" "$node_port" "socks5" "$timeout")
                        ;;
                esac
                
                if [[ "$latency" == "-1" ]]; then
                    echo -e "${RED}✗ 不可达${NC}"
                    ((failed++))
                else
                    echo -e "${GREEN}✓${NC} ${latency}ms"
                    ((success++))
                fi
                
                # 保存测试结果
                local status=$([[ "$latency" == "-1" ]] && echo "failed" || echo "success")
                save_health_check_result "$node_name" "$node_server" "$node_port" "$test_type" "$latency" "$status"
            fi
        fi
    done < "$nodes_file"
    
    echo ""
    echo -e "${WHITE}测试统计:${NC}"
    echo "  总节点: $total"
    echo -e "  成功: ${GREEN}$success${NC}"
    echo -e "  失败: ${RED}$failed${NC}"
    echo ""
    
    # 生成测试报告
    generate_health_check_report "$test_type" "$total" "$success" "$failed"
}

# ============================================================================
# 节点可用性检查
# ============================================================================

# 检查节点可用性
check_node_availability() {
    local node_name=$1
    local node_server=$2
    local node_port=$3
    local timeout=${4:-5}
    
    log_info "检查节点可用性: $node_name"
    
    # TCP连接检查
    local tcp_available=0
    if timeout $timeout bash -c "echo > /dev/tcp/$node_server/$node_port" 2>/dev/null; then
        tcp_available=1
    fi
    
    # HTTP检查
    local http_available=0
    if curl -s --connect-timeout $timeout "http://$node_server:$node_port" > /dev/null 2>&1; then
        http_available=1
    fi
    
    # 代理检查
    local proxy_available=0
    if curl -s --connect-timeout $timeout --socks5 "$node_server:$node_port" "https://httpbin.org/ip" > /dev/null 2>&1; then
        proxy_available=1
    fi
    
    # 计算可用性
    local availability=0
    if [[ $tcp_available -eq 1 ]]; then
        ((availability += 33))
    fi
    if [[ $http_available -eq 1 ]]; then
        ((availability += 33))
    fi
    if [[ $proxy_available -eq 1 ]]; then
        ((availability += 34))
    fi
    
    echo "节点: $node_name"
    echo "TCP: $([[ $tcp_available -eq 1 ]] && echo '✓' || echo '✗')"
    echo "HTTP: $([[ $http_available -eq 1 ]] && echo '✓' || echo '✗')"
    echo "代理: $([[ $proxy_available -eq 1 ]] && echo '✓' || echo '✗')"
    echo "可用性: ${availability}%"
    
    # 保存可用性结果
    save_availability_result "$node_name" "$node_server" "$node_port" "$tcp_available" "$http_available" "$proxy_available" "$availability"
    
    return 0
}

# 批量检查节点可用性
check_nodes_availability_batch() {
    local nodes_file=$1
    local timeout=${2:-5}
    
    log_info "批量检查节点可用性..."
    
    if [[ ! -f "$nodes_file" ]]; then
        log_error "节点文件不存在: $nodes_file"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}可用性检查报告:${NC}"
    echo ""
    
    local total=0
    local available=0
    local unavailable=0
    
    # 读取节点文件
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]* ]]; then
            local node_name=$(echo "$line" | cut -d: -f2 | tr -d ' ')
            
            # 提取server和port
            local node_server=$(grep -A 10 "name: $node_name" "$nodes_file" | grep "server:" | head -1 | cut -d: -f2 | tr -d ' ')
            local node_port=$(grep -A 10 "name: $node_name" "$nodes_file" | grep "port:" | head -1 | cut -d: -f2 | tr -d ' ')
            
            if [[ -n "$node_server" && -n "$node_port" ]]; then
                ((total++))
                
                # 检查可用性
                local tcp_available=0
                local http_available=0
                local proxy_available=0
                
                if timeout $timeout bash -c "echo > /dev/tcp/$node_server/$node_port" 2>/dev/null; then
                    tcp_available=1
                fi
                
                if curl -s --connect-timeout $timeout "http://$node_server:$node_port" > /dev/null 2>&1; then
                    http_available=1
                fi
                
                if curl -s --connect-timeout $timeout --socks5 "$node_server:$node_port" "https://httpbin.org/ip" > /dev/null 2>&1; then
                    proxy_available=1
                fi
                
                # 计算可用性
                local availability=0
                if [[ $tcp_available -eq 1 ]]; then
                    ((availability += 33))
                fi
                if [[ $http_available -eq 1 ]]; then
                    ((availability += 33))
                fi
                if [[ $proxy_available -eq 1 ]]; then
                    ((availability += 34))
                fi
                
                if [[ $availability -ge 50 ]]; then
                    echo -e "  ${GREEN}✓${NC} $node_name: ${availability}%"
                    ((available++))
                else
                    echo -e "  ${RED}✗${NC} $node_name: ${availability}%"
                    ((unavailable++))
                fi
                
                # 保存可用性结果
                save_availability_result "$node_name" "$node_server" "$node_port" "$tcp_available" "$http_available" "$proxy_available" "$availability"
            fi
        fi
    done < "$nodes_file"
    
    echo ""
    echo -e "${WHITE}可用性统计:${NC}"
    echo "  总节点: $total"
    echo -e "  可用: ${GREEN}$available${NC}"
    echo -e "  不可用: ${RED}$unavailable${NC}"
    echo ""
}

# ============================================================================
# 节点速度测试
# ============================================================================

# 测试节点速度
test_node_speed() {
    local node_name=$1
    local node_server=$2
    local node_port=$3
    local test_size=${4:-102400}  # 100KB
    
    log_info "测试节点速度: $node_name"
    
    # 下载速度测试
    local download_speed=0
    local start_time=$(date +%s%N)
    
    if curl -s --socks5 "$node_server:$node_port" -o /dev/null "https://httpbin.org/bytes/$test_size" 2>/dev/null; then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))
        
        if [[ $duration -gt 0 ]]; then
            download_speed=$(( test_size / duration ))  # KB/s
        fi
    fi
    
    # 延迟抖动测试
    local jitter=0
    local latencies=()
    
    for i in {1..3}; do
        local latency=$(test_tcp_latency "$node_server" "$node_port" 5)
        if [[ "$latency" != "-1" ]]; then
            latencies+=("$latency")
        fi
        sleep 0.1
    done
    
    if [[ ${#latencies[@]} -ge 2 ]]; then
        local sum=0
        local prev=${latencies[0]}
        
        for latency in "${latencies[@]:1}"; do
            local diff=$((latency - prev))
            if [[ $diff -lt 0 ]]; then
                diff=$((-diff))
            fi
            sum=$((sum + diff))
            prev=$latency
        done
        
        jitter=$((sum / (${#latencies[@]} - 1)))
    fi
    
    echo "节点: $node_name"
    echo "下载速度: ${download_speed} KB/s"
    echo "延迟抖动: ${jitter}ms"
    
    # 保存速度测试结果
    save_speed_result "$node_name" "$node_server" "$node_port" "$download_speed" "$jitter"
    
    return 0
}

# ============================================================================
# 节点状态监控
# ============================================================================

# 监控节点状态
monitor_node_status() {
    local node_name=$1
    local node_server=$2
    local node_port=$3
    local interval=${4:-60}
    local duration=${5:-300}
    
    log_info "监控节点状态: $node_name (间隔: ${interval}s, 时长: ${duration}s)"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    local check_count=0
    local success_count=0
    local failed_count=0
    
    echo ""
    echo -e "${WHITE}节点状态监控:${NC}"
    echo ""
    
    while [[ $(date +%s) -lt $end_time ]]; do
        ((check_count++))
        
        echo -n "  [$(date '+%H:%M:%S')] $node_name: "
        
        # 检查节点状态
        if timeout 5 bash -c "echo > /dev/tcp/$node_server/$node_port" 2>/dev/null; then
            echo -e "${GREEN}✓ 可达${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ 不可达${NC}"
            ((failed_count++))
        fi
        
        # 保存状态记录
        save_status_record "$node_name" "$node_server" "$node_port" "$([[ $? -eq 0 ]] && echo 'success' || echo 'failed')"
        
        # 等待间隔
        sleep $interval
    done
    
    echo ""
    echo -e "${WHITE}监控统计:${NC}"
    echo "  检查次数: $check_count"
    echo -e "  成功: ${GREEN}$success_count${NC}"
    echo -e "  失败: ${RED}$failed_count${NC}"
    echo "  可用性: $((success_count * 100 / check_count))%"
    echo ""
}

# ============================================================================
# 结果保存和报告
# ============================================================================

# 保存健康检查结果
save_health_check_result() {
    local node_name=$1
    local node_server=$2
    local node_port=$3
    local test_type=$4
    local latency=$5
    local status=$6
    
    local result_file="${HEALTH_CHECK_DIR}/results/$(date +%Y%m%d_%H%M%S)_${node_name}.json"
    
    cat > "$result_file" << EOF
{
  "node_name": "$node_name",
  "node_server": "$node_server",
  "node_port": "$node_port",
  "test_type": "$test_type",
  "latency": $latency,
  "status": "$status",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
}

# 保存可用性结果
save_availability_result() {
    local node_name=$1
    local node_server=$2
    local node_port=$3
    local tcp_available=$4
    local http_available=$5
    local proxy_available=$6
    local availability=$7
    
    local result_file="${HEALTH_CHECK_DIR}/results/$(date +%Y%m%d_%H%M%S)_${node_name}_availability.json"
    
    cat > "$result_file" << EOF
{
  "node_name": "$node_name",
  "node_server": "$node_server",
  "node_port": "$node_port",
  "tcp_available": $tcp_available,
  "http_available": $http_available,
  "proxy_available": $proxy_available,
  "availability": $availability,
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
}

# 保存速度测试结果
save_speed_result() {
    local node_name=$1
    local node_server=$2
    local node_port=$3
    local download_speed=$4
    local jitter=$5
    
    local result_file="${HEALTH_CHECK_DIR}/results/$(date +%Y%m%d_%H%M%S)_${node_name}_speed.json"
    
    cat > "$result_file" << EOF
{
  "node_name": "$node_name",
  "node_server": "$node_server",
  "node_port": "$node_port",
  "download_speed": $download_speed,
  "jitter": $jitter,
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
}

# 保存状态记录
save_status_record() {
    local node_name=$1
    local node_server=$2
    local node_port=$3
    local status=$4
    
    local record_file="${HEALTH_CHECK_DIR}/results/$(date +%Y%m%d)_${node_name}_status.log"
    
    echo "$(date '+%H:%M:%S') $status" >> "$record_file"
}

# 生成健康检查报告
generate_health_check_report() {
    local test_type=$1
    local total=$2
    local success=$3
    local failed=$4
    
    local report_file="${HEALTH_CHECK_DIR}/reports/$(date +%Y%m%d_%H%M%S)_${test_type}_report.md"
    
    cat > "$report_file" << EOF
# 节点健康检查报告

## 报告信息
- 测试类型: $test_type
- 测试时间: $(date '+%Y-%m-%d %H:%M:%S')
- 总节点数: $total
- 成功节点: $success
- 失败节点: $failed
- 成功率: $((success * 100 / total))%

## 测试结果
详见测试结果文件。

## 建议
1. 定期进行健康检查
2. 关注失败节点
3. 优化延迟高的节点
4. 监控可用性变化

---
*报告由 mihomo-quick 自动生成*
EOF
    
    log_info "健康检查报告已生成: $report_file"
}

# ============================================================================
# 统计分析函数
# ============================================================================

# 分析延迟统计
analyze_latency_stats() {
    local results_dir="${HEALTH_CHECK_DIR}/results"
    
    log_info "分析延迟统计..."
    
    echo ""
    echo -e "${WHITE}延迟统计分析:${NC}"
    echo ""
    
    # 提取所有延迟数据
    local latencies=()
    local successful=0
    local failed=0
    
    for result_file in "$results_dir"/*.json; do
        if [[ -f "$result_file" ]]; then
            local latency=$(grep '"latency"' "$result_file" | cut -d: -f2 | tr -d ' ,')
            local status=$(grep '"status"' "$result_file" | cut -d: -f2 | tr -d ' ,"')
            
            if [[ "$status" == "success" && "$latency" != "-1" ]]; then
                latencies+=("$latency")
                ((successful++))
            else
                ((failed++))
            fi
        fi
    done
    
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
    
    local avg=$((sum / ${#latencies[@]}))
    
    echo "  总测试次数: $((successful + failed))"
    echo "  成功次数: $successful"
    echo "  失败次数: $failed"
    echo "  平均延迟: ${avg}ms"
    echo "  最小延迟: ${min}ms"
    echo "  最大延迟: ${max}ms"
    echo ""
}

echo "✓ 已加载节点健康检查模块: node_health.sh"
