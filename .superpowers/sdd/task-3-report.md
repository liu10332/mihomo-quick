# Task 3: Create lib/network.sh

## Status: DONE

## Summary

Created `lib/network.sh` with 7 network utility functions, sourced dependencies, verified syntax, and committed.

## Files Created

- `lib/network.sh` — 239 lines

## Functions Implemented

| Function | Description |
|---|---|
| `GITHUB_MIRRORS` | Array of 4 GitHub mirror sites |
| `download_with_mirrors URL OUTPUT DESC` | Download with mirror fallback + direct connect |
| `get_latest_release REPO` | Get latest GitHub release tag (API + tags fallback) |
| `configure_firewall PORT PROTO` | Auto-detect and configure ufw/firewalld/iptables |
| `configure_selinux PORT` | Add SELinux port policy if enforcing |
| `test_dns_resolve DOMAIN` | Test DNS resolution (dig/nslookup/getent) |
| `test_network HOST PORT` | Test connectivity (nc /dev/tcp/curl) |

## Test Results

- `bash -n lib/network.sh` — passed (no syntax errors)
- Commit: `1211d35 feat: add network utility library`

## Notes

- Sources `lib/common.sh` for logging; `lib/detect.sh` sourced conditionally (doesn't exist yet)
- `download_with_mirrors` tries all mirrors then direct, cleans up partial files
- `configure_firewall` is non-destructive: only warns on iptables (no sudo auto-run)
- `configure_selinux` skips gracefully when not enforcing or semanage unavailable
