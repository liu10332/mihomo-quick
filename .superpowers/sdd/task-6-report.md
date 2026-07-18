# Task 6: Refactor install.sh

## Summary
Rewrote install.sh to use the new lib/ libraries, eliminating ~300 lines of duplicated code.

## Changes Made

### install.sh
- Removed inline color definitions, detect_arch(), get_latest_release(), download_with_mirrors()
- Added sourcing of lib/common.sh, lib/detect.sh, lib/network.sh, lib/service.sh
- Replaced inline echo with log_info/log_error/log_step/log_title functions
- Used detect_arch(), detect_distro_name(), detect_current_user() for system detection
- Used find_available_port() for automatic port selection (7890, 7891, 9090)
- Used download_with_mirrors() and get_latest_release() from lib/network.sh
- Used backup_file() for consistent backup naming
- Used confirm() for user prompts
- Generated config from templates/config.yaml with auto-detected values:
  - API secret: openssl rand -hex 16
  - Ports: auto-detected available ports
  - TUN device: detected via detect_tun_device()
- Installed systemd services using templates with variable substitution
- Default MATCH rule is now DIRECT (from template)

### New Functions
- show_system_info(): Displays distro, arch, user
- check_required_deps(): Validates curl, tar, openssl
- install_services(): Handles both normal and TUN mode systemd services

### Removed Code
- Inline color variable definitions (now in lib/common.sh)
- Duplicate detect_arch() function
- Duplicate get_latest_release() function
- Duplicate download_with_mirrors() function
- install_one_service() helper (replaced by inline logic with templates)

## Test Results
- `bash -n install.sh` - PASSED (no syntax errors)
- Script sources all 4 library files correctly
- Template variable substitution verified

## Commits
- refactor: universal install script with auto-detection
