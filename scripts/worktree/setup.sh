#!/usr/bin/env bash
# Sets up a new worktree, once .env and the build caches are copied into it.
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

docker exec wc-db createdb -U postgres "$db"
docker exec wc-db pg_dump -U postgres watch_club_dev |
  docker exec -i wc-db psql -q -v ON_ERROR_STOP=1 -U postgres -d "$db" >/dev/null

# Queued jobs belong to main: running them here would resubmit its requests to
# Radarr and Sonarr. Download progress jobs only read from them, so they stay.
docker exec wc-db psql -q -U postgres -d "$db" -c "
  delete from oban_jobs
  where worker <> 'WatchClub.Requests.Workers.RefreshMediaSourceRequest'
    or state not in ('available', 'scheduled', 'retryable')"

# Approving the Tidewave server here avoids a prompt in each new worktree.
settings=.claude/settings.local.json
[[ -f $settings ]] || echo '{}' >"$settings"
jq '.enabledMcpjsonServers = ["tidewave-mcp"]' "$settings" >"$settings.worktree"
mv "$settings.worktree" "$settings"
