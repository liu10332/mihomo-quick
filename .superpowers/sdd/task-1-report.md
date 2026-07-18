# Task 1: Create lib/common.sh

## Status: DONE

## Summary

Created `lib/common.sh` — the shared function library for all mihomo-quick scripts. Includes color variables with terminal detection, 5 logging functions, error handling (`die`), confirmation prompt with configurable default, file backup utility, and progress bar display.

## Deliverables

- `lib/common.sh` — complete function library (122 lines)

## Functions Implemented

| Function | Description |
|----------|-------------|
| `log_info` | Green success messages |
| `log_warn` | Yellow warning messages |
| `log_error` | Red error messages (stderr) |
| `log_step` | Cyan step/status messages |
| `log_title` | White section titles with spacing |
| `die` | Print error and exit 1 |
| `confirm` | Prompt with configurable default (Y/n or y/N) |
| `backup_file` | Backup file with timestamped `.bak` suffix |
| `show_progress` | Terminal progress bar with percentage |

## Color Variables

- `GREEN`, `YELLOW`, `RED`, `CYAN`, `WHITE`, `BLUE`, `NC`
- Auto-disabled when stdout is not a terminal or `TERM=dumb`

## Test Results

- `bash -n lib/common.sh` — **PASS** (syntax verified)

## Commits

- `864ac02` feat: add common function library
