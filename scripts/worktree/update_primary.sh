#!/usr/bin/env bash
# Brings the primary worktree up to date with what was merged on GitHub: its code, then its tools and
# database. The dev server picks up the new code on its own.
set -euo pipefail

# New worktrees branch from the local base branch, so it must not stay behind
git fetch --quiet
git merge --ff-only --quiet '@{upstream}'

mise install
mise exec -- pnpm install
# Regenerate the uncommitted API client so the dev server picks up merged API changes
mise exec -- turbo run generate:client
mise exec -- sqlx migrate run --source apps/server/migrations
