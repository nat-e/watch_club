"""`.harness/config.toml`, which says what `generate_harness.py` generates."""

import tomllib
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

PATH = Path(".harness/config.toml")


class Harness(StrEnum):
    """A coding agent that the generated files set up, by its name in the config and the sources."""

    CLAUDE_CODE = "claude-code"
    PI = "pi"


@dataclass(frozen=True)
class Config:
    harnesses: list[Harness]


def load_config() -> Config:
    """Reads the config, and exits with the reason when it's invalid."""
    config = tomllib.loads(PATH.read_text())
    try:
        harnesses = [Harness(name) for name in config["harnesses"]]
    except KeyError:
        raise SystemExit(f"{PATH}: `harnesses` is missing") from None
    except ValueError:
        raise SystemExit(
            f"{PATH}: `harnesses` takes {', '.join(f'"{harness}"' for harness in Harness)}"
        ) from None
    return Config(harnesses=harnesses)
