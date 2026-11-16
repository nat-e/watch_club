#!/usr/bin/env bash
# Runs the server's and the web app's dev servers, and Expo's with --expo. Passes other flags to turbo.
# Usage: pnpm dev [--expo] [turbo flags]
set -euo pipefail

args=(run dev --filter=server --filter=web)
for arg in "$@"; do
  if [[ $arg == --expo ]]; then
    args+=(--filter=mobile)
  else
    args+=("$arg")
  fi
done
exec turbo "${args[@]}"
