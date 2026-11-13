#!/usr/bin/env bash
# Stops and deletes what setup.sh and register_webhooks.sh created. Safe to run
# again after a failure.
#
# Names come from the arguments and never from .env: after a failed setup, .env
# can still hold main's values.
# Usage: teardown.sh <slug> <db-suffix> <port>
set -euo pipefail

db="watch_club_$2"
test_db="watch_club_test_$2"
port=$3

lsof -ti "tcp:$port" -sTCP:LISTEN | xargs kill 2>/dev/null || true

# Only this worktree's webhooks match: until they're registered, the rows still
# hold main's.
docker exec wc-db psql -U postgres -At -F $'\t' -d "$db" 2>/dev/null \
  -c "select base_url, api_key, notification_id from servarr_media_sources
      where webhook_callback_base_url = 'http://host.docker.internal:$port'" |
  while IFS=$'\t' read -r base_url api_key notification_id; do
    curl -sS -o /dev/null -X DELETE -H "X-Api-Key: $api_key" \
      "$base_url/api/v3/notification/$notification_id" ||
      echo "Could not delete webhook $notification_id from $base_url" >&2
  done || true

# The worktree's own Radarr, Sonarr and Sportarr, which `mix dev.catalog.seed` started. Their
# ports don't matter to remove them.
RADARR_PORT=0 SONARR_PORT=0 SPORTARR_PORT=0 docker compose --project-name "${db}_servarrs" \
  --file "$(dirname "$0")/../../dev/catalog/docker-compose.yml" down --volumes

docker exec wc-db dropdb -U postgres --if-exists --force "$db"
docker exec wc-db dropdb -U postgres --if-exists --force "$test_db"
