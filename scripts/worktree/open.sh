#!/usr/bin/env bash
# Opens a worktree's app in the browser. Sign in with a demo User, such as alice / watchclub.
# Usage: open.sh <worktree-path>
set -euo pipefail

open "$(sed -n 's/^APP_URL=//p' "$1/.env")"
