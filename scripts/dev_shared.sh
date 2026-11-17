#!/usr/bin/env bash
# Starts the services of docker-compose.dev.yml, which the worktrees share: Postgres, and the
# Radarr, Sonarr and Sportarr of the dev catalog, restored from its snapshot the first time.
# --reset-catalog restores the catalog again, which undoes every change to it.
# Usage: dev_shared.sh [--reset-catalog]
set -euo pipefail

# The services come from the primary worktree, whichever worktree runs this
cd "$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")"
# The catalog's clips, which docker-compose.dev.yml mounts in the apps
media=$PWD/tmp/catalog
# Written once a restore succeeds, so that the next start tries again after a failure
restored=$media/.restored
apps=(radarr sonarr sportarr)

compose() {
  docker compose --file docker-compose.dev.yml "$@"
}

# Replaces the clips, and the apps' data with the snapshot's: the Docker volumes
# watch_club_rs_<app>_snapshot
restore_catalog() {
  for app in "${apps[@]}"; do
    if ! docker volume inspect "watch_club_rs_${app}_snapshot" >/dev/null 2>&1; then
      echo "The dev catalog's snapshot volume watch_club_rs_${app}_snapshot is missing: copy it" \
        "from the snapshot of the Elixir app's mix dev.catalog.seed" >&2
      exit 1
    fi
  done
  compose rm --stop --force "${apps[@]}"

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
    compose run --rm --no-deps --no-TTY --volume "watch_club_rs_${app}_snapshot:/snapshot:ro" \
      --entrypoint sh "$app" -c 'find /config -mindepth 1 -delete && cp -a /snapshot/. /config/'
  done
  touch "$restored"
}

case ${1:-} in
  "") ;;
  --reset-catalog) rm -f "$restored" ;;
  *)
    echo "Usage: $0 [--reset-catalog]" >&2
    exit 1
    ;;
esac

# Postgres first, which the worktrees need even when the catalog fails
compose up --detach --wait db
if [[ ! -e $restored ]]; then
  restore_catalog
fi
compose up --detach
