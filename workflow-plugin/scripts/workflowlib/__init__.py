"""Workflow plugin runtime library.

Dev-mode bootstrap: if `artifactlib` isn't importable (no pip install),
walk up from this file to find a sibling `artifact-plugin/` checkout and
insert it on `sys.path`. In production the `artifact-plugin` package is
installed via `pyproject.toml` and this path-munging is a no-op.
"""

from __future__ import annotations

import sys
from pathlib import Path


def _bootstrap_artifactlib() -> None:
    try:
        import artifactlib  # noqa: F401

        return
    except ImportError:
        pass

    here = Path(__file__).resolve()
    # Layouts covered:
    #   dev checkout:   <sibling>/artifact-plugin/artifact-plugin/scripts/artifactlib
    #   legacy mono:    <sibling>/artifact-plugin/scripts/artifactlib
    #   plugin cache:   <sibling>/artifact-plugin/<version>/scripts/artifactlib
    for ancestor in here.parents:
        for root_name in ("artifact-plugin", "artifact"):
            artifact_root = ancestor.parent / root_name
            if not artifact_root.is_dir():
                continue
            candidates = [
                artifact_root / "artifact-plugin" / "scripts",
                artifact_root / "artifact" / "scripts",
                artifact_root / "scripts",
            ]
            candidates.extend(sorted(artifact_root.glob("*/scripts"), reverse=True))
            for cand in candidates:
                if (cand / "artifactlib").is_dir():
                    sys.path.insert(0, str(cand))
                    return


_bootstrap_artifactlib()
