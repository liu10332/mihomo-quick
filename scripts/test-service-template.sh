#!/bin/bash
# test-service-template.sh - 服务模板回归测试
#
# 验证两件事：
#   1. TUN 模板渲染结果不带 User= / ip 预处理 / *_PROXY / 未替换占位符
#   2. 任一缺陷出现时 assert_service_unit_safe 必须拒绝写入
#
# 背景：templates/mihomo-tun.service 曾经带着 User={USER} 与 ip tuntap 预处理，
# 跑 setup-service.sh tun 会装出一个起不来的服务。本测试防止回归。
#
# 用法: ./scripts/test-service-template.sh   （不写 /etc/systemd，干跑）

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/mihomo-quick-test.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/systemd"

PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# 假 sudo / systemctl：函数优先于二进制，安装流程全部落到测试目录
sudo() { "$@"; }
systemctl() { echo "FAKE-SYSTEMCTL $*"; return 0; }

# shellcheck source=../lib/service.sh
source "$SCRIPT_ROOT/lib/common.sh"
source "$SCRIPT_ROOT/lib/detect.sh"
source "$SCRIPT_ROOT/lib/service.sh"

SYSTEMD_DIR="$T/systemd"

render() {  # render <template> <out> <mode> <user> <bin> [dev] [gw]
    local tpl="$1" out="$2" mode="$3" u="$4" b="$5" dev="${6:-}" gw="${7:-}"
    sed -e "s/{USER}/$u/g" -e "s|{HOME}|$HOME|g" -e "s|{BIN_DIR}|$b|g" \
        -e "s|{CONFIG_DIR}|$HOME/.config/mihomo|g" -e "s/{TUN_DEVICE}/$dev/g" \
        -e "s/{TUN_GATEWAY}/$gw/g" -e "s|/root|$HOME|g" "$tpl" > "$out" || return 1
    [[ -s "$out" ]] || { echo "渲染失败(输出为空): $tpl"; return 1; }
}
require_rendered() { [[ -s "$1" ]] && ok "渲染成功: $(basename "$1")" || bad "渲染失败: $1"; }

echo "===== A. TUN 模板渲染后必须通过自检"
render "$SCRIPT_ROOT/templates/mihomo-tun.service" "$T/tun.service" tun "$(id -un)" "$HOME/.local/bin" tun0 10.0.0.1
require_rendered "$T/tun.service"
assert_service_unit_safe "$T/tun.service" tun && ok "TUN 模板通过" || bad "TUN 模板被误拒"

echo "===== B. 单个缺陷都必须被拦下"
printf '[Service]\nType=simple\nUser=liu\nExecStart=/bin/true\n' > "$T/only-user.service"
printf '[Service]\nType=simple\nExecStartPre=-/sbin/ip tuntap add tun0 mode tun\nExecStart=/bin/true\n' > "$T/only-ip.service"
printf '[Service]\nType=simple\nEnvironment=HTTP_PROXY=http://127.0.0.1:7890\nExecStart=/bin/true\n' > "$T/only-proxy.service"
printf '[Service]\nExecStart={BIN_DIR}/mihomo-core\n' > "$T/leftover.service"
printf '[Service]\n# 注释里提到 User={USER} 和 ip tuntap，但注释不该触发误报\nExecStart=/bin/true\n' > "$T/comment-only.service"

assert_service_unit_safe "$T/only-user.service" tun     && bad "未拦住 User="            || ok "拦住 User="
assert_service_unit_safe "$T/only-ip.service" tun       && bad "未拦住 ip 预处理"        || ok "拦住 ip 预处理"
assert_service_unit_safe "$T/only-proxy.service" tun    && bad "未拦住 *_PROXY"          || ok "拦住 *_PROXY"
assert_service_unit_safe "$T/leftover.service" normal   && bad "未拦住未替换占位符"      || ok "拦住未替换占位符"
assert_service_unit_safe "$T/comment-only.service" tun  && ok "注释不误判"        || bad "注释被误判为缺陷"

echo "===== C. 普通模式模板必须通过（User= 在 normal 下合法）"
render "$SCRIPT_ROOT/templates/mihomo.service" "$T/normal.service" normal "$(id -un)" "$HOME/.local/bin"
require_rendered "$T/normal.service"
assert_service_unit_safe "$T/normal.service" normal && ok "普通模板通过" || bad "普通模板被误拒"

echo "===== D. install_service 干跑（写入测试目录，不碰 /etc/systemd）"
install_service tun > "$T/install-tun.log" 2>&1 && ok "install_service tun 返回 0" || { bad "install_service tun 失败"; sed -n '1,15p' "$T/install-tun.log"; }
UNIT="$T/systemd/mihomo-tun.service"
[[ -f "$UNIT" ]] && ok "TUN unit 已写入" || bad "TUN unit 未写入"
grep -qE '^(User|Group)=' "$UNIT" 2>/dev/null                       && bad "写出的 unit 有 User="   || ok "写出的 unit 无 User="
grep -qE '^Exec(StartPre|StopPost)=.*ip (tuntap|addr|link)' "$UNIT" 2>/dev/null && bad "写出的 unit 有 ip 预处理" || ok "写出的 unit 无 ip 预处理"
grep -qi '_PROXY=' "$UNIT" 2>/dev/null                              && bad "写出的 unit 有代理变量" || ok "写出的 unit 无代理变量"
grep -q '{[A-Z_]*}' "$UNIT" 2>/dev/null                             && bad "写出的 unit 有未替换占位符" || ok "占位符全部替换"
if command -v systemd-analyze &>/dev/null; then
    systemd-analyze verify "$UNIT" > "$T/verify.log" 2>&1 || true
    grep -q "mihomo-tun" "$T/verify.log" && bad "systemd-analyze 报告本 unit 有问题" || ok "systemd-analyze 校验通过"
fi

echo "===== E. 普通模式干跑"
install_service normal > "$T/install-normal.log" 2>&1 && ok "install_service normal 返回 0" || { bad "install_service normal 失败"; sed -n '1,15p' "$T/install-normal.log"; }
[[ -f "$T/systemd/mihomo.service" ]] && ok "normal unit 已写入" || bad "normal unit 未写入"

echo ""
echo "===== 结果: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
