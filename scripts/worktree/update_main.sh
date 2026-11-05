#!/usr/bin/env bash
# Brings the primary worktree up to date with GitHub and installs what the new
# commits need. The dev server keeps its old dependencies and config until it
# restarts.
set -euo pipefail

git fetch
git merge --ff-only '@{upstream}' || git rebase '@{upstream}'
git push

mise install
mise exec -- mix deps.get
mise exec -- mix assets.setup
mise exec -- mix ecto.migrate
