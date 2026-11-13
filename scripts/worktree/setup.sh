#!/usr/bin/env bash
# Sets up a new worktree, once .env and the build caches are copied into it: its databases,
# seeded from the dev catalog with its own Radarr, Sonarr and Sportarr, see
# dev/catalog/README.md.
# Usage: setup.sh <slug> <db-suffix> <port>
set -euo pipefail

slug=$1
db="watch_club_$2"
test_db="watch_club_test_$2"
port=$3

sed -E \
  -e "s|^(WC_DATABASE_URL=.*/).*|\1$db|" \
  -e "s|^WC_URL=.*|WC_URL=http://$slug.localhost:$port|" \
  -e "s|^WC_PORT=.*|WC_PORT=$port|" \
  .env >.env.worktree
printf '\nWC_TEST_DATABASE=%s\nWC_LIVE_DEBUGGER_PORT=%s\n' "$test_db" "$((port + 10000))" >>.env.worktree
mv .env.worktree .env

# Approving the Tidewave server here avoids a prompt in each new worktree.
settings=.claude/settings.local.json
[[ -f $settings ]] || echo '{}' >"$settings"
jq '.enabledMcpjsonServers = ["tidewave-mcp"]' "$settings" >"$settings.worktree"
mv "$settings.worktree" "$settings"

# A worktree whose seed failed, such as without the internet, still works: `mix reset`
# seeds it again.
mix ecto.setup || echo "Couldn't seed the database: run mix reset" >&2
