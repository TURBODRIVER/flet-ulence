"""Provide the current Flet version."""

import json
import sys
from pathlib import Path
from typing import Optional

__all__ = [
    "find_repo_root",
    "flet_version",
    "flutter_version",
]

# set by CI
flet_version = "0.85.99"
"""
The Flet version in use.

This value is set explicitly in CI for released packages. When running from
source and no version is provided, it is derived from the nearest Git tag
when available.
"""

# set by CI
flutter_version = ""
"""
The Flutter SDK version used when building the flet client or packaging
apps with [`flet build`](https://flet.dev/docs/cli/flet-build/).

This value is set explicitly in CI for released packages. When running from
source and no version is provided, it is resolved from the repository's
`.fvmrc` file when available.
"""


def find_repo_root(start_path: Path) -> Optional[Path]:
    """Find the root directory of the Git repository containing the start path.

    Accepts both a regular clone (where `.git` is a directory) and a
    worktree (where `.git` is a file containing `gitdir: ...`).
    """
    current_path = start_path.resolve()
    while current_path != current_path.parent:
        if (current_path / ".git").exists():
            return current_path
        current_path = current_path.parent
    return None


def get_flet_version() -> str:
    """Return the Flet version, falling back to Git or a default if needed."""

    # If the version is already set (e.g., replaced by CI), use it
    if flet_version:
        return flet_version

    # If 'flet_version' is still empty after the above (e.g., in a built package
    # where CI didn't replace it), fall back to the default version.
    # CI replacement is the standard way for packaged versions.
    return "0.85.99"


def get_flutter_version() -> str:
    """
    Return the Flutter SDK version.

    Uses `flutter_version` when set (CI/release builds); otherwise resolves it
    from `.fvmrc` in a local development checkout.
    """

    # If the version is already set (e.g., replaced by CI), use it
    if flutter_version:
        return flutter_version

    repo_root = find_repo_root(Path(__file__).resolve().parent)
    if repo_root:
        fvmrc_path = repo_root / ".fvmrc"
        try:
            v = json.loads(fvmrc_path.read_text(encoding="utf-8"))[
                "flutter"
            ].strip()
            if not v:
                raise ValueError("Empty or missing 'flutter' value")
            return v
        except Exception as e:
            print(f"Error parsing {fvmrc_path!r}: {e}", file=sys.stderr)

    # If 'flutter_version' is still empty after the above (e.g., in a built package
    # where CI didn't replace it), fall back to the below default.
    # CI replacement is the standard way for packaged versions.
    return "0"


flutter_version = get_flutter_version()
flet_version = get_flet_version()
__version__ = flet_version
