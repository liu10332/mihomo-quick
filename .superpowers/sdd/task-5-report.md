# Task 5: Create templates/ directory — Report

## Status: DONE

## Summary

Created `templates/` directory with three template files containing placeholder variables for mihomo-quick service and config management.

## Files Created

1. **templates/mihomo.service** — Standard systemd service template
   - Variables: `{USER}`, `{HOME}`, `{BIN_DIR}`, `{CONFIG_DIR}`
   - Replaces hardcoded `/root` paths with user-specific placeholders

2. **templates/mihomo-tun.service** — TUN mode systemd service template
   - Same variables as mihomo.service, plus `{TUN_DEVICE}` and `{TUN_GATEWAY}` for TUN device configuration
   - Includes TUN device setup/cleanup ExecStartPre/ExecStopPost

3. **templates/config.yaml** — Mihomo config template
   - Port variables: `{HTTP_PORT}`, `{SOCKS_PORT}`, `{API_PORT}`
   - Auth: `{API_SECRET}` (random API secret)
   - Paths: `{CONFIG_DIR}`
   - TUN: `{TUN_ENABLE}`, `{TUN_DEVICE}`, `{TUN_GATEWAY}`

## Design Decisions

- Placeholders use `{VAR}` style (not `/root` sed-replacement) for clarity and safety
- TUN service template includes the same proxy environment variables as the original
- Config template preserves the DNS, geox-url, and rules structure from the existing `config/config.yaml`
- All templates are designed to be processed by `lib/service.sh`'s `install_service()` via sed replacement

## Commit

```
979afb3 feat: add service and config templates
```
