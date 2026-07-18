# Task 8: Refactor setup-service.sh

## Summary
Simplified setup-service.sh from 90 lines to 46 lines by leveraging the new lib/ libraries.

## Changes Made

### setup-service.sh
- **Removed**: 40+ lines of duplicate code
  - Color variable definitions (now from `lib/common.sh`)
  - Manual systemctl checks and service file selection
  - Manual sed/tee/daemon-reload logic
  - Manual systemctl enable/start logic
- **Added**: Library imports and function calls
  - `source lib/common.sh` - colors, log functions, confirm()
  - `source lib/detect.sh` - system detection (get_service_user available)
  - `source lib/service.sh` - install_service(), start_service()
- **Key simplifications**:
  - `install_service "$SERVICE_MODE"` replaces 30+ lines of manual installation
  - `start_service "$SERVICE_NAME"` replaces manual systemctl start logic
  - `confirm` function replaces manual read/prompt handling
  - `log_step`, `log_error`, `log_info` replace echo with color variables

## Verification
- ✅ Syntax check: `bash -n setup-service.sh` passed
- ✅ Commit created: `3358ab5`

## Lines Changed
- **Before**: 90 lines
- **After**: 46 lines
- **Reduction**: 49% fewer lines

## Benefits
1. **Maintainability**: Service logic now lives in lib/service.sh (single source of truth)
2. **Consistency**: Uses standard log_* functions across all scripts
3. **Less duplication**: No more copy-pasted systemctl commands
4. **Better UX**: confirm() function provides consistent prompts
