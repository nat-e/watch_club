#!/usr/bin/env bash
# Brings the primary worktree's tools, Postgres and database up to date with what was merged.
# The dev server picks up the new code on its own.
set -euo pipefail

mise install
mise exec -- pnpm install
# Applies the changes to Postgres in docker-compose.dev.yml, and starts it if it's stopped
mise exec -- pnpm dev:shared
# Regenerate the uncommitted API client so the dev server picks up merged API changes
mise exec -- turbo run generate:client
mise exec -- sqlx migrate run --source apps/server/migrations
