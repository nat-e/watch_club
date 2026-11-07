#!/usr/bin/env bash
# Keeps a worktree's local prototypes (dev/prototypes, ignored by git) from being lost. Run from the
# worktree. `wt step copy-ignored` copies the primary worktree's prototypes into a new worktree.
#
#   prototypes.sh snapshot
#     Records the copied prototypes' checksums in dev/prototypes/.base-checksums.
#
#   prototypes.sh save <primary worktree path>
#     Before the worktree is removed, copies its new and changed prototypes back to the primary
#     worktree. A prototype that only changed in the primary worktree since the snapshot is left
#     alone. Prototypes deleted in this worktree stay in the primary worktree.
#
#     Only a merged branch's prototypes replace the primary copy. When one changed
#     in both worktrees, the newer copy wins and the other one is kept next to it, as
#     <name>.ex.before-<branch>.bak (the primary worktree's) or <name>.ex.from-<branch>.bak (this
#     worktree's). An unmerged branch's prototypes are all kept as <name>.ex.from-<branch>.bak.
set -euo pipefail

checksums=dev/prototypes/.base-checksums

snapshot() {
  [ -d dev/prototypes ] || return 0
  (cd dev/prototypes && find . -type f ! -name .base-checksums -exec shasum -a 256 -- {} + > .base-checksums)
}

checksum() { shasum -a 256 "$1" | cut -d ' ' -f 1; }

checksum_at_snapshot() {
  awk -v name="$1" '$2 == name || $2 == "./" name { print $1 }' "$checksums" 2> /dev/null || true
}

# worktrunk counts a branch as merged when merging it would add nothing, which also catches squash
# merges. Uncommitted changes are lost with the worktree, so they make the branch unmerged.
merged() {
  local branch="$1"
  [ -z "$(git status --porcelain)" ] &&
    wt list --format=json | jq -e --arg branch "$branch" \
      '.items[] | select(.branch == $branch) | .default_branch.integration != null' > /dev/null
}

save() {
  local primary="$1/dev/prototypes" branch suffix
  branch="$(git branch --show-current)"
  suffix="${branch//\//-}"

  # Worktrees created before prototypes were copied link to the primary worktree's folder
  if [ ! -d dev/prototypes ] || [ -L dev/prototypes ]; then
    return 0
  fi

  mkdir -p "$primary"
  local is_merged=false
  if merged "$branch"; then is_merged=true; fi

  while IFS= read -r -d '' file; do
    local name target copied
    name="${file#dev/prototypes/}"
    target="$primary/$name"
    copied="$(checksum_at_snapshot "$name")"
    mkdir -p "$(dirname "$target")"

    if [ "$(checksum "$file")" = "$copied" ] || cmp -s "$file" "$target"; then
      continue
    elif [ "$is_merged" = false ]; then
      cp -p "$file" "$target.from-$suffix.bak"
    elif [ ! -e "$target" ] || [ "$(checksum "$target")" = "$copied" ]; then
      cp -p "$file" "$target"
    elif [ "$file" -nt "$target" ]; then
      cp -p "$target" "$target.before-$suffix.bak"
      cp -p "$file" "$target"
    else
      cp -p "$file" "$target.from-$suffix.bak"
    fi
  done < <(find dev/prototypes -type f ! -name .base-checksums -print0)
}

case "$1" in
  snapshot) snapshot ;;
  save) save "$2" ;;
esac
