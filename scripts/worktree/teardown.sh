#!/usr/bin/env bash
# Stops and deletes what setup.sh created. Safe to run again after a failure.
#
# Names come from the arguments and never from .env: after a failed setup, .env can still hold the
# primary worktree's.
# Usage: teardown.sh <slug> <database> <port>
set -euo pipefail

slug=$1
database=$2
port=$3

# The server, and the web app's dev server on the next port
lsof -ti "tcp:$port,$((port + 1))" -sTCP:LISTEN | xargs kill 2>/dev/null || true

# The worktree's database, and the test databases named after it that killed test runs left, see
# apps/server/src/testing.rs
docker compose --file "$(dirname "$0")/../../docker-compose.dev.yml" exec -T db \
  psql -U postgres -v ON_ERROR_STOP=1 -v database="$database" <<'SQL'
SELECT format('DROP DATABASE %I WITH (FORCE)', datname)
FROM pg_database
WHERE datname = :'database' OR starts_with(datname, :'database' || '-test-')
\gexec
SQL

# Worktrees set up before Postgres was shared have their own
docker compose --project-name "watch-club-rs-$slug" down --volumes
