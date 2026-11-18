"""Subagents: each harness's agent files, generated from the sources in `.harness/agents`.

A source is a Markdown file named after its agent. Its frontmatter has the agent's `name`, its
`description` and a block of settings for each harness, which goes into that harness's file as it
is. Its body is the agent's prompt.
"""

import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, assert_never

import yaml

from config import Harness
from files import write_folder

SOURCES = Path(".harness/agents")

# Where each harness reads its subagents
FOLDERS = {
    Harness.CLAUDE_CODE: Path(".claude/agents"),
    Harness.PI: Path(".pi/agents"),
}


@dataclass(frozen=True)
class _Agent:
    source: Path
    name: str
    description: str
    settings: dict[Harness, dict[str, Any]]
    prompt: str


def generate_agents(harnesses: list[Harness]) -> None:
    """Writes the agent files of `harnesses` from the sources, and deletes those without one.

    Exits with the reason when a source is invalid.
    """
    agents = [_load(path, harnesses) for path in sorted(SOURCES.glob("*.md"))]
    for harness in harnesses:
        write_folder(
            FOLDERS[harness], {f"{agent.name}.md": _render(agent, harness) for agent in agents}
        )


def _load(source: Path, harnesses: list[Harness]) -> _Agent:
    parts = re.fullmatch(r"---\n(.*?)\n---\n(.*)", source.read_text(), re.DOTALL)
    if not parts:
        raise SystemExit(f"{source}: starts with no frontmatter")
    frontmatter = yaml.safe_load(parts[1])
    if frontmatter.get("name") != source.stem:
        raise SystemExit(f"{source}: `name` isn't the file's name, `{source.stem}`")
    if not isinstance(frontmatter.get("description"), str):
        raise SystemExit(f"{source}: `description` is missing")
    for harness in harnesses:
        if not isinstance(frontmatter.get(harness), dict):
            raise SystemExit(f"{source}: the `{harness}` settings are missing")
    return _Agent(
        source=source,
        name=frontmatter["name"],
        description=frontmatter["description"],
        settings={harness: frontmatter[harness] for harness in harnesses},
        prompt=parts[2].strip() + "\n",
    )


def _render(agent: _Agent, harness: Harness) -> str:
    settings = agent.settings[harness]
    match harness:
        case Harness.CLAUDE_CODE:
            fields = {"name": agent.name, "description": agent.description, **settings}
        case Harness.PI:
            # Pi names an agent after its file
            fields = {"description": agent.description, **settings}
        case _:
            assert_never(harness)
    frontmatter = yaml.safe_dump(fields, sort_keys=False, allow_unicode=True, width=math.inf)
    return (
        f"---\n# Generated from {agent.source}: edit it there\n{frontmatter}---\n\n{agent.prompt}"
    )
