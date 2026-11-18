#!/usr/bin/env bash
# Builds the app and runs it on Android or iOS, with the Expo dev server that process-compose runs.
# Usage: run-native.sh android|ios [expo run options]
set -euo pipefail

platform=$1
shift
port=${RCT_METRO_PORT:-8081}

# `expo run` reuses this app's dev server when it already runs on the port, but starts its own,
# outside process-compose, when it doesn't: so start process-compose's first, and wait until it's ready
pnpm --workspace-root dev
if ! process-compose process get expo --output json | grep -q '"is_running": true'; then
  process-compose process start expo
fi
process-compose project is-ready --wait
if ! curl --silent --fail "http://localhost:$port/status" >/dev/null; then
  echo "Expo's dev server doesn't answer on port $port: see process-compose process logs expo" >&2
  exit 1
fi

exec expo run:"$platform" --port "$port" "$@"
