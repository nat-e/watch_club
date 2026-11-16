#!/usr/bin/env bash
# Stops and deletes what setup.sh created. Safe to run again after a failure.
# Usage: teardown.sh <slug> <port>
set -euo pipefail

slug=$1
port=$2

# The server, and the web app's dev server on the next port
lsof -ti "tcp:$port,$((port + 1))" -sTCP:LISTEN | xargs kill 2>/dev/null || true
docker compose -p "watch-club-rs-$slug" down --volumes
