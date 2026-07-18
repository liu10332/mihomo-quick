# Task 2: mihomo-sub Subscription Management

## Status: DONE

## Summary

Created `scripts/mihomo-sub` - a complete subscription management script with full lifecycle support (add/update/remove/list/refresh/filter) and corrected fallback logic.

## What Was Done

### 1. Created `scripts/mihomo-sub` (813 lines)
Full-featured subscription management script supporting:
- **CLI commands**: `mihomo-sub [add|update|remove|list|refresh|filter]`
- **Interactive menu**: When run without arguments
- **Command aliases**: `ls`, `up`, `rm`, `delete`

### 2. Fixed Fallback Logic (Critical Fix)

**Old broken logic** (in `scripts/mihomo-add-sub`):
- Backup subscriptions were added directly to fallback group's `proxies` list as provider names
- This caused mihomo to fail because proxy-providers can't be directly referenced in proxy-groups

**New correct logic**:
- Each subscription gets its own `url-test` group (e.g., `📡 订阅名`)
- These groups are added to `🔄 故障转移` fallback group's `proxies` list
- Fallback group proxies reference group names, not provider names

Example structure:
```yaml
proxy-groups:
  - name: 📡 主订阅
    type: url-test
    use: [primary-sub]
  - name: 📡 备用订阅
    type: url-test
    use: [backup-sub]
  - name: 🔄 故障转移
    type: fallback
    proxies:
      - 📡 主订阅
      - 📡 备用订阅
      - DIRECT
  - name: 📱 手动选择
    type: select
    proxies:
      - 🔄 故障转移
      - 📡 主订阅
      - 📡 备用订阅
      - DIRECT
    use: [primary-sub, backup-sub]
```

### 3. Proxy Chain Selection
- Auto-detects available proxy groups (url-test, fallback, load-balance)
- Excludes manual selection groups
- Presents numbered list for user selection

### 4. Node Filtering Integration
- Calls `filter_provider_nodes()` after adding/refreshing subscriptions
- Supports `mihomo-sub filter` to filter all subscriptions

### 5. Functions Implemented
- `cmd_list()` - List all subscriptions
- `cmd_add()` - Add new subscription
- `cmd_update()` - Update existing subscription
- `cmd_remove()` - Delete subscription
- `cmd_refresh()` - Refresh all subscriptions
- `cmd_filter()` - Filter invalid nodes
- `select_provider()` - Select provider from list
- `select_proxy_chain()` - Select proxy chain
- `get_available_groups()` - Get available proxy groups
- `add_provider()` - Add provider to config
- `update_provider()` - Update provider URL/interval
- `remove_provider()` - Remove provider from config
- `ensure_fallback_group()` - Ensure fallback group exists
- `ensure_select_group()` - Ensure select group exists
- `filter_provider_nodes()` - Filter invalid nodes for a provider

## Test Results

- Syntax check: PASS (`bash -n scripts/mihomo-sub`)
- Backup file call signatures: PASS (matches `backup_file()` in `lib/common.sh`)

## Commits

- `f89f864` feat: rewrite subscription management

## Files Touched

- `scripts/mihomo-sub` (created, 813 lines)

## Key Design Decisions

1. **Preserved existing script structure**: Used same patterns as other scripts (sourcing lib/common.sh, lib/detect.sh, lib/service.sh, lib/filter.sh)
2. **Single backup_file call**: Fixed incorrect two-argument call from old script to single-argument call matching `backup_file()` signature
3. **Python3 for YAML**: Continued using Python3 for YAML processing (pyyaml required)
4. **Group naming convention**: `📡 {name}` for url-test groups, consistent with task requirements
5. **Manual group handling**: Select group uses both `use` (provider names) and `proxies` (group names) correctly
