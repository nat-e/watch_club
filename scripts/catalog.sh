#!/usr/bin/env bash
# Runs the dev catalog, which every worktree shares: the clips of dev/catalog/media, in the primary
# worktree's tmp/catalog, and the Radarr, Sonarr and Sportarr of dev/catalog/docker-compose.yml,
# which hold them, on ports 4103, 4104 and 4105.
#   start: starts them, restored from their snapshot the first time
#   reset: restores them from their snapshot, which undoes every change to them
# Usage: catalog.sh start|reset
set -euo pipefail

# The worktrees share one catalog, so it comes from the primary worktree, whichever runs this
cd "$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")"
media=$PWD/tmp/catalog
# Written once a restore succeeds, so that start tries again after a failure
restored=$media/.restored
project=watch-club-rs-catalog
apps=(radarr sonarr sportarr)

compose() {
  CATALOG_MEDIA=$media docker compose --project-name "$project" \
    --file dev/catalog/docker-compose.yml "$@"
}

# Replaces the clips, and the apps' data with the snapshot's: the Docker volumes
# watch-club-rs-catalog-snapshot-*
restore() {
  for app in "${apps[@]}"; do
    if ! docker volume inspect "$project-snapshot-$app" >/dev/null 2>&1; then
      echo "The snapshot's volume $project-snapshot-$app is missing: copy it from the snapshot of" \
        "the Elixir app's mix dev.catalog.seed" >&2
      exit 1
    fi
  done
  compose down --volumes

  # Clones of the files in Git LFS's store, which the worktrees share, take no extra disk space on
  # APFS, Btrfs or XFS
  local clone=(cp --reflink=auto)
  if [[ $(uname) == Darwin ]]; then clone=(cp -c); fi
  rm -rf "$media"
  # .lfsconfig keeps the clips out of clones and fetches
  git lfs fetch --include 'dev/catalog/media/**' --exclude ''
  git lfs ls-files --long --include 'dev/catalog/media/**' HEAD |
    while read -r oid _ path; do
      target=$media/${path#dev/catalog/media/}
      mkdir -p "$(dirname "$target")"
      "${clone[@]}" ".git/lfs/objects/${oid:0:2}/${oid:2:2}/$oid" "$target"
    done

  for app in "${apps[@]}"; do
    compose run --rm --no-deps --no-TTY --volume "$project-snapshot-$app:/snapshot:ro" \
      --entrypoint cp "$app" -a /snapshot/. /config/
  done
  touch "$restored"
}

case ${1:-} in
  start)
    if [[ ! -e $restored ]]; then
      restore
    fi
    ;;
  reset) restore ;;
  *)
    echo "Usage: $0 start|reset" >&2
    exit 1
    ;;
esac
compose up --detach
