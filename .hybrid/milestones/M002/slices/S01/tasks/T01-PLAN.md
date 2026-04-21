# T01 完善配置模板 任务计划

## 任务目标
完善现有配置模板，添加更多配置项，确保模板的完整性和实用性。

## 步骤分解

### 步骤1: 完善基础配置模板
```yaml
# 基础配置模板
mixed-port: {HTTP_PORT}
socks-port: {SOCKS_PORT}
allow-lan: {ALLOW_LAN}
bind-address: '{BIND_ADDRESS}'
mode: {MODE}
log-level: {LOG_LEVEL}
external-controller: {API_ADDRESS}:{API_PORT}
secret: '{API_SECRET}'
external-ui: {CONFIG_DIR}/dashboard

# IPv6配置
ipv6: {IPV6_ENABLED}

# DNS配置
dns:
  enable: {DNS_ENABLED}
  ipv6: {DNS_IPV6}
  enhanced-mode: {DNS_MODE}
  fake-ip-range: {FAKE_IP_RANGE}
  fake-ip-filter:
  {FAKE_IP_FILTER}
  default-nameserver:
  {DEFAULT_DNS}
  nameserver:
  {NAMESERVER}
  fallback:
  {FALLBACK_DNS}
  fallback-filter:
    geoip: {FALLBACK_GEOIP}
    geoip-code: {FALLBACK_GEOIP_CODE}
    ipcidr:
    {FALLBACK_IPCIDR}
```

### 步骤2: 完善TUN模式模板
```yaml
# TUN模式配置模板
tun:
  enable: true
  stack: {TUN_STACK}
  dns-hijack:
    - any:53
  auto-route: {TUN_AUTO_ROUTE}
  auto-detect-interface: {TUN_AUTO_DETECT}
  device: {TUN_DEVICE}
  mtu: {TUN_MTU}
  strict-route: {TUN_STRICT_ROUTE}
  gateway: {TUN_GATEWAY}
  iproute2-table: {TUN_ROUTE_TABLE}
  iproute2-rule: {TUN_ROUTE_RULE}
  gso: {TUN_GSO}
  checksum: {TUN_CHECKSUM}
```

### 步骤3: 完善系统代理模板
```yaml
# 系统代理配置模板
mixed-port: {HTTP_PORT}
socks-port: {SOCKS_PORT}
allow-lan: {ALLOW_LAN}
bind-address: '{BIND_ADDRESS}'
mode: {MODE}

# 系统代理模式下的额外配置
# 注意：系统代理模式下，TUN配置应该禁用
tun:
  enable: false
```

### 步骤4: 完善订阅配置模板
```yaml
# 订阅配置模板
proxy-providers:
  {PROVIDER_NAME}:
    type: http
    url: "{PROVIDER_URL}"
    interval: {PROVIDER_INTERVAL}
    health-check:
      enable: true
      interval: {HEALTH_CHECK_INTERVAL}
      url: {HEALTH_CHECK_URL}
    override:
      skip-cert-verify: {SKIP_CERT_VERIFY}
    filter: "{PROVIDER_FILTER}"
    exclude: "{PROVIDER_EXCLUDE}"
```

### 步骤5: 完善规则配置模板
```yaml
# 规则配置模板
rules:
  # 本地网络
  - DOMAIN-SUFFIX,local,DIRECT
  - DOMAIN-SUFFIX,localhost,DIRECT
  - DOMAIN-SUFFIX,ip6-localhost,DIRECT
  - DOMAIN-SUFFIX,ip6-loopback,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,100.64.0.0/10,DIRECT
  - IP-CIDR,224.0.0.0/4,DIRECT
  - IP-CIDR,fe80::/10,DIRECT
  
  # 中国IP
  - GEOIP,CN,{CHINA_PROXY_GROUP}
  
  # 用户自定义规则
  {USER_RULES}
  
  # 默认规则
  - MATCH,{DEFAULT_PROXY_GROUP}
```

## 验收标准
1. 模板完整
2. 配置项齐全
3. 格式正确
4. 变量齐全

## 预计时间
2小时

## 创建日期
2026-04-21 12:41:20
