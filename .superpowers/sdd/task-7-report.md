# Task 7: Refactor scripts/ for mihomo-quick

**Status**: DONE
**Date**: 2026-07-18
**Commit**: `13cc9f1` - refactor: update scripts to use common libraries

## Summary

Updated 7 scripts to use the new lib/ libraries, removing ~350 lines of duplicate code and centralizing common functionality.

## Changes Made

### 1. mihomo-menu
- Sources `lib/common.sh`, `lib/detect.sh`, `lib/service.sh`
- Replaced hardcoded color variables with library colors
- Uses `get_service_status()` for status display
- Uses `restart_service()`, `stop_service()` from service.sh
- Removed duplicate service detection logic

### 2. mihomo-add-sub
- Sources libraries for colors, logging, and service management
- Uses `backup_file()` from common.sh for backups
- Uses `confirm()` for user prompts
- Uses `restart_service()` for service restart
- Added error handling for Python YAML operations (`|| { log_error "..."; return 1; }`)

### 3. mihomo-rules
- Sources libraries for colors, logging, and service management
- Removed hardcoded `OPENCLAW_CONFIG` path
- Added configurable sync via `OPENCLAW_CONFIG` environment variable
- Renamed `sync_from_openclaw()` → `sync_from_config()` to be generic
- Uses `backup_file()` and `confirm()` from common.sh
- Added error handling for Python operations

### 4. mihomo-start
- Sources `lib/service.sh` for process management
- Replaced inline process detection with `start_manual()` from service.sh
- Uses `MIHOMO_BIN`, `CONFIG_DIR`, `LOG_FILE`, `PID_FILE` constants from service.sh
- Reduced from 52 to 35 lines

### 5. mihomo-stop
- Sources `lib/service.sh` for process management
- Single function call: `stop_service()` handles all stop logic
- Handles both manual processes and systemd services
- Reduced from 31 to 10 lines

### 6. mihomo-update
- Sources `lib/network.sh` for `download_with_mirrors()` and `get_latest_release()`
- Sources `lib/detect.sh` for `detect_arch()`
- Uses `log_*` functions from common.sh
- Uses `restart_service()` for service restart
- Removed duplicate mirror list and download functions
- Added error handling for Python operations

### 7. test-all-proxy
- Sources `lib/common.sh` for colors and logging
- **Fixed process detection**: `pgrep -x "mihomo-core"` instead of `pgrep -x "mihomo"`
- Uses `BLUE` color from library instead of hardcoded

## Test Results

All 7 scripts pass `bash -n` syntax validation:
- ✅ mihomo-menu
- ✅ mihomo-add-sub
- ✅ mihomo-rules
- ✅ mihomo-start
- ✅ mihomo-stop
- ✅ mihomo-update
- ✅ test-all-proxy

## Lines Changed

| Script | Before | After | Delta |
|--------|--------|-------|-------|
| mihomo-menu | 222 | 178 | -44 |
| mihomo-add-sub | 324 | 283 | -41 |
| mihomo-rules | 285 | 234 | -51 |
| mihomo-start | 52 | 35 | -17 |
| mihomo-stop | 31 | 10 | -21 |
| mihomo-update | 286 | 230 | -56 |
| test-all-proxy | 81 | 81 | 0 |
| **Total** | **1281** | **1051** | **-230** |

Net reduction: ~230 lines (excluding new library calls)
