#!/bin/bash
#
# test-all-proxy.sh - 综合代理测试脚本
# 参照 mihomo-proxy-export 的 test-all-proxy 脚本
#
# 测试内容:
#   1. 环境检查（mihomo进程、代理端口）
#   2. 大模型API直连测试
#   3. 代理基本连接测试
#   4. 外网访问测试（通过代理）
#   5. 国内网站直连测试
#   6. 代理IP信息
#   7. 配置摘要
#

# ============================================================================
# 颜色定义
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# 配置
# ============================================================================

HTTP_PROXY_PORT="${HTTP_PROXY_PORT:-7890}"
SOCKS_PROXY_PORT="${SOCKS_PROXY_PORT:-7891}"
API_PORT="${API_PORT:-9090}"
HTTP_PROXY="http://127.0.0.1:${HTTP_PROXY_PORT}"

# 计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ============================================================================
# 测试函数
# ============================================================================

# 测试直连
test_direct() {
    local name="$1"
    local url="$2"

    ((TOTAL_TESTS++))
    echo -n "  测试 $name (直连): "

    if timeout 10 curl -s -I "$url" 2>&1 | grep -q "HTTP/"; then
        echo -e "${GREEN}✅ 成功${NC}"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}❌ 失败${NC}"
        ((FAILED_TESTS++))
        return 1
    fi
}

# 测试代理
test_with_proxy() {
    local name="$1"
    local url="$2"

    ((TOTAL_TESTS++))
    echo -n "  测试 $name (代理): "

    if [[ -z "$http_proxy" ]]; then
        echo -e "${YELLOW}⚠️ 代理未设置${NC}"
        ((FAILED_TESTS++))
        return 1
    fi

    if timeout 10 curl -s --proxy "$http_proxy" "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 成功${NC}"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}❌ 失败${NC}"
        ((FAILED_TESTS++))
        return 1
    fi
}

# ============================================================================
# 主测试流程
# ============================================================================

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  mihomo-quick 综合代理测试                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================================
# 1. 环境检查
# ============================================================================

echo -e "${BLUE}1. 环境检查${NC}"
echo ""

# 检查mihomo进程
echo -n "  mihomo进程: "
if pgrep -x "mihomo" > /dev/null 2>&1; then
    local_pid=$(pgrep -x "mihomo" | head -1)
    echo -e "${GREEN}✅ 运行中 (PID: $local_pid)${NC}"
else
    echo -e "${RED}❌ 未运行${NC}"
    echo ""
    echo -e "${YELLOW}提示: 请先启动 mihomo 服务${NC}"
    echo "  ./mihomo-quick.sh start"
    exit 1
fi

# 检查代理端口
echo -n "  HTTP代理端口 (${HTTP_PROXY_PORT}): "
if netstat -tuln 2>/dev/null | grep -q ":${HTTP_PROXY_PORT} "; then
    echo -e "${GREEN}✅ 监听中${NC}"
else
    echo -e "${RED}❌ 未监听${NC}"
fi

echo -n "  SOCKS代理端口 (${SOCKS_PROXY_PORT}): "
if netstat -tuln 2>/dev/null | grep -q ":${SOCKS_PROXY_PORT} "; then
    echo -e "${GREEN}✅ 监听中${NC}"
else
    echo -e "${RED}❌ 未监听${NC}"
fi

# 检查环境变量
echo -n "  环境变量 (http_proxy): "
if [[ -n "$http_proxy" ]]; then
    echo -e "${GREEN}✅ 已设置: $http_proxy${NC}"
else
    echo -e "${YELLOW}⚠️ 未设置${NC}"
    echo ""
    echo -e "${YELLOW}提示: 请设置代理环境变量${NC}"
    echo "  source scripts/proxy-env.sh on"
fi

echo ""

# ============================================================================
# 2. 大模型API直连测试
# ============================================================================

echo -e "${BLUE}2. 大模型API直连测试${NC}"
echo ""

test_direct "Anthropic API" "https://api.anthropic.com"
test_direct "火山引擎 (volces.com)" "https://ark.cn-beijing.volces.com"
test_direct "智谱AI (bigmodel.cn)" "https://open.bigmodel.cn"

echo ""

# ============================================================================
# 3. 代理基本连接测试
# ============================================================================

echo -e "${BLUE}3. 代理基本连接测试${NC}"
echo ""

test_with_proxy "httpbin.org" "http://httpbin.org/ip"
test_with_proxy "Cloudflare" "https://cloudflare.com"

echo ""

# ============================================================================
# 4. 外网访问测试（通过代理）
# ============================================================================

echo -e "${BLUE}4. 外网访问测试${NC}"
echo ""

test_with_proxy "Google" "https://www.google.com"
test_with_proxy "GitHub" "https://github.com"
test_with_proxy "DuckDuckGo" "https://duckduckgo.com"

echo ""

# ============================================================================
# 5. 国内网站直连测试
# ============================================================================

echo -e "${BLUE}5. 国内网站直连测试${NC}"
echo ""

test_direct "百度" "https://www.baidu.com"
test_direct "腾讯" "https://www.qq.com"

echo ""

# ============================================================================
# 6. 代理IP信息
# ============================================================================

echo -e "${BLUE}6. 代理IP信息${NC}"
echo ""

if [[ -n "$http_proxy" ]]; then
    echo -n "  获取代理IP: "
    proxy_ip=$(timeout 15 curl -s --proxy "$http_proxy" "https://api.ipify.org?format=json" 2>/dev/null)
    if [[ -n "$proxy_ip" ]]; then
        echo -e "${GREEN}$proxy_ip${NC}"
    else
        echo -e "${YELLOW}无法获取${NC}"
    fi
else
    echo -e "  ${YELLOW}代理未设置，跳过${NC}"
fi

echo ""

# ============================================================================
# 7. 配置摘要
# ============================================================================

echo -e "${BLUE}7. 配置摘要${NC}"
echo ""
echo "  代理端口: ${HTTP_PROXY_PORT} (HTTP), ${SOCKS_PROXY_PORT} (SOCKS5)"
echo "  控制面板: http://127.0.0.1:${API_PORT}/ui"
echo "  当前代理: ${http_proxy:-未设置}"
echo ""

# ============================================================================
# 测试结果
# ============================================================================

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${WHITE}测试结果:${NC}"
echo "  总测试: $TOTAL_TESTS"
echo -e "  成功: ${GREEN}$PASSED_TESTS${NC}"
echo -e "  失败: ${RED}$FAILED_TESTS${NC}"
echo ""

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}🎉 所有测试通过！代理配置正常。${NC}"
else
    echo -e "${YELLOW}⚠️ 部分测试失败，请检查代理配置。${NC}"
fi

echo ""
echo -e "${YELLOW}💡 常用命令:${NC}"
echo "  # 设置代理环境变量"
echo "  source scripts/proxy-env.sh on"
echo ""
echo "  # 测试代理"
echo "  curl --proxy http://127.0.0.1:${HTTP_PROXY_PORT} https://www.google.com"
echo ""
echo "  # 测试直连（大模型API）"
echo "  curl -I https://ark.cn-beijing.volces.com"
echo ""

exit $FAILED_TESTS
