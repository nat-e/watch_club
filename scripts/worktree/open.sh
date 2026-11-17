#!/usr/bin/env bash
# Opens a worktree's app in the browser. Sign in as admin, with the password passw0rd.
# Usage: open.sh <worktree-path>
set -euo pipefail

open "$(sed -n 's/^APP_URL=//p' "$1/.env")"
