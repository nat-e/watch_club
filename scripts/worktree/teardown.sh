#!/usr/bin/env bash
# Stops and deletes what setup.sh created. Safe to run again after a failure.
#
# Names come from the arguments and never from .env: after a failed setup, .env can still hold the
# primary worktree's.
# Usage: teardown.sh <slug> <port> [<database>]
set -euo pipefail

slug=$1
port=$2
# Worktrees set up before Postgres was shared don't pass it
database=${3:-}

# The dev processes. The hook runs in the worktree, whose mise.toml says where they are
mise exec -- process-compose down 2>/dev/null || true
# And a server or web app started outside them
lsof -ti "tcp:$port,$((port + 1))" -sTCP:LISTEN | xargs kill 2>/dev/null || true

# The worktree's database, and the test databases named after it that killed test runs left, see
# apps/server/src/testing.rs
if [[ -n $database ]]; then
  docker compose --file "$(dirname "$0")/../../docker-compose.dev.yml" exec -T db \
    psql -U postgres -v ON_ERROR_STOP=1 -v database="$database" <<'SQL'
SELECT format('DROP DATABASE %I WITH (FORCE)', datname)
FROM pg_database
WHERE datname = :'database' OR starts_with(datname, :'database' || '-test-')
\gexec
SQL
fi

# Worktrees set up before Postgres was shared have their own
docker compose --project-name "watch-club-rs-$slug" down --volumes
