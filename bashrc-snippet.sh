# ========== mihomo-quick 代理配置 ==========

# 自动设置代理环境变量
if [ -f ~/.local/bin/set-proxy-env ]; then
    source ~/.local/bin/set-proxy-env >/dev/null 2>&1
fi

# 快捷命令
alias proxy-start="mihomo-start"
alias proxy-stop="mihomo-stop"
alias proxy-restart="mihomo-stop && sleep 2 && mihomo-start"
alias proxy-status="pgrep -x mihomo && echo '✅ Mihomo 运行中' || echo '⚠️ Mihomo 未运行'"
alias proxy-test="test-all-proxy"

# ========== mihomo-quick 配置结束 ==========
