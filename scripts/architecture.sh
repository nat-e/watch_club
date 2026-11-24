#!/usr/bin/env bash
# Lays out the System Context, Container and Component diagrams of docs/architecture, then draws
# every diagram as Mermaid in the README.md beside it, which GitHub shows.
# --check validates the model and fails when a layout or the README doesn't match it, without
# changing them.
# Usage: architecture.sh [--check]
set -euo pipefail

cd "$(dirname "$0")/.."
model=docs/architecture

if [[ "${1:-}" != --check ]]; then
  node scripts/architecture-layout.mjs
  pnpm exec likec4 export markdown "$model"
  exit
fi

if ! pnpm exec likec4 validate --max-warnings 0 "$model"; then
  echo "The model is invalid, or a diagram doesn't match its layout. Run pnpm fix to update the layouts." >&2
  exit 1
fi

# likec4 only writes the README beside the model, so it draws a copy's
copy=$(mktemp -d)
trap 'rm -rf "$copy"' EXIT
cp -R "$model/." "$copy"
pnpm exec likec4 export markdown "$copy"
if ! diff --brief "$model/README.md" "$copy/README.md" >/dev/null; then
  echo "$model/README.md doesn't match the model. Run pnpm fix to update it." >&2
  exit 1
fi
