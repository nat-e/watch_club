#!/usr/bin/env bash
# Replaces each Radarr/Sonarr webhook copied from main's database with one that
# calls this worktree, cloned from main's so that both stay subscribed to the
# same events.
# Usage: register_webhooks.sh <slug> <db-suffix> <port>
set -euo pipefail

slug=$1
db="watch_club_$2"
port=$3
callback_base="http://host.docker.internal:$port"

for _ in $(seq 300); do
  curl -s -o /dev/null "http://localhost:$port" && break
  sleep 2
done

docker exec wc-db psql -U postgres -At -F $'\t' -d "$db" \
  -c "select id, flavor, base_url, api_key, notification_id from servarr_media_sources" |
  while IFS=$'\t' read -r id flavor base_url api_key notification_id; do
    new_id=$(
      curl -fsS -H "X-Api-Key: $api_key" "$base_url/api/v3/notification/$notification_id" |
        jq --arg name "WatchClub $id $slug" --arg url "$callback_base/webhooks/$flavor/$id" \
          'del(.id) | .name = $name | (.fields[] | select(.name == "url")).value = $url' |
        curl -fsS -X POST -H "X-Api-Key: $api_key" -H 'Content-Type: application/json' -d @- \
          "$base_url/api/v3/notification" |
        jq -r .id
    )

    docker exec wc-db psql -q -U postgres -d "$db" -c "
      update servarr_media_sources
      set notification_id = $new_id, webhook_callback_base_url = '$callback_base'
      where id = '$id'"
  done
