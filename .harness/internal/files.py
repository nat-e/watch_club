"""The folders of generated files that the harnesses read."""

from collections.abc import Mapping
from pathlib import Path


def write_folder(folder: Path, files: Mapping[str, str]) -> None:
    """Makes `folder` hold exactly `files`, each text by its file name, and prints what changed.

    The generator owns the folder: it deletes the other files in it.
    """
    # A symlink, as `.claude/agents` was before it was generated, would lead the writes and deletes
    # elsewhere, such as into the sources
    if folder.is_symlink():
        folder.unlink()
    folder.mkdir(parents=True, exist_ok=True)
    for path in sorted(folder.iterdir()):
        if path.name not in files:
            path.unlink()
            print(f"deleted {path}")
    for name, text in files.items():
        path = folder / name
        if not path.exists() or path.read_text() != text:
            path.write_text(text)
            print(f"wrote {path}")
