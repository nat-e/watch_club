#!/usr/bin/env bash
# Sets up a new worktree, once .env and the build cache are copied into it: its own database in the
# Postgres that the worktrees share, with the migrations and the demo data.
# Usage: setup.sh <slug> <database> <port>
set -euo pipefail

slug=$1
database=$2
port=$3
web_port=$((port + 1))
expo_port=$((port + 2))

# .env files from before the web app's and Expo's dev servers lack their ports
grep -q '^WEB_PORT=' .env || echo 'WEB_PORT=' >>.env
grep -q '^RCT_METRO_PORT=' .env || echo 'RCT_METRO_PORT=' >>.env
sed -E \
  -e "s|^(DATABASE_URL=.*/).*|\1$database|" \
  -e "s|^PORT=.*|PORT=$port|" \
  -e "s|^WEB_PORT=.*|WEB_PORT=$web_port|" \
  -e "s|^RCT_METRO_PORT=.*|RCT_METRO_PORT=$expo_port|" \
  -e "s|^APP_URL=.*|APP_URL=http://$slug.localhost:$web_port|" \
  .env >.env.worktree
mv .env.worktree .env

# mise only loads .env for a trusted config, and trust goes by path
mise trust --quiet mise.toml

# Postgres, and the dev catalog, which the worktree works without until the server connects to
# Radarr, Sonarr and Sportarr
"$(dirname "$0")/../dev_shared.sh" || echo "Some shared services didn't start, see above" >&2
mise exec -- pnpm install
# The API client and Expo Router's types aren't committed: generate them now, for the editor
mise exec -- turbo run generate:client generate:routes
mise exec -- sqlx database setup --source apps/server/migrations
mise exec -- pnpm --filter server seed
