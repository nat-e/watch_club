#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["pyyaml>=6"]
#
# [tool.uv]
# # Only versions published at least a week ago, as pnpm-workspace.yaml does
# exclude-newer = "1 week"
# ///
"""Generates, from the sources in `.harness`, the files that the harnesses in
`.harness/config.toml` read but don't share: for now, their subagents.

Run it after changing `.harness/agents` or `.harness/config.toml`. `pnpm install` and `pnpm check`
run it too.
"""

import os
from pathlib import Path

from agents import generate_agents
from config import load_config


def main() -> None:
    # The modules' paths are relative to the repository's root
    os.chdir(Path(__file__).resolve().parents[2])
    config = load_config()
    generate_agents(config.harnesses)


if __name__ == "__main__":
    main()
