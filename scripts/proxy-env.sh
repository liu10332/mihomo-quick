#!/bin/bash
#
# proxy-env.sh - 代理环境变量管理脚本
# 参照 mihomo-proxy-export 的 proxy-env 和 set-proxy-env 脚本
#
# 用法:
#   proxy-env.sh on/start    启用代理环境变量
#   proxy-env.sh off/stop    禁用代理环境变量
#   proxy-env.sh status      查看当前状态
#   proxy-env.sh test        测试代理连接
#   proxy-env.sh config      配置代理参数
#   proxy-env.sh npm-on      启用npm代理
#   proxy-env.sh npm-off     禁用npm代理
#

# ============================================================================
# 配置
# ============================================================================

# 代理服务器地址和端口
PROXY_HOST="127.0.0.1"
HTTP_PROXY_PORT="${HTTP_PROXY_PORT:-7890}"
SOCKS_PROXY_PORT="${SOCKS_PROXY_PORT:-7891}"

# 代理URL
HTTP_PROXY="http://${PROXY_HOST}:${HTTP_PROXY_PORT}"
SOCKS_PROXY="socks5://${PROXY_HOST}:${SOCKS_PROXY_PORT}"

# ============================================================================
# 排除域名配置（大模型API必须直连）
# ============================================================================

NO_PROXY_DOMAINS="
# 大模型API（必须直连）
*.anthropic.com
*.bigmodel.cn
*.dataeyes.ai
*.openai.com
*.openrouter.ai
*.volcengine.com
*.volces.com
*.xiaomimimo.com

# 国内主要网站
*.163.com
*.alibaba.com
*.alipay.com
*.aliyun.com
*.baidu.com
*.bilibili.com
*.jd.com
*.mi.com
*.qq.com
*.sina.com.cn
*.sohu.com
*.taobao.com
*.tencent.com
*.tmall.com
*.weixin.qq.com
*.xiaomi.com

# 本地网络
localhost
127.0.0.1
::1
10.*
172.16.*
172.17.*
172.18.*
172.19.*
172.20.*
172.21.*
172.22.*
172.23.*
172.24.*
172.25.*
172.26.*
172.27.*
172.28.*
172.29.*
172.30.*
172.31.*
192.168.*
"

# ============================================================================
# 颜色定义
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# 函数
# ============================================================================

# 启用代理
enable_proxy() {
    export http_proxy="${HTTP_PROXY}"
    export https_proxy="${HTTP_PROXY}"
    export HTTP_PROXY="${HTTP_PROXY}"
    export HTTPS_PROXY="${HTTP_PROXY}"
    export ALL_PROXY="${SOCKS_PROXY}"
    export all_proxy="${SOCKS_PROXY}"

    # 设置排除规则（压缩格式，去掉注释和空行）
    export no_proxy="$(echo ${NO_PROXY_DOMAINS} | grep -v '^#' | grep -v '^$' | tr '\n' ',' | tr -s ',' | sed 's/^,//' | sed 's/,$//')"
    export NO_PROXY="${no_proxy}"

    echo -e "${GREEN}✅ 代理环境变量已设置${NC}"
    echo ""
    echo -e "${BLUE}📊 配置详情:${NC}"
    echo "   HTTP代理: ${HTTP_PROXY}"
    echo "   SOCKS代理: ${SOCKS_PROXY}"
    echo ""
    echo -e "${BLUE}🔧 当前环境变量:${NC}"
    echo "   http_proxy=${http_proxy}"
    echo "   https_proxy=${https_proxy}"
    echo "   ALL_PROXY=${ALL_PROXY}"
    echo "   no_proxy=$(echo ${no_proxy} | cut -c1-80)..."
}

# 禁用代理
disable_proxy() {
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    unset ALL_PROXY all_proxy
    unset no_proxy NO_PROXY

    echo -e "${GREEN}✅ 代理环境变量已清除${NC}"
}

# 查看状态
show_status() {
    echo -e "${BLUE}📊 当前代理状态:${NC}"
    echo ""
    echo "   http_proxy=${http_proxy:-${YELLOW}未设置${NC}}"
    echo "   https_proxy=${https_proxy:-${YELLOW}未设置${NC}}"
    echo "   ALL_PROXY=${ALL_PROXY:-${YELLOW}未设置${NC}}"
    echo "   no_proxy=${no_proxy:-${YELLOW}未设置${NC}}"
    echo ""

    # 检查mihomo是否运行
    if pgrep -x "mihomo" > /dev/null 2>&1; then
        echo -e "   mihomo: ${GREEN}运行中${NC}"
    else
        echo -e "   mihomo: ${RED}未运行${NC}"
    fi

    # 检查npm代理
    if command -v npm &> /dev/null; then
        local npm_proxy=$(npm config get proxy 2>/dev/null)
        echo "   npm proxy=${npm_proxy:-${YELLOW}未设置${NC}}"
    fi
}

# 测试代理
test_proxy() {
    echo -e "${BLUE}🧪 测试代理连接...${NC}"
    echo ""

    # 1. 测试直连（大模型API）
    echo -n "1. 测试大模型API直连 (volces.com): "
    if curl -s -I --connect-timeout 5 https://ark.cn-beijing.volces.com 2>&1 | grep -q "HTTP/"; then
        echo -e "${GREEN}✅ 直连成功${NC}"
    else
        echo -e "${RED}❌ 直连失败${NC}"
    fi

    # 2. 测试代理基本连接
    echo -n "2. 测试代理基本连接: "
    if [[ -n "$http_proxy" ]]; then
        if timeout 5 curl -s --proxy "$http_proxy" http://httpbin.org/ip > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 代理工作${NC}"
        else
            echo -e "${RED}❌ 代理失败${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ 代理未设置${NC}"
    fi

    # 3. 测试代理外网访问
    echo -n "3. 测试代理外网访问 (Google): "
    if [[ -n "$http_proxy" ]]; then
        if timeout 10 curl -s --proxy "$http_proxy" https://www.google.com > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 访问成功${NC}"
        else
            echo -e "${RED}❌ 访问失败${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ 代理未设置${NC}"
    fi

    # 4. 获取代理IP
    echo ""
    echo -e "${BLUE}📍 代理IP信息:${NC}"
    if [[ -n "$http_proxy" ]]; then
        local proxy_ip=$(timeout 10 curl -s --proxy "$http_proxy" https://api.ipify.org?format=json 2>/dev/null)
        if [[ -n "$proxy_ip" ]]; then
            echo "   $proxy_ip"
        else
            echo -e "   ${YELLOW}无法获取${NC}"
        fi
    else
        echo -e "   ${YELLOW}代理未设置${NC}"
    fi
}

# 配置代理
config_proxy() {
    echo -e "${BLUE}⚙️ 配置代理参数:${NC}"
    echo ""

    read -p "代理主机 [${PROXY_HOST}]: " new_host
    PROXY_HOST=${new_host:-$PROXY_HOST}

    read -p "HTTP代理端口 [${HTTP_PROXY_PORT}]: " new_http_port
    HTTP_PROXY_PORT=${new_http_port:-$HTTP_PROXY_PORT}

    read -p "SOCKS代理端口 [${SOCKS_PROXY_PORT}]: " new_socks_port
    SOCKS_PROXY_PORT=${new_socks_port:-$SOCKS_PROXY_PORT}

    HTTP_PROXY="http://${PROXY_HOST}:${HTTP_PROXY_PORT}"
    SOCKS_PROXY="socks5://${PROXY_HOST}:${SOCKS_PROXY_PORT}"

    echo ""
    echo -e "${GREEN}✅ 代理配置已更新:${NC}"
    echo "   HTTP代理: ${HTTP_PROXY}"
    echo "   SOCKS代理: ${SOCKS_PROXY}"
    echo ""
    echo -e "${YELLOW}提示: 请执行 'proxy-env.sh on' 使配置生效${NC}"
}

# 启用npm代理
enable_npm_proxy() {
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm 未安装${NC}"
        return 1
    fi

    npm config set proxy "${HTTP_PROXY}" 2>/dev/null
    npm config set https-proxy "${HTTP_PROXY}" 2>/dev/null

    echo -e "${GREEN}✅ npm 代理已启用: ${HTTP_PROXY}${NC}"
}

# 禁用npm代理
disable_npm_proxy() {
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm 未安装${NC}"
        return 1
    fi

    npm config delete proxy 2>/dev/null
    npm config delete https-proxy 2>/dev/null

    echo -e "${GREEN}✅ npm 代理已禁用${NC}"
}

# 显示帮助
show_help() {
    echo "用法: proxy-env.sh [命令]"
    echo ""
    echo "命令:"
    echo "  on/start     启用代理环境变量"
    echo "  off/stop     禁用代理环境变量"
    echo "  status       查看当前状态"
    echo "  test         测试代理连接"
    echo "  config       配置代理参数"
    echo "  npm-on       启用npm代理"
    echo "  npm-off      禁用npm代理"
    echo ""
    echo "当前配置:"
    echo "  代理: ${PROXY_HOST}:${HTTP_PROXY_PORT}"
    echo ""
    echo "排除的域名:"
    echo "${NO_PROXY_DOMAINS}" | grep -v '^#' | grep -v '^$' | head -10
    echo "  ..."
}

# ============================================================================
# 主逻辑
# ============================================================================

case "${1:-}" in
    on|start)
        enable_proxy
        ;;
    off|stop)
        disable_proxy
        ;;
    status)
        show_status
        ;;
    test)
        test_proxy
        ;;
    config)
        config_proxy
        ;;
    npm-on)
        enable_npm_proxy
        ;;
    npm-off)
        disable_npm_proxy
        ;;
    *)
        show_help
        ;;
esac
