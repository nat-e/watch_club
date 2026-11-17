#!/usr/bin/env bash
# Sets up a new worktree, once .env and the build cache are copied into it: its own Postgres, with
# the migrations and the demo data, and the dev catalog that the worktrees share.
# Usage: setup.sh <slug> <port>
set -euo pipefail

slug=$1
port=$2
web_port=$((port + 1))
expo_port=$((port + 2))
db_port=$((port + 10000))

# .env files from before the web app's and Expo's dev servers lack their ports
grep -q '^WEB_PORT=' .env || echo 'WEB_PORT=' >>.env
grep -q '^RCT_METRO_PORT=' .env || echo 'RCT_METRO_PORT=' >>.env
sed -E \
  -e "s|^DATABASE_URL=.*|DATABASE_URL=postgres://postgres:postgres@localhost:$db_port/watch_club|" \
  -e "s|^PORT=.*|PORT=$port|" \
  -e "s|^WEB_PORT=.*|WEB_PORT=$web_port|" \
  -e "s|^RCT_METRO_PORT=.*|RCT_METRO_PORT=$expo_port|" \
  -e "s|^APP_URL=.*|APP_URL=http://$slug.localhost:$web_port|" \
  .env >.env.worktree
mv .env.worktree .env

# mise only loads .env for a trusted config, and trust goes by path
mise trust --quiet mise.toml

DB_PORT=$db_port docker compose -p "watch-club-rs-$slug" up -d --wait
mise exec -- pnpm install
# The API client and Expo Router's types aren't committed: generate them now, for the editor
mise exec -- turbo run generate:client generate:routes
mise exec -- sqlx database setup --source apps/server/migrations
mise exec -- pnpm --filter server seed
# The worktree works without it, until the server connects to Radarr, Sonarr and Sportarr
"$(dirname "$0")/../catalog.sh" start || echo "Couldn't start the dev catalog" >&2
